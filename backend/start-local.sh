#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
backend_dir="$repo_root/backend"
WP_PORT="${WP_PORT:-8081}"
compose=(docker compose --project-directory "$backend_dir" -f "$backend_dir/compose.yaml")
app_url="http://127.0.0.1:${WP_PORT:-8081}"
admin_user="topo-admin"
admin_email="topo-admin@example.com"
password_file="$backend_dir/.local-admin-password"

if ! command -v docker >/dev/null 2>&1; then
  printf 'Docker is required to run the local WordPress backend.\n' >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  printf 'Docker Compose is required to run the local WordPress backend.\n' >&2
  exit 1
fi

if [[ ! -f "$backend_dir/.env" ]]; then
  (
    umask 077
    python3 - <<'PY' > "$backend_dir/.env"
import secrets

print(f"DB_PASSWORD={secrets.token_urlsafe(32)}")
print(f"DB_ROOT_PASSWORD={secrets.token_urlsafe(32)}")
PY
  )
fi

cd "$repo_root/frontend"
flutter build web --release --base-href /topo/

cd "$backend_dir"
"${compose[@]}" up -d --wait

cli() {
  "${compose[@]}" run --rm wpcli "$@"
}

for attempt in $(seq 1 60); do
  if curl --silent --fail --output /dev/null "$app_url/wp-json/"; then
    break
  fi
  if [[ "$attempt" -eq 60 ]]; then
    printf 'WordPress did not become available at %s.\n' "$app_url" >&2
    exit 1
  fi
  sleep 2
done

if ! cli core is-installed >/dev/null 2>&1; then
  if [[ ! -f "$password_file" ]]; then
    (
      umask 077
      python3 - <<'PY' > "$password_file"
import secrets
print(secrets.token_urlsafe(24))
PY
    )
  fi
  admin_password="$(< "$password_file")"
  cli core install \
    --url="$app_url" \
    --title="Topo Local" \
    --admin_user="$admin_user" \
    --admin_password="$admin_password" \
    --admin_email="$admin_email" \
    --skip-email
elif ! cli user get "$admin_user" --field=ID >/dev/null 2>&1; then
  if [[ ! -f "$password_file" ]]; then
    (
      umask 077
      python3 - <<'PY' > "$password_file"
import secrets
print(secrets.token_urlsafe(24))
PY
    )
  fi
  admin_password="$(< "$password_file")"
  cli user create "$admin_user" "$admin_email" \
    --role=administrator \
    --user_pass="$admin_password" \
    --porcelain
fi

if ! cli plugin is-active crux-climbing-gym >/dev/null 2>&1; then
  cli plugin activate crux-climbing-gym
fi
cli rewrite structure '/%postname%/' --hard
cli eval-file /tmp/topo-dev/assign-local-admin.php
cli eval-file /tmp/topo-dev/seed-local-routes.php

printf '\nLocal app: %s/topo/?lane=12\n' "$app_url"
printf 'WordPress admin: %s/wp-admin/\n' "$app_url"
if [[ -f "$password_file" ]]; then
  printf 'Admin username: %s\nAdmin password: %s\n' \
    "$admin_user" "$(< "$password_file")"
else
  printf 'Admin username: %s (existing password was left unchanged)\n' "$admin_user"
fi
printf 'Credentials are stored in backend/.local-admin-password.\n'
