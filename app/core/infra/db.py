import asyncio
from collections.abc import Awaitable, Callable
from contextlib import asynccontextmanager
from functools import wraps
from typing import Any, Optional, ParamSpec, TypeVar
import json
from config.settings import AppConfig
from core.http.exceptions import AppHTTPException
from loguru import logger
from sqlalchemy import Boolean, DateTime, Float, Integer, String, inspect, text
from sqlalchemy.exc import InterfaceError, OperationalError
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.schema import CreateIndex

P = ParamSpec("P")
T = TypeVar("T")


_CLIENT_DEBUG_LOG_BATCH_OBSOLETE_COLUMNS = {
    "client_session_id",
    "platform",
    "app_version",
    "build_number",
    "debug_enabled",
    "upload_reason",
    "log_count",
    "started_at",
    "ended_at",
    "levels_json",
    "compressed_bytes",
}


def _import_registered_models() -> None:
    import models  # noqa: F401
    import models.chat_quick_prompt  # noqa: F401
    import modules.membership.models  # noqa: F401


def _create_and_sync_database_schema(sync_conn) -> None:
    from models.base import Base

    Base.metadata.create_all(sync_conn)
    _sync_database_schema(sync_conn, Base)


def _configure_aiomysql_pre_ping(engine: AsyncEngine) -> None:
    dialect = engine.sync_engine.dialect
    if dialect.name == "mysql" and dialect.driver == "aiomysql":
        # aiomysql's SQLAlchemy adapter requires ping(False), while newer
        # PyMySQL signatures can make SQLAlchemy choose ping() during pre-ping.
        dialect._send_false_to_ping = True


def _sync_database_schema(sync_conn, base):
    """
    Check all registered tables and update schema if outdated.
    Tries to ALTER TABLE ADD COLUMN first.
    If that fails, it logs an error (does NOT drop table automatically to prevent data loss).
    """
    inspector = inspect(sync_conn)
    existing_tables = set(inspector.get_table_names())

    # Iterate over all defined models in Base.metadata
    for table_name, table in base.metadata.tables.items():
        if table_name not in existing_tables:
            continue

        # Get actual columns
        actual_columns = {col['name'] for col in inspector.get_columns(table_name)}
        # Get expected columns from model
        expected_columns_map = {col.name: col for col in table.columns}
        expected_columns = set(expected_columns_map.keys())

        # Check for missing columns
        missing_columns = expected_columns - actual_columns

        if missing_columns:
            logger.info(f"[DB] 检测到表 '{table_name}' 缺少列: {missing_columns}")

            for col_name in missing_columns:
                col = expected_columns_map[col_name]
                try:
                    # Determine column type and default value
                    col_type = col.type.compile(sync_conn.dialect)
                    default_clause = ""

                    # Handle NOT NULL constraints by adding a default value
                    if not col.nullable:
                        if isinstance(col.type, String):
                            if table_name == "events" and col_name == "time_shape":
                                default_clause = " DEFAULT 'span'"
                            else:
                                default_clause = " DEFAULT ''"
                        elif isinstance(col.type, Integer):
                            default_clause = " DEFAULT 0"
                        elif isinstance(col.type, Boolean):
                            default_clause = " DEFAULT 0"
                        elif isinstance(col.type, Float):
                            default_clause = " DEFAULT 0.0"
                        elif isinstance(col.type, DateTime):
                            # Keep DB-generated defaults aligned with UTC storage semantics.
                            if sync_conn.dialect.name == 'mysql':
                                default_clause = " DEFAULT UTC_TIMESTAMP"
                            else:
                                now_str = utc_now_naive().strftime('%Y-%m-%d %H:%M:%S')
                                default_clause = f" DEFAULT '{now_str}'"

                    # Construct ALTER TABLE statement
                    sql = f"ALTER TABLE {table_name} ADD COLUMN {col_name} {col_type}{default_clause}"
                    logger.info(f"[DB] 尝试添加列: {sql}")
                    sync_conn.execute(text(sql))
                    logger.info(f"[DB] 成功添加列 '{col_name}' 到表 '{table_name}'")

                except Exception as e:
                    logger.error(f"[DB] 无法自动添加列 '{col_name}' 到表 '{table_name}': {e}")
                    # If ALTER fails, we could fallback to DROP, but let's be safe and just log error
                    # The user can manually drop if needed.

        actual_indexes = {item["name"] for item in inspector.get_indexes(table_name)}
        for index in sorted(table.indexes, key=lambda item: item.name or ""):
            if not index.name or index.name in actual_indexes:
                continue
            try:
                logger.info(
                    f"[DB] 尝试添加索引 '{index.name}' 到表 '{table_name}'"
                )
                sync_conn.execute(CreateIndex(index))
                logger.info(
                    f"[DB] 成功添加索引 '{index.name}' 到表 '{table_name}'"
                )
            except Exception as e:
                logger.error(
                    f"[DB] 无法自动添加索引 '{index.name}' 到表 '{table_name}': {e}"
                )

