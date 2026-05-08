#!/usr/bin/env bats

setup() {
    # shellcheck source=check-codeowners.sh
    source "$BATS_TEST_DIRNAME/check-codeowners.sh"
    FIXTURE_DIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$FIXTURE_DIR"
}

# ---------------------------------------------------------------------------
# extract_individuals
# ---------------------------------------------------------------------------

@test "extract_individuals: empty output for team-only entries" {
    printf "* @org/backend-team\n/src @org/frontend-team\n" > "$FIXTURE_DIR/CODEOWNERS"
    run extract_individuals "$FIXTURE_DIR/CODEOWNERS"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "extract_individuals: detects a single individual" {
    printf "* @johndoe\n" > "$FIXTURE_DIR/CODEOWNERS"
    run extract_individuals "$FIXTURE_DIR/CODEOWNERS"
    [ "$output" = "@johndoe" ]
}

@test "extract_individuals: detects individual mixed with teams on the same line" {
    printf "* @org/team @johndoe\n" > "$FIXTURE_DIR/CODEOWNERS"
    run extract_individuals "$FIXTURE_DIR/CODEOWNERS"
    [ "$output" = "@johndoe" ]
}

@test "extract_individuals: detects multiple individuals across lines" {
    printf "* @alice\n/docs @bob\n" > "$FIXTURE_DIR/CODEOWNERS"
    run extract_individuals "$FIXTURE_DIR/CODEOWNERS"
    [ "$output" = "@alice"$'\n'"@bob" ]
}

@test "extract_individuals: ignores comment lines" {
    printf "# @individual-in-comment\n* @org/team\n" > "$FIXTURE_DIR/CODEOWNERS"
    run extract_individuals "$FIXTURE_DIR/CODEOWNERS"
    [ -z "$output" ]
}

@test "extract_individuals: ignores email addresses" {
    printf "* user@example.com\n" > "$FIXTURE_DIR/CODEOWNERS"
    run extract_individuals "$FIXTURE_DIR/CODEOWNERS"
    [ -z "$output" ]
}

@test "extract_individuals: empty output for empty file" {
    touch "$FIXTURE_DIR/CODEOWNERS"
    run extract_individuals "$FIXTURE_DIR/CODEOWNERS"
    [ -z "$output" ]
}

@test "extract_individuals: ignores pattern-only lines with no owner (unset ownership)" {
    printf "*.lockfile\n/some/path\n* @org/team\n" > "$FIXTURE_DIR/CODEOWNERS"
    run extract_individuals "$FIXTURE_DIR/CODEOWNERS"
    [ -z "$output" ]
}

# ---------------------------------------------------------------------------
# find_codeowners
# ---------------------------------------------------------------------------

@test "find_codeowners: finds CODEOWNERS at root" {
    touch "$FIXTURE_DIR/CODEOWNERS"
    run find_codeowners "$FIXTURE_DIR"
    [ "$status" -eq 0 ]
    [ "$output" = "$FIXTURE_DIR/CODEOWNERS" ]
}

@test "find_codeowners: finds CODEOWNERS under .github/" {
    mkdir -p "$FIXTURE_DIR/.github"
    touch "$FIXTURE_DIR/.github/CODEOWNERS"
    run find_codeowners "$FIXTURE_DIR"
    [ "$status" -eq 0 ]
    [ "$output" = "$FIXTURE_DIR/.github/CODEOWNERS" ]
}

@test "find_codeowners: finds CODEOWNERS under docs/" {
    mkdir -p "$FIXTURE_DIR/docs"
    touch "$FIXTURE_DIR/docs/CODEOWNERS"
    run find_codeowners "$FIXTURE_DIR"
    [ "$status" -eq 0 ]
    [ "$output" = "$FIXTURE_DIR/docs/CODEOWNERS" ]
}

@test "find_codeowners: root takes priority over .github/" {
    mkdir -p "$FIXTURE_DIR/.github"
    touch "$FIXTURE_DIR/CODEOWNERS" "$FIXTURE_DIR/.github/CODEOWNERS"
    run find_codeowners "$FIXTURE_DIR"
    [ "$output" = "$FIXTURE_DIR/CODEOWNERS" ]
}

@test "find_codeowners: returns non-zero when no CODEOWNERS exists" {
    run find_codeowners "$FIXTURE_DIR"
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# main (integration)
# ---------------------------------------------------------------------------

@test "main: passes for team-only CODEOWNERS" {
    printf "* @org/team\n/src @org/other-team\n" > "$FIXTURE_DIR/CODEOWNERS"
    run main "$FIXTURE_DIR"
    [ "$status" -eq 0 ]
}

@test "main: fails for individual user in CODEOWNERS" {
    printf "* @username\n" > "$FIXTURE_DIR/CODEOWNERS"
    run main "$FIXTURE_DIR"
    [ "$status" -eq 1 ]
}

@test "main: passes when no CODEOWNERS file exists" {
    run main "$FIXTURE_DIR"
    [ "$status" -eq 0 ]
}
