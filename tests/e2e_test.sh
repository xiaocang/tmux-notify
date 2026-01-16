#!/usr/bin/env bash
#
# Data-driven e2e tests for tmux-notify
#
# Test case format: "name|setup|expected_count"
# Setup format: window_index:pane_index,window_index:pane_index,...
#   - Notifications are added for each window:pane pair
#   - Same window_index = same window (tests deduplication)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$SCRIPT_DIR/../target/release/tmux-notify"
TEST_DB="/tmp/tmux-notify-test-$$.db"
TEST_SESSION="tmux-notify-test-$$"

# Count test cases: "name|setup|expected_count"
# Setup format: window_index:pane_index,... (same window_index = same window)
COUNT_TESTS=(
    "empty db|none|0"
    "single notification|1:0|1"
    "two panes same window|1:0,1:1|1"
    "two different windows|1:0,2:0|2"
    "three windows|1:0,2:0,3:0|3"
    "mixed: 2 panes in win1, 1 in win2|1:0,1:1,2:0|2"
    "four panes in two windows|1:0,1:1,2:0,2:1|2"
)

# Prune test cases: "name|real_panes|fake_panes|expected_pruned"
PRUNE_TESTS=(
    "prune single stale|none|%99999|1"
    "prune multiple stale|none|%99999,%99998|2"
    "prune mixed: keep real, remove stale|1:0|%99999|1"
    "prune nothing when all valid|1:0,2:0|none|0"
)

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
PASSED=0
FAILED=0

cleanup() {
    tmux kill-session -t "$TEST_SESSION" 2>/dev/null || true
    rm -f "$TEST_DB"
}
trap cleanup EXIT

notify() {
    "$BINARY" --db-path "$TEST_DB" "$@"
}

setup_session() {
    tmux new-session -d -s "$TEST_SESSION" -n "win1"
    tmux split-window -t "$TEST_SESSION:win1"
    tmux new-window -t "$TEST_SESSION" -n "win2"
    tmux split-window -t "$TEST_SESSION:win2"
    tmux new-window -t "$TEST_SESSION" -n "win3"
    tmux split-window -t "$TEST_SESSION:win3"
    sleep 0.3
}

# Get pane_id for window:pane index
get_pane_id() {
    local win_idx="$1"
    local pane_idx="$2"
    tmux list-panes -t "$TEST_SESSION:win${win_idx}" -F '#{pane_id}' | sed -n "$((pane_idx + 1))p"
}

run_count_test() {
    local name="$1"
    local setup="$2"
    local expected="$3"

    rm -f "$TEST_DB"

    if [[ "$setup" != "none" ]]; then
        IFS=',' read -ra pairs <<< "$setup"
        for pair in "${pairs[@]}"; do
            local win_idx pane_idx pane_id
            win_idx="${pair%%:*}"
            pane_idx="${pair##*:}"
            pane_id=$(get_pane_id "$win_idx" "$pane_idx")
            notify add -t "Test" -m "msg" -p "$pane_id" >/dev/null
        done
    fi

    local actual
    actual=$(notify count)

    if [[ "$actual" == "$expected" ]]; then
        echo -e "${GREEN}✓${NC} $name"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗${NC} $name (expected: $expected, got: $actual)"
        FAILED=$((FAILED + 1))
    fi
}

run_prune_test() {
    local name="$1"
    local real_setup="$2"
    local fake_panes="$3"
    local expected="$4"

    rm -f "$TEST_DB"

    # Add real pane notifications
    if [[ "$real_setup" != "none" ]]; then
        IFS=',' read -ra pairs <<< "$real_setup"
        for pair in "${pairs[@]}"; do
            local win_idx pane_idx pane_id
            win_idx="${pair%%:*}"
            pane_idx="${pair##*:}"
            pane_id=$(get_pane_id "$win_idx" "$pane_idx")
            notify add -t "Real" -m "msg" -p "$pane_id" >/dev/null
        done
    fi

    # Add fake pane notifications
    if [[ "$fake_panes" != "none" ]]; then
        IFS=',' read -ra fakes <<< "$fake_panes"
        for fake in "${fakes[@]}"; do
            notify add -t "Fake" -m "msg" -p "$fake" >/dev/null
        done
    fi

    # Get valid panes and prune
    local valid_panes
    valid_panes=$(tmux list-panes -t "$TEST_SESSION" -a -F '#{pane_id}' | tr '\n' ',')
    local result
    result=$(notify prune --valid-panes "$valid_panes")
    local actual
    actual=$(echo "$result" | grep -o '"pruned":[0-9]*' | grep -o '[0-9]*')

    if [[ "$actual" == "$expected" ]]; then
        echo -e "${GREEN}✓${NC} $name"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗${NC} $name (expected: $expected, got: $actual)"
        FAILED=$((FAILED + 1))
    fi
}

main() {
    echo "tmux-notify e2e tests"
    echo "====================="

    [[ -z "$TMUX" ]] && { echo "Error: run inside tmux"; exit 1; }
    [[ ! -x "$BINARY" ]] && cargo build --release

    setup_session

    echo "Count tests (window deduplication):"
    for tc in "${COUNT_TESTS[@]}"; do
        IFS='|' read -r name setup expected <<< "$tc"
        run_count_test "$name" "$setup" "$expected"
    done

    echo ""
    echo "Prune tests (stale pane cleanup):"
    for tc in "${PRUNE_TESTS[@]}"; do
        IFS='|' read -r name real fake expected <<< "$tc"
        run_prune_test "$name" "$real" "$fake" "$expected"
    done

    echo "====================="
    echo -e "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"
    [[ $FAILED -gt 0 ]] && exit 1 || exit 0
}

main "$@"
