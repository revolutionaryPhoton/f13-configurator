#!/usr/bin/env bash
# Template renderer — envsubst with a per-file variable allow-list.
# Only vars found in the template are substituted, preventing accidental
# expansion of shell internals (PATH, HOME, …) into generated YAML.
set -euo pipefail

# render::file SRC DEST
#   Renders template SRC into DEST via envsubst.
#   Only variables present in the template are substituted (allow-list).
render::file() {
  local src="${1:?render::file: SRC required}"
  local dest="${2:?render::file: DEST required}"

  [[ -f "$src" ]] || { printf 'render::file: source not found: %s\n' "$src" >&2; return 1; }

  local destdir
  destdir=$(dirname "$dest")
  mkdir -p "$destdir"

  # Extract var names from template — allow-list restricted to [A-Z_][A-Z0-9_]*
  # (F13 convention: all substitution vars are uppercase).
  local varlist
  varlist=$(grep -oE '\$\{?[A-Z_][A-Z0-9_]*' "$src" \
    | grep -oE '[A-Z_][A-Z0-9_]*' \
    | sort -u \
    | sed 's/^/\$/' \
    | tr '\n' ' ') || true

  # envsubst with an explicit (possibly empty) allow-list; empty → no substitution.
  envsubst "${varlist}" < "$src" > "$dest"
}

# render::tree SRC_DIR DEST_DIR
#   Recursively renders every *.tmpl file under SRC_DIR into DEST_DIR,
#   mirroring the directory structure and stripping the .tmpl extension.
render::tree() {
  local src_dir="${1:?render::tree: SRC_DIR required}"
  local dest_dir="${2:?render::tree: DEST_DIR required}"

  [[ -d "$src_dir" ]] || { printf 'render::tree: source dir not found: %s\n' "$src_dir" >&2; return 1; }

  local tmpl rel_path dest_path
  while IFS= read -r -d '' tmpl; do
    rel_path="${tmpl#"${src_dir}/"}"
    dest_path="${dest_dir}/${rel_path%.tmpl}"
    render::file "$tmpl" "$dest_path"
  done < <(find "$src_dir" -name '*.tmpl' -print0 | sort -z)
}
