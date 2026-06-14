# Ling Deploy

部署相关文件统一放在 `deploy/` 下：

- `deploy/images/`: Dockerfile 等共享镜像构建资源
- `deploy/dev/`: 开发环境 Docker Compose 与环境变量模板
- `deploy/prod/`: 生产环境 Docker Compose 与环境变量模板
- `deploy/test/`: 测试环境 Docker Compose 与环境变量模板
- `website/withling-home/`: `withling.top` 官网静态服务，已接入各环境 Compose

`ling` 的 Compose 部署会启动后端应用容器和官网静态服务，不启动 MySQL 或 Redis。MySQL/Redis 作为外部依赖，通过各环境 `.env` 中的 `LING_MYSQL_*` 和 `LING_REDIS_*` 变量连接。

## Docker Compose

先按目标环境创建 `.env`：

```bash
cp deploy/dev/.env.example deploy/dev/.env
cp deploy/prod/.env.example deploy/prod/.env
cp deploy/test/.env.example deploy/test/.env
```

推荐通过环境入口部署：

```bash
deploy/compose.sh up -d --build
deploy/compose.sh dev up -d --build
deploy/compose.sh prod up -d --build
deploy/compose.sh test up -d --build
```

`deploy/compose.sh` 默认使用 `prod` 环境；也可以通过第一个参数指定 `dev`、`prod` 或 `test`。脚本默认优先读取 `deploy/<env>/.env`；如果该文件不存在，则回退读取仓库根目录 `.env`。也可以通过 `ENV_FILE=/path/to/.env` 显式指定配置文件。

也可以直接指定对应 compose 文件：

```bash
docker compose --env-file deploy/dev/.env -f deploy/dev/docker-compose.yml up -d --build
docker compose --env-file deploy/prod/.env -f deploy/prod/docker-compose.yml up -d --build
docker compose --env-file deploy/test/.env -f deploy/test/docker-compose.yml up -d --build
```

`dev`、`prod`、`test` 的 compose 文件已区分项目名、容器名和宿主机端口。`.env` 只保留 `LING_DEPLOY_ROOT`、`LING_HOME_PORT`、会随部署变化的连接信息、开关和密钥。

官网服务会随 Ling 服务一起启动，默认端口：

- `prod`: `LING_HOME_PORT=30351`
- `dev`: `LING_HOME_PORT=31079`
- `test`: `LING_HOME_PORT=32079`

如需让 `withling.top` 直接访问官网，可以在服务器或云厂商入口层把域名转发到对应的 `LING_HOME_PORT`。官网也支持单独部署，详见 `website/withling-home/README.md`。
