#!/bin/sh
# ShinyProxy serves every app session on a sub-path that only exists once the container has been
# created (`/app_proxy/<proxy-id>/`), while SvelteKit bakes `paths.base` into the build. The image is
# therefore built with a placeholder base path, and this script rewrites the build output to the real
# one before the server starts.
#
# The base is taken from SHINYPROXY_PUBLIC_PATH (inject it via `container-env` in application.yml).
# BASE_PATH overrides it, and an empty value serves the app from the root - which is what happens on
# a plain `docker run`, so the image stays usable outside of ShinyProxy.
set -eu

APP_DIR=${APP_DIR:-/app/build}
PLACEHOLDER=${BASE_PATH_PLACEHOLDER:-/__SHINYPROXY_PUBLIC_PATH__}

base=${BASE_PATH:-${SHINYPROXY_PUBLIC_PATH:-}}
# SvelteKit requires the base to start - but not end - with a slash, or to be empty.
base=$(printf '%s' "$base" | sed -e 's#/*$##' -e 's#^/*#/#')
if [ "$base" = "/" ]; then
	base=''
fi

placeholder_dir="$APP_DIR/client${PLACEHOLDER}"

if [ -d "$placeholder_dir" ]; then
	echo "[entrypoint] serving app from base path '${base:-/}'"

	# 1. The base path is part of the directory layout of the static assets, so move them into place.
	for root in client prerendered; do
		src="$APP_DIR/$root${PLACEHOLDER}"
		[ -d "$src" ] || continue

		if [ -n "$base" ]; then
			dest="$APP_DIR/$root$base"
			mkdir -p "$(dirname "$dest")"
			mv "$src" "$dest"
		else
			# Root deployment: hoist the placeholder directory's contents one level up.
			find "$src" -mindepth 1 -maxdepth 1 -exec mv {} "$APP_DIR/$root/" \;
			rmdir "$src"
		fi
	done

	# 2. Rewrite the placeholder inside the server bundle, the client bundle and the prerendered HTML.
	#    Any pre-compressed sibling of a rewritten file would still hold the placeholder, so drop it
	#    and let the server fall back to the plain file.
	grep -rlF "$PLACEHOLDER" "$APP_DIR" | while read -r file; do
		sed -i "s|$PLACEHOLDER|$base|g" "$file"
		rm -f "$file.gz" "$file.br"
	done
else
	echo "[entrypoint] build output already rewritten, starting as-is"
fi

exec "$@"