def db_retry(
    max_retries: int = 3,
    delay: float = 1.0,
) -> Callable[[Callable[P, Awaitable[T]]], Callable[P, Awaitable[T]]]:
    """
    数据库操作重试装饰器
    """
    def decorator(func: Callable[P, Awaitable[T]]) -> Callable[P, Awaitable[T]]:
        @wraps(func)
        async def wrapper(*args: P.args, **kwargs: P.kwargs) -> T:
            last_err = None
            for attempt in range(max_retries):
                try:
                    return await func(*args, **kwargs)
                except (OperationalError, InterfaceError) as e:
                    last_err = e
                    logger.warning(f"数据库操作异常 (尝试 {attempt + 1}/{max_retries}): {e}")
                    if attempt < max_retries - 1:
                        await asyncio.sleep(delay)
            
            # 重试耗尽，抛出 AppHTTPException
            logger.error(f"数据库操作最终失败: {last_err}")
            raise AppHTTPException(
                detail="数据库操作失败",
                error_detail=str(last_err)
            )
        return wrapper
    return decorator


class SessionManager:
    """
    异步数据库会话管理器
    当前仅支持 MySQL
    """

    def __init__(self, cfg: AppConfig):
        self.cfg = cfg
        self._lock = asyncio.Lock()

        self._engine_name = "mysql"
        self._engine = None
        self._SessionLocal: Optional[async_sessionmaker] = None

        self.mysql_config = {
            "host": cfg.mysql_host,
            "port": int(cfg.mysql_port),
            "user": cfg.mysql_user,
            "password": cfg.mysql_password,
            "database": cfg.mysql_database,
            "charset": cfg.mysql_charset,
        }
        logger.info(
            "使用MySQL数据库: {}:{} / {}",
            self.mysql_config.get("host"),
            self.mysql_config.get("port"),
            self.mysql_config.get("database"),
        )

    async def init_conn(self):
        """
        初始化数据库连接和 session 工厂
        """
        try:
            async with self._lock:
                from urllib.parse import quote_plus

                user = self.mysql_config.get("user", "")
                password = quote_plus(self.mysql_config.get("password", ""))
                host = self.mysql_config.get("host", "127.0.0.1")
                port = int(self.mysql_config.get("port", 3306))
                database = self.mysql_config.get("database", "")
                charset = self.mysql_config.get("charset", "utf8mb4")

                url = (
                    "mysql+aiomysql://"
                    f"{user}:{password}@{host}:{port}/{database}?charset={charset}"
                )
                self._engine = create_async_engine(
                    url,
                    future=True,
                    pool_size=20,
                    max_overflow=20,
                    pool_recycle=1800,
                    pool_timeout=10,
                    pool_pre_ping=True,
                    json_serializer=lambda obj: json.dumps(obj, ensure_ascii=False),
                    json_deserializer=json.loads,
                )
                _configure_aiomysql_pre_ping(self._engine)

                self._SessionLocal = async_sessionmaker(
                    bind=self._engine,
                    autoflush=False,
                    autocommit=False,
                    expire_on_commit=False,
                )

                try:
                    async with self._engine.connect() as conn:
                        await conn.execute(text("SELECT 1"))
                except Exception as e:
                    logger.error(f"MySQL 连接验证失败: {e}")
                    raise e

                _import_registered_models()

        except Exception as e:
            err_msg = str(e)
            logger.error(f"数据库初始化失败: {err_msg}")

            # 提供更友好的错误提示
            hint = ""
            if (
                "Name or service not known" in err_msg
                or "gaierror" in err_msg
                or "Can't connect to MySQL server" in err_msg
            ):
                hint = "可能是数据库 Host 配置错误，请检查 mysql_host"
            elif "Access denied" in err_msg:
                hint = "可能是数据库用户名或密码错误"
            elif "Connection refused" in err_msg:
                hint = "可能是数据库端口错误或服务未启动"

            if hint:
                logger.error(f"提示: {hint}")

            raise AppHTTPException(
                detail="数据库初始化失败",
                error_detail=f"{err_msg} | {hint}",
            ) from e

    async def initialize_schema(self) -> None:
        if not self._engine:
            raise AppHTTPException(
                detail="数据库未初始化",
                error_detail="SQLAlchemy 引擎不存在",
            )

        _import_registered_models()
        logger.info("开始初始化数据库表结构...")
        async with self._engine.begin() as conn:
            await conn.run_sync(_create_and_sync_database_schema)
        logger.info("数据库表结构初始化完成。")

    async def close(self):
        """
        关闭数据库连接
        """
        async with self._lock:
            if self._engine:
                await self._engine.dispose()
                self._engine = None

    def _create_session(self) -> AsyncSession:
        if not self._SessionLocal or not self._engine:
            raise AppHTTPException(
                detail="数据库未初始化",
                error_detail="SQLAlchemy 引擎或会话工厂不存在",
            )
        return self._SessionLocal()

    @asynccontextmanager
    async def get_session(self, autocommit: bool = True):
        """
        获取异步数据库会话
        - 适配 StreamingResponse / 高并发
        - 正确处理 CancelledError
        """
        if not self._SessionLocal or not self._engine:
            raise AppHTTPException(
                detail="数据库未初始化",
                error_detail="SQLAlchemy 引擎或会话工厂不存在",
            )

        session: AsyncSession = self._create_session()
        cancelled = False

        try:
            yield session

            # ⚠️ 如果 Task 已被 cancel，不要再 commit
            if autocommit and not cancelled:
                await session.commit()

        except asyncio.CancelledError:
            # ✅ 标记取消，但不再尝试 rollback（连接可能已不可用）
            cancelled = True
            raise

        except (OperationalError, InterfaceError) as e:
            # ✅ aiomysql 在取消时抛 InterfaceError: Cancelled during execution
            if "Cancelled during execution" in str(e):
                cancelled = True
                logger.debug(f"数据库操作被取消: {e}")
                raise asyncio.CancelledError() from e

            # 正常数据库异常
            try:
                await session.rollback()
            except Exception:
                pass
            raise

        except Exception as e:
            try:
                await session.rollback()
            except Exception:
                pass

            logger.error(f"数据库操作失败: {e}")
            raise AppHTTPException(
                detail="数据库操作失败",
                error_detail=str(e),
            ) from e

        finally:
            # ✅ close 必须 shield，但取消时允许直接放弃连接
            try:
                await asyncio.shield(session.close())
            except asyncio.CancelledError:
                pass
            except (OperationalError, InterfaceError) as e:
                # 忽略因取消导致的 InterfaceError
                if "Cancelled during execution" in str(e):
                    pass
                else:
                    logger.error(f"关闭 Session 失败（数据库错误）: {e}")
            except Exception as e:
                logger.error(f"关闭 Session 失败: {e}")

    @asynccontextmanager
    async def transaction(self):
        """
        获取显式事务上下文。
        使用 SQLAlchemy 原生 `session.begin()` 管理提交与回滚。
        """
        if not self._SessionLocal or not self._engine:
            raise AppHTTPException(
                detail="数据库未初始化",
                error_detail="SQLAlchemy 引擎或会话工厂不存在",
            )

        session: AsyncSession = self._create_session()

        try:
            async with session.begin():
                yield session
        except (OperationalError, InterfaceError) as e:
            if "Cancelled during execution" in str(e):
                logger.debug(f"数据库事务被取消: {e}")
                raise asyncio.CancelledError() from e
            raise
        finally:
            try:
                await asyncio.shield(session.close())
            except asyncio.CancelledError:
                pass
            except (OperationalError, InterfaceError) as e:
                if "Cancelled during execution" in str(e):
                    pass
                else:
                    logger.error(f"关闭事务 Session 失败（数据库错误）: {e}")
            except Exception as e:
                logger.error(f"关闭事务 Session 失败: {e}")


