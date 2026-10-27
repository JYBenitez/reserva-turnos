#!/usr/bin/env bash
# PreToolUse: bloquea editar una migración Flyway que ya está commiteada.
# Una migración versionada aplicada no se toca: cambiar su contenido rompe el
# checksum de Flyway en cualquier base donde ya corrió. El cambio va en una
# migración nueva (V<n+1>__...).
set -euo pipefail

migrations_dir="${FLYWAY_MIGRATIONS_DIR:-src/main/resources/db/migration}"
project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"

file_path="$(jq -r '.tool_input.file_path // empty')"
[[ -z "$file_path" ]] && exit 0

rel_path="${file_path#"$project_dir"/}"
file_name="$(basename "$rel_path")"

# Solo migraciones versionadas (V*.sql); las repetibles (R__*.sql) se pueden editar.
[[ "$rel_path" == "$migrations_dir"/* && "$file_name" == V*.sql ]] || exit 0

# Sin repo git no hay forma de saber si ya se aplicó: se permite.
git -C "$project_dir" rev-parse --verify HEAD >/dev/null 2>&1 || exit 0

if git -C "$project_dir" cat-file -e "HEAD:$rel_path" 2>/dev/null; then
  echo "Bloqueado: $rel_path ya está commiteada. No edites migraciones aplicadas; creá una nueva V<n>__<descripcion>.sql en $migrations_dir." >&2
  exit 2
fi

exit 0
