#!/bin/sh
set -eu
tree=$1
scratch=$(mktemp -d "${TMPDIR:-/tmp}/wfdb-forum-source.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT
mkdir "$scratch/FreeIDX-WFDB"
git -C "$tree" archive HEAD | tar -xf - -C "$scratch/FreeIDX-WFDB"
for path in \
    apps/api/src/index.ts apps/api/src/core/cache/index.ts apps/api/src/core/cache/edge.ts \
    apps/api/src/modules/companion/routes.ts apps/api/migrations/0035_wfdb_desktop.sql \
    apps/api/wrangler.wfdb.toml apps/api/src/types/env.ts apps/api/seed/wfdb.sql \
    apps/web/index.html apps/web/src/components/AuthModal.tsx apps/web/src/components/ContentLangBar.tsx \
    apps/web/src/components/SiteLogo.tsx apps/web/src/components/ui.tsx \
    apps/web/src/themes/light/Layout.tsx apps/web/src/themes/light/wfdb.css \
    apps/web/src/themes/light/pages/HomePage.tsx apps/web/src/themes/light/pages/LoginPage.tsx \
    apps/web/src/themes/light/pages/RegisterPage.tsx apps/web/src/themes/light/pages/WfdbAuthPage.tsx
do
    mkdir -p "$scratch/FreeIDX-WFDB/$(dirname "$path")"
    cp "$tree/$path" "$scratch/FreeIDX-WFDB/$path"
done
tar -czf "$tree/apps/web/dist/wfdb-forum-source.tar.gz" -C "$scratch" FreeIDX-WFDB
