# 无限库 WFDB 论坛

论坛以 [FreeIDX](https://github.com/cobubu/FreeIDX) 为基础，使用 Cloudflare Workers Static Assets 和 D1。论坛先开放文字主题和回复。论坛主页是 `forum.wfdb.cc`，资料库和下载入口在 `wfdb.cc`。

`prepare.py` 应用 `wfdb-ui.patch`，给论坛加上主站的颜色、品牌和导航。页面继续使用 FreeIDX 的主题列表、搜索和账号表单。

## 本机试用

在仓库根目录运行下面的命令。需要 Node.js、Corepack 和 Python 3。

```sh
python3 forum/prepare.py
cd forum/build/freeidx
corepack pnpm install --frozen-lockfile
corepack pnpm --filter @freeidx/web build
cd apps/api
umask 077
printf 'JWT_SECRET=%s\n' "$(openssl rand -hex 32)" > .dev.vars
corepack pnpm exec wrangler d1 migrations apply wfdb-forum --local --config wrangler.wfdb.toml
corepack pnpm exec wrangler d1 execute wfdb-forum --local --config wrangler.wfdb.toml --file seed/wfdb.sql
corepack pnpm exec wrangler dev --config wrangler.wfdb.toml --ip 127.0.0.1 --port 8789
```

在另一个终端回到仓库根目录，运行 `WFDB_FORUM_LOCAL=1 ./clients/macos/build.sh`。用生成的本机测试客户端进入「账号」，在浏览器注册或登录，回原授权页继续，确认用户名后授权并返回客户端。

## 部署

为论坛单独创建名为 `wfdb-forum` 的 D1 数据库，在 `wrangler.wfdb.toml` 填写数据库 ID。用 `--remote` 执行上面的迁移和一次性种子步骤。种子只为新论坛初始化板块和设置，不应在已经运营的论坛上重跑。使用 `wrangler secret put JWT_SECRET` 在 Cloudflare 保存随机密钥。

在仓库根目录运行 `sh forum/source.sh forum/build/freeidx`，把带许可证和实际修改的论坛源码归档到部署资产目录。使用 `wrangler deploy --config wrangler.wfdb.toml` 上传应用，再为 Worker 添加自定义域名 `forum.wfdb.cc`。论坛页脚提供源码下载和返回主站的入口。

账号由论坛维护。Mac 客户端只请求论坛账号编号和用户名，授权使用一次性代码和 S256 校验，客户端会话存入 macOS 钥匙串。客户端可独立退出登录。正式论坛可在后台配置邮件验证和密码重置。按需为社区管理者启用管理角色。