@asynccontextmanager
async def transaction_scope(session: AsyncSession | None = None):
    """
    复用已有 session；若未传入则开启一个新的事务上下文。
    适合 service 层在“可嵌套参与事务”和“独立开启事务”之间统一写法。
    """
    if session is not None:
        yield session
        return

    db = await get_global_db()
    async with db.transaction() as active_session:
        yield active_session


# ===== 全局 DB 管理 =====
DB_MANAGER: Optional[SessionManager] = None


async def init_db_client(cfg: AppConfig) -> SessionManager:
    """
    初始化全局数据库客户端
    """
    global DB_MANAGER
    if DB_MANAGER is not None:
        return DB_MANAGER

    required = [
        cfg.mysql_host,
        cfg.mysql_port,
        cfg.mysql_user,
        cfg.mysql_password,
        cfg.mysql_database,
    ]
    if not all(required):
        raise AppHTTPException(
            status_code=503,
            detail="MySQL 配置不完整",
            error_detail="mysql host/port/user/password/database are required",
        )

    mgr = SessionManager(cfg)
    await mgr.init_conn()
    DB_MANAGER = mgr
    return DB_MANAGER


async def get_global_db() -> SessionManager:
    """
    获取全局数据库客户端
    """
    global DB_MANAGER
    if DB_MANAGER is None:
        raise AppHTTPException(
            detail="全局数据库管理器未设置",
            error_detail="请在项目启动时初始化数据库客户端",
        )
    return DB_MANAGER


async def close_db_client() -> None:
    """
    关闭全局数据库客户端
    """
    global DB_MANAGER
    try:
        if DB_MANAGER is not None:
            await DB_MANAGER.close()
    finally:
        DB_MANAGER = None
