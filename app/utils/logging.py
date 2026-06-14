import logging
import re
import sys
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Callable

from config.settings import get_app_config
from core.http.context import get_request_id
from loguru import logger


class InterceptHandler(logging.Handler):
    """
    Default handler from examples in loguru documentation.
    See https://loguru.readthedocs.io/en/stable/overview.html#entirely-compatible-with-standard-logging
    """

    def emit(self, record):
        # Get corresponding Loguru level if it exists
        try:
            level = logger.level(record.levelname).name
        except ValueError:
            level = record.levelno

        # Find caller from where originated the logged message
        frame, depth = logging.currentframe(), 2
        while frame.f_code.co_filename == logging.__file__:
            frame = frame.f_back
            depth += 1

        logger.opt(depth=depth, exception=record.exc_info).log(
            level, record.getMessage()
        )


def _ensure_model_level_registered() -> None:
    """Ensure MODEL level exists before writing model logs."""
    try:
        logger.level("MODEL")
    except ValueError:
        logger.level("MODEL", no=15, color="<cyan>", icon="M")


def model_log(message: str):
    _ensure_model_level_registered()
    clean_message = str(message).replace("\n", " ").replace("\r", " ")
    logger.bind(flow="model").log("MODEL", clean_message)


def _resolve_retention_days() -> int:
    """Retention default reserved for future re-enable."""
    # Retention cleanup is intentionally disabled for now.
    return 365


def _build_archive_rename_callback(active_file: Path) -> Callable[[str], None]:
    """Rename rotated file to '<stem>_YYYY-MM-DD.log' and avoid collisions."""

    def _rename(rotated_file: str) -> None:
        rotated_path = Path(rotated_file)
        if not rotated_path.exists():
            return

        try:
            archive_date = datetime.fromtimestamp(rotated_path.stat().st_mtime).strftime(
                "%Y-%m-%d"
            )
        except OSError:
            archive_date = datetime.now().strftime("%Y-%m-%d")

        target = active_file.with_name(
            f"{active_file.stem}_{archive_date}{active_file.suffix}"
        )
        index = 1
        while target.exists():
            target = active_file.with_name(
                f"{active_file.stem}_{archive_date}_{index}{active_file.suffix}"
            )
            index += 1

        rotated_path.rename(target)

    return _rename


def _build_retention_callback(active_file: Path, retention_days: int) -> Callable[[list], None]:
    """Delete archives older than retention_days based on archive date in filename."""
    archive_pattern = re.compile(
        rf"^{re.escape(active_file.stem)}_(\d{{4}}-\d{{2}}-\d{{2}})(?:_\d+)?{re.escape(active_file.suffix)}$"
    )

    def _cleanup(_files: list) -> None:
        cutoff_date = date.today() - timedelta(days=retention_days)
        for candidate in active_file.parent.glob(f"{active_file.stem}_*{active_file.suffix}"):
            matched = archive_pattern.match(candidate.name)
            if not matched:
                continue

            try:
                archived_day = datetime.strptime(matched.group(1), "%Y-%m-%d").date()
            except ValueError:
                continue

            if archived_day < cutoff_date:
                try:
                    candidate.unlink()
                except OSError:
                    # Keep logging alive even if a stale file cannot be removed.
                    pass

    return _cleanup


def _build_daily_file_params(active_file: Path, fmt: str) -> dict:
    _retention_days = _resolve_retention_days()
    # Keep callback for future re-enable of retention.
    # retention_callback = _build_retention_callback(active_file, _retention_days)
    return {
        "rotation": "00:00",
        "compression": _build_archive_rename_callback(active_file),
        "encoding": "utf8",
        "format": fmt,
    }


def _quiet_dependency_loggers() -> None:
    # APScheduler logs the full Job object at INFO when Aliyun's ECS RAM role
    # credential refresher runs. Keep warnings/errors, but drop the routine object dump.
    logging.getLogger("apscheduler.executors").setLevel(logging.WARNING)


def init_logging(log_name="app", log_level=None):
    """
    Initializes the Loguru logger with custom settings.

    Args:
        log_name (str, optional): The base name for log files. Defaults to "app".
        log_level (str, optional): Console log level. If None, use settings.LOG.LEVEL.
    """

    _format = (
        "<green>{time:YYYY-MM-DD HH:mm:ss.ms}</green> [{extra[request_id]}] | {level} | {module}.{function}:{line} : "
        "{message}"
    )

    logger.remove()  # Remove default handler

    # Register custom level for model logs between DEBUG(10) and INFO(20).
    _ensure_model_level_registered()

    configured_level = log_level if log_level is not None else "DEBUG"
    if isinstance(configured_level, str):
        console_level = configured_level.strip().upper() or "DEBUG"
    else:
        console_level = "DEBUG"

    try:
        logger.level(console_level)
    except ValueError:
        console_level = "DEBUG"

    # Configure patcher to automatically inject request_id
    def patcher(record):
        record["extra"]["request_id"] = get_request_id()

    logger.configure(patcher=patcher)

    logger.add(
        sys.stdout,
        level=console_level,
        format=_format,
        filter=lambda record: record["extra"].get("flow") != "access",
    )
    cfg = get_app_config()

    log_dir = Path(cfg.logs_dir)
    log_dir.mkdir(parents=True, exist_ok=True)

    debug_file = log_dir / f"{log_name}_debug.log"
    info_file = log_dir / f"{log_name}_info.log"
    error_file = log_dir / f"{log_name}_error.log"
    model_file = log_dir / f"{log_name}_model.log"

    logger.add(
        debug_file,
        level="DEBUG",
        filter=lambda record: record["extra"].get("flow") != "access",
        **_build_daily_file_params(debug_file, _format),
    )
    logger.add(
        info_file,
        level="INFO",
        filter=lambda record: record["extra"].get("flow") not in {"model", "access"},
        **_build_daily_file_params(info_file, _format),
    )
    logger.add(error_file, level="ERROR", **_build_daily_file_params(error_file, _format))
    logger.add(
        model_file,
        level="MODEL",
        filter=lambda record: record["extra"].get("flow") == "model",
        **_build_daily_file_params(
            model_file,
            "<green>{time:YYYY-MM-DD HH:mm:ss.ms}</green> [{extra[request_id]}] | MODEL | {message}",
        ),
)
    # 添加专门的访问日志文件
    access_format = "<green>{time:YYYY-MM-DD HH:mm:ss.ms}</green> [{extra[request_id]}] | ACCESS | {message}"
    access_file = log_dir / f"{log_name}_access.log"
    logger.add(
        access_file,
        level="INFO",
        filter=lambda record: record["extra"].get("flow") == "access",
        **_build_daily_file_params(access_file, access_format),
    )
    # 拦截标准日志并转发到 Loguru
    # 使用 INFO 级别以减少内部库的调试日志
    logging.basicConfig(handlers=[InterceptHandler()], level=logging.INFO, force=True)
    _quiet_dependency_loggers()

    # 显式接管 uvicorn 的日志记录器，但跳过 access log，避免与应用层请求日志重复。
    for logger_name in ("uvicorn", "uvicorn.error"):
        logging_logger = logging.getLogger(logger_name)
        logging_logger.handlers = [InterceptHandler()]
        logging_logger.propagate = False

    logging.getLogger("uvicorn.access").handlers = []
    logging.getLogger("uvicorn.access").propagate = False
