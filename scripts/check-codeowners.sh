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

main() {
    local root="${1:-.}"
    local codeowners_file

    if ! codeowners_file=$(find_codeowners "$root"); then
        echo "No CODEOWNERS file found — nothing to check."
        exit 0
    fi

    echo "Checking $codeowners_file ..."

    local individuals
    individuals=$(extract_individuals "$codeowners_file")

    if [[ -n "$individuals" ]]; then
        echo "::error file=$codeowners_file::Individual users are not permitted in CODEOWNERS — use @org/team references instead."
        echo ""
        echo "Offending entries:"
        echo "$individuals"
        exit 1
    fi

    echo "All CODEOWNERS entries are team references."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
    main "$@"
fi
