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
# load_allowlist
# ---------------------------------------------------------------------------

@test "load_allowlist: empty output for empty file" {
    touch "$FIXTURE_DIR/allowlist.txt"
    run load_allowlist "$FIXTURE_DIR/allowlist.txt"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "load_allowlist: empty output for missing file" {
    run load_allowlist "$FIXTURE_DIR/does-not-exist.txt"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "load_allowlist: ignores comments and blank lines" {
    printf "# a comment\n\n# another\n   \n" > "$FIXTURE_DIR/allowlist.txt"
    run load_allowlist "$FIXTURE_DIR/allowlist.txt"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "load_allowlist: returns entries from a mixed file" {
    printf "# header\n@bot-one\n\n@bot-two\n# trailing\n" > "$FIXTURE_DIR/allowlist.txt"
    run load_allowlist "$FIXTURE_DIR/allowlist.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "@bot-one"$'\n'"@bot-two" ]
}

@test "load_allowlist: trims surrounding whitespace" {
    printf "  @spaced-bot  \n\t@tabbed-bot\t\n" > "$FIXTURE_DIR/allowlist.txt"
    run load_allowlist "$FIXTURE_DIR/allowlist.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "@spaced-bot"$'\n'"@tabbed-bot" ]
}

# ---------------------------------------------------------------------------
# filter_against_allowlist
# ---------------------------------------------------------------------------

@test "filter_against_allowlist: empty allowlist preserves all input" {
    run bash -c 'source "'"$BATS_TEST_DIRNAME"'/check-codeowners.sh"; printf "@alice\n@bob\n" | filter_against_allowlist ""'
    [ "$status" -eq 0 ]
    [ "$output" = "@alice"$'\n'"@bob" ]
}

@test "filter_against_allowlist: removes matching entries" {
    run bash -c 'source "'"$BATS_TEST_DIRNAME"'/check-codeowners.sh"; printf "@alice\n@bot\n@bob\n" | filter_against_allowlist "@bot"'
    [ "$status" -eq 0 ]
    [ "$output" = "@alice"$'\n'"@bob" ]
}

@test "filter_against_allowlist: removes multiple matches" {
    run bash -c 'source "'"$BATS_TEST_DIRNAME"'/check-codeowners.sh"; printf "@alice\n@bot-one\n@bob\n@bot-two\n" | filter_against_allowlist "@bot-one"$'"'"'\n'"'"'"@bot-two"'
    [ "$status" -eq 0 ]
    [ "$output" = "@alice"$'\n'"@bob" ]
}

@test "filter_against_allowlist: empty output when all entries are allowlisted" {
    run bash -c 'source "'"$BATS_TEST_DIRNAME"'/check-codeowners.sh"; printf "@bot\n" | filter_against_allowlist "@bot"'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "filter_against_allowlist: empty input passes through cleanly" {
    run bash -c 'source "'"$BATS_TEST_DIRNAME"'/check-codeowners.sh"; printf "" | filter_against_allowlist "@bot"'
    [ "$status" -eq 0 ]
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

@test "main: passes when only allowlisted individual is present" {
    printf "@allowed-bot\n" > "$FIXTURE_DIR/allowlist.txt"
    printf "* @org/team @allowed-bot\n" > "$FIXTURE_DIR/CODEOWNERS"
    CODEOWNERS_ALLOWLIST_FILE="$FIXTURE_DIR/allowlist.txt" run main "$FIXTURE_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Allowed via allowlist: @allowed-bot"* ]]
}

@test "main: fails on disallowed individual but reports allowlisted exemption" {
    printf "@allowed-bot\n" > "$FIXTURE_DIR/allowlist.txt"
    printf "* @org/team @allowed-bot @human\n" > "$FIXTURE_DIR/CODEOWNERS"
    CODEOWNERS_ALLOWLIST_FILE="$FIXTURE_DIR/allowlist.txt" run main "$FIXTURE_DIR"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Allowed via allowlist: @allowed-bot"* ]]
    [[ "$output" == *"@human"* ]]
    [[ "$output" != *"Offending entries:"*"@allowed-bot"* ]]
}

@test "main: fails for non-allowlisted individual when allowlist file is missing" {
    printf "* @human\n" > "$FIXTURE_DIR/CODEOWNERS"
    CODEOWNERS_ALLOWLIST_FILE="$FIXTURE_DIR/does-not-exist.txt" run main "$FIXTURE_DIR"
    [ "$status" -eq 1 ]
    [[ "$output" == *"@human"* ]]
}
