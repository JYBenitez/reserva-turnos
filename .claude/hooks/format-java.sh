#!/usr/bin/env bash
# PostToolUse: formatea con Spotless el archivo .java recién editado.
# No hace nada hasta que exista ./mvnw y el pom tenga spotless-maven-plugin.
set -euo pipefail

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"

file_path="$(jq -r '.tool_input.file_path // empty')"
[[ "$file_path" == *.java ]] || exit 0
[[ -x "$project_dir/mvnw" ]] || exit 0
grep -q "spotless-maven-plugin" "$project_dir/pom.xml" 2>/dev/null || exit 0

# spotlessFiles recibe una regex: se escapan los caracteres especiales del path.
file_regex="$(printf '%s' "$file_path" | sed 's/[][\.*^$+?(){}|]/\\&/g')"

cd "$project_dir"
if ! output="$(./mvnw -q spotless:apply -DspotlessFiles="$file_regex" 2>&1)"; then
  echo "Spotless falló sobre $file_path:" >&2
  echo "$output" >&2
  exit 2
fi
