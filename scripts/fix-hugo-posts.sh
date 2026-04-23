#!/usr/bin/env bash

set -euo pipefail

mode="apply"
root_dir=""

usage() {
  cat <<'EOF'
Usage:
  scripts/fix-hugo-posts.sh [--check] [--apply] [--root PATH]

Behavior:
  - Renames a single root markdown file in each post directory to index.md
  - Moves files out of a photo/ subdirectory into the post root
  - Adds missing front matter fields: title, date, draft

Options:
  --check       Preview actions without modifying files
  --apply       Apply changes (default)
  --root PATH   Repository root, defaults to the parent of this script
  -h, --help    Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      mode="check"
      shift
      ;;
    --apply)
      mode="apply"
      shift
      ;;
    --root)
      root_dir="${2:-}"
      if [[ -z "$root_dir" ]]; then
        echo "error: --root requires a path" >&2
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
root_dir="${root_dir:-$(cd -- "$script_dir/.." && pwd)}"
post_root="$root_dir/content/post"

if [[ ! -d "$post_root" ]]; then
  echo "error: post root not found: $post_root" >&2
  exit 1
fi

changed=0
warnings=0

log() {
  printf '%s\n' "$*"
}

warn() {
  printf 'warn: %s\n' "$*" >&2
  warnings=$((warnings + 1))
}

run() {
  if [[ "$mode" == "check" ]]; then
    printf '[check] %s\n' "$*"
    return 0
  fi

  "$@"
}

yaml_escape() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  printf '"%s"' "$value"
}

title_from_name() {
  local source_name="$1"
  source_name="${source_name%.md}"
  source_name="${source_name//_/ }"
  source_name="${source_name//-/ }"
  source_name="$(printf '%s' "$source_name" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"

  if [[ -z "$source_name" ]]; then
    source_name="Untitled"
  fi

  printf '%s' "$source_name"
}

date_from_dir() {
  local dir_name="$1"
  local year=""
  local month=""
  local day=""

  if [[ "$dir_name" =~ ^([0-9]{4})[-.]([0-9]{1,2})[-.]([0-9]{1,2})$ ]]; then
    year="${BASH_REMATCH[1]}"
    month="${BASH_REMATCH[2]}"
    day="${BASH_REMATCH[3]}"
  elif [[ "$dir_name" =~ ^([0-9]{2})[-.]([0-9]{1,2})[-.]([0-9]{1,2})$ ]]; then
    year="20${BASH_REMATCH[1]}"
    month="${BASH_REMATCH[2]}"
    day="${BASH_REMATCH[3]}"
  else
    date '+%F'
    return 0
  fi

  printf '%04d-%02d-%02d\n' "$year" "$month" "$day"
}

front_matter_block() {
  local file="$1"
  awk '
    NR == 1 && $0 == "---" { in_block = 1; next }
    in_block && $0 == "---" { exit }
    in_block { print }
  ' "$file"
}

ensure_front_matter() {
  local file="$1"
  local title="$2"
  local date_value="$3"
  local temp_file
  temp_file="$(mktemp)"

  if [[ "$(head -n 1 "$file" 2>/dev/null)" != "---" ]]; then
    log "front matter: add $file"
    changed=1

    if [[ "$mode" == "check" ]]; then
      rm -f "$temp_file"
      return 0
    fi

    {
      printf -- '---\n'
      printf 'title: %s\n' "$(yaml_escape "$title")"
      printf 'date: %s\n' "$date_value"
      printf 'draft: false\n'
      printf -- '---\n\n'
      cat "$file"
    } >"$temp_file"
    mv "$temp_file" "$file"
    return 0
  fi

  local block
  block="$(front_matter_block "$file")"
  local has_title=0
  local has_date=0
  local has_draft=0

  grep -q '^title:' <<<"$block" && has_title=1
  grep -q '^date:' <<<"$block" && has_date=1
  grep -q '^draft:' <<<"$block" && has_draft=1

  if [[ $has_title -eq 1 && $has_date -eq 1 && $has_draft -eq 1 ]]; then
    rm -f "$temp_file"
    return 0
  fi

  log "front matter: fill missing fields in $file"
  changed=1

  if [[ "$mode" == "check" ]]; then
    rm -f "$temp_file"
    return 0
  fi

  awk \
    -v title_line="title: $(yaml_escape "$title")" \
    -v date_line="date: $date_value" \
    -v draft_line="draft: false" \
    -v has_title="$has_title" \
    -v has_date="$has_date" \
    -v has_draft="$has_draft" '
      NR == 1 && $0 == "---" {
        print
        if (!has_title) print title_line
        if (!has_date) print date_line
        if (!has_draft) print draft_line
        next
      }
      { print }
    ' "$file" >"$temp_file"
  mv "$temp_file" "$file"
}

shopt -s nullglob dotglob

for post_dir in "$post_root"/*; do
  [[ -d "$post_dir" ]] || continue
  [[ "$(basename "$post_dir")" == .* ]] && continue

  post_name="$(basename "$post_dir")"
  index_file="$post_dir/index.md"
  candidate_markdowns=()

  while IFS= read -r -d '' file; do
    candidate_markdowns+=("$file")
  done < <(find "$post_dir" -maxdepth 1 -type f -name '*.md' ! -name 'index.md' -print0 | sort -z)

  source_name="$post_name"
  if [[ ${#candidate_markdowns[@]} -gt 0 ]]; then
    source_name="$(basename "${candidate_markdowns[0]}")"
  fi

  if [[ ! -f "$index_file" ]]; then
    if [[ ${#candidate_markdowns[@]} -eq 1 ]]; then
      log "rename: ${candidate_markdowns[0]} -> $index_file"
      changed=1
      run mv "${candidate_markdowns[0]}" "$index_file"
    elif [[ ${#candidate_markdowns[@]} -gt 1 ]]; then
      warn "skip $post_dir: multiple markdown files found, cannot choose index.md automatically"
      continue
    else
      warn "skip $post_dir: no markdown file found"
      continue
    fi
  fi

  photo_dir="$post_dir/photo"
  if [[ -d "$photo_dir" ]]; then
    while IFS= read -r -d '' asset; do
      target="$post_dir/$(basename "$asset")"
      if [[ -e "$target" ]]; then
        warn "skip move $asset: target already exists at $target"
        continue
      fi

      log "move: $asset -> $target"
      changed=1
      run mv "$asset" "$target"
    done < <(find "$photo_dir" -mindepth 1 -maxdepth 1 -type f -print0 | sort -z)

    if [[ -z "$(find "$photo_dir" -mindepth 1 -print -quit)" ]]; then
      log "remove empty dir: $photo_dir"
      changed=1
      run rmdir "$photo_dir"
    else
      warn "keep $photo_dir: directory still contains nested content"
    fi
  fi

  derived_title="$(title_from_name "$source_name")"
  derived_date="$(date_from_dir "$post_name")"
  ensure_front_matter "$index_file" "$derived_title" "$derived_date"
done

if [[ $changed -eq 0 ]]; then
  log "No incompatible Hugo post structure found."
else
  log "Done."
fi

if [[ $warnings -gt 0 ]]; then
  warn "finished with $warnings warning(s)"
fi
