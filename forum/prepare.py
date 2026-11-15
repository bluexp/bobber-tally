#!/usr/bin/env python3
"""Prepare the pinned FreeIDX checkout for a WFDB deployment."""
from pathlib import Path
import re
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parent
default_tree = root / "build" / "freeidx"
tree = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else default_tree
revision = "f5274fde5b4f3e6343630c702bf7672f2115d413"
if not tree.exists():
    tree.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "clone", "https://github.com/cobubu/FreeIDX.git", str(tree)], check=True)
    subprocess.run(["git", "-C", str(tree), "checkout", "--detach", revision], check=True)
actual = subprocess.check_output(["git", "-C", str(tree), "rev-parse", "HEAD"], text=True).strip()
if actual != revision:
    sys.exit(f"Unexpected FreeIDX revision: {actual}")

api = tree / "apps" / "api"
companion = api / "src" / "modules" / "companion"
companion.mkdir(exist_ok=True)
shutil.copyfile(root / "companion.ts", companion / "routes.ts")
shutil.copyfile(root / "0035_wfdb_desktop.sql", api / "migrations" / "0035_wfdb_desktop.sql")

def insert(file, anchor, addition):
    text = file.read_text()
    if addition + "\n" + anchor in text:
        return
    if text.count(anchor) != 1:
        sys.exit(f"Expected a unique insertion point in {file}")
    file.write_text(text.replace(anchor, addition + "\n" + anchor))

index = api / "src" / "index.ts"
insert(index, "import { authRoutes } from './modules/auth/routes';",
       "import { companionRoutes } from './modules/companion/routes';")
insert(index, "app.route('/', authRoutes());", "app.route('/', companionRoutes());")
insert(index, "app.use('/api/admin/*', adminGuard());", """
// WFDB starts with a text forum. A missing object store never reaches upload handlers.
app.use('*', async (c, next) => {
  const path = c.req.path;
  if (!c.env.FILES &&
      (path.startsWith('/files/') || /^\\/api\\/attachments(?:\\/|$)/.test(path) ||
       (c.req.method === 'POST' && path === '/api/me/avatar'))) {
    return Response.json({ code: 'unavailable', message: '附件上传暂未开放 / Uploads are unavailable.' }, { status: 404 });
  }
  return next();
});
""".strip())
insert(api / "src" / "core" / "cache" / "edge.ts", "function isShellPath(path: string): boolean {",
       "// WFDB account pages carry request-specific authorization and never use the SPA cache.")
shell = api / "src" / "core" / "cache" / "edge.ts"
shell_anchor = "function isShellPath(path: string): boolean {\n"
shell_guard = "  if (path.startsWith('/wfdb/')) return false;\n"
shell_text = shell.read_text()
if shell_anchor + shell_guard not in shell_text:
    shell.write_text(shell_text.replace(shell_anchor, shell_anchor + shell_guard))
shell_text = shell.read_text()
shell_text = shell_text.replace("function shellKeyRequest(origin: string): Request {",
                                "function shellKeyRequest(origin: string, revision: string): Request {")
shell_text = shell_text.replace("return new Request(`${origin}/__fi/spa-shell`, { method: 'GET' });",
                                "return new Request(`${origin}/__fi/spa-shell/${encodeURIComponent(revision)}`, { method: 'GET' });")
shell_text = shell_text.replace("shellKeyRequest(new URL(c.req.url).origin);",
                                "shellKeyRequest(new URL(c.req.url).origin, c.env.CF_VERSION_METADATA?.id ?? 'dev');")
shell.write_text(shell_text)
insert(api / "src" / "types" / "env.ts", "  ASSETS: Fetcher;",
       "  CF_VERSION_METADATA?: WorkerVersionMetadata;")
cache = api / "src" / "core" / "cache" / "index.ts"
for operation in ("get", "put", "delete"):
    is_read = operation == "get"
    anchor = f"    try {{\n      {'return ' if is_read else ''}await this.env.CACHE.{operation}("
    guard = "    if (!this.env.CACHE) return" + (" null;" if is_read else ";")
    insert(cache, anchor, guard)

# Preserve upstream semantics for everything except WFDB resources and optional storage.
config = subprocess.check_output(["git", "-C", str(tree), "show", "HEAD:apps/api/wrangler.toml"], text=True)
config = re.sub(r"\[\[kv_namespaces\]\].*?(?=\[triggers\])", "", config, flags=re.S)
config = config.replace('name = "freeidx-api"', 'name = "wfdb-forum"')
config = config.replace('database_name = "freeidx"', 'database_name = "wfdb-forum"')
config = config.replace("enabled = true", "enabled = false")
config = config.replace('"!/fonts/*"]', '"!/fonts/*", "!/wfdb-forum-source.tar.gz"]')
config += '\n[version_metadata]\nbinding = "CF_VERSION_METADATA"\n'
(api / "wrangler.wfdb.toml").write_text(config)
seed = (api / "seed" / "seed.sql").read_text()
seed = re.sub(r"--> s4_admin.*?(?=--> s5_setting)", "", seed, flags=re.S)
(api / "seed" / "wfdb.sql").write_text(seed + (root / "seed.sql").read_text())
layout = tree / "apps" / "web" / "src" / "themes" / "light" / "Layout.tsx"
previous_footer_links = (
    '                  <a href="https://wfdb.cc/" className="mr-3">WFDB</a>\n'
    '                  <a href="/wfdb-forum-source.tar.gz" className="mr-3">Source code</a>\n'
)
layout_text = layout.read_text()
if previous_footer_links in layout_text:
    layout.write_text(layout_text.replace(previous_footer_links, ""))

patch = ["git", "-C", str(tree), "apply"]
ui = str(root / "wfdb-ui.patch")
already_applied = subprocess.run([*patch, "--reverse", "--check", ui], capture_output=True)
if already_applied.returncode != 0:
    subprocess.run([*patch, "--check", ui], check=True)
    subprocess.run([*patch, ui], check=True)
print(tree)
