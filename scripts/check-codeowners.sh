#!/usr/bin/env bash

# Locate a CODEOWNERS file under ROOT (defaults to cwd).
# GitHub resolves CODEOWNERS from three locations in priority order.
find_codeowners() {
    local root="${1:-.}"
    for path in CODEOWNERS .github/CODEOWNERS docs/CODEOWNERS; do
        if [[ -f "$root/$path" ]]; then
            echo "$root/$path"
            return 0
        fi
    done
    return 1
}

# Print individual-user @mentions from FILE (one per line).
# Team references (@org/team) and email addresses (user@host) are excluded.
# Splits on whitespace first so that embedded @ (e.g. user@host) is never matched.
extract_individuals() {
    local file="$1"
    grep -v '^\s*#' "$file" \
        | tr ' \t' '\n' \
        | grep -E '^@[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)?$' \
        | grep -v '/' \
        || true
}

# Load allowlist entries from FILE. Strips full-line comments (# prefix after
# trimming), blank lines, and surrounding whitespace. Missing file → empty
# output (no error) so removing the allowlist falls back to strict enforcement.
load_allowlist() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    awk '
        { gsub(/^[[:space:]]+|[[:space:]]+$/, "") }
        /^$/ { next }
        /^#/ { next }
        { print }
    ' "$file"
}

# Filter stdin against ALLOWLIST (newline-separated). Drops exact matches,
# prints survivors. Empty allowlist → passthrough.
filter_against_allowlist() {
    local allowlist="$1"
    if [[ -z "$allowlist" ]]; then
        cat
        return 0
    fi
    grep -Fxv -f <(printf '%s\n' "$allowlist") || true
}

main() {
    local root="${1:-.}"
    local codeowners_file

    if ! codeowners_file=$(find_codeowners "$root"); then
        echo "No CODEOWNERS file found — nothing to check."
        exit 0
    fi

    echo "Checking $codeowners_file ..."

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local allowlist_file="${CODEOWNERS_ALLOWLIST_FILE:-${script_dir}/codeowners-allowlist.txt}"
    local allowlist
    allowlist=$(load_allowlist "$allowlist_file")

    local individuals disallowed allowed_matches
    individuals=$(extract_individuals "$codeowners_file")

    if [[ -z "$individuals" ]]; then
        echo "All CODEOWNERS entries are team references."
        return 0
    fi

    disallowed=$(printf '%s\n' "$individuals" | filter_against_allowlist "$allowlist")
    allowed_matches=$(printf '%s\n' "$individuals" | { [[ -n "$allowlist" ]] && grep -Fxf <(printf '%s\n' "$allowlist") || true; })

    if [[ -n "$allowed_matches" ]]; then
        echo "Allowed via allowlist: $(echo "$allowed_matches" | paste -sd, -)"
    fi

    if [[ -n "$disallowed" ]]; then
        echo "::error file=$codeowners_file::Individual users are not permitted in CODEOWNERS — use @org/team references instead."
        echo ""
        echo "Offending entries:"
        echo "$disallowed"
        exit 1
    fi

    echo "All CODEOWNERS entries are team references or allowlisted."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
    main "$@"
fi
