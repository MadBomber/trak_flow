#!/usr/bin/env bash
#
# TrakFlow CLI Demo
#
# This script demonstrates how to use the `tf` command-line interface.
# Run from the examples directory: ./cli_demo.sh
#
# Options:
#   -n, --no-pause  Run without pausing between sections (for testing)
#

set -e

# Parse options
NO_PAUSE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--no-pause)
      NO_PAUSE=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Determine project root and set up environment
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
export PATH="$PROJECT_DIR/bin:$PATH"
export BUNDLE_GEMFILE="$PROJECT_DIR/Gemfile"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

header() {
  echo ""
  echo -e "${BLUE}============================================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}============================================================${NC}"
  echo ""
}

run_cmd() {
  echo -e "${YELLOW}\$ $1${NC}"
  eval "$1"
  echo ""
}

pause() {
  if [ "$NO_PAUSE" = false ]; then
    echo -e "${GREEN}Press Enter to continue...${NC}"
    read -r
  fi
}

# Create temp directory for demo
DEMO_DIR=$(mktemp -d -t trak_flow_demo)
cd "$DEMO_DIR"

cleanup() {
  echo ""
  echo -e "${RED}Cleaning up demo directory...${NC}"
  rm -rf "$DEMO_DIR"
  echo "Done."
}
trap cleanup EXIT

header "TrakFlow CLI Demo"
echo "Demo directory: $DEMO_DIR"
echo ""

# =============================================================================
header "1. Initialize TrakFlow"
# =============================================================================

run_cmd "tf init"
run_cmd "tf info"

pause

# =============================================================================
header "2. Create Tasks"
# =============================================================================

echo "Creating various task types..."
echo ""

run_cmd "tf create 'Build user authentication' -t epic -p 1"
run_cmd "tf create 'Design database schema' -t task -p 1 -d 'Create tables for users and sessions'"
run_cmd "tf create 'Implement login endpoint' -t feature -p 2"
run_cmd "tf create 'Write integration tests' -t task -p 3"
run_cmd "tf create 'Fix password validation bug' -t bug -p 0"

pause

# =============================================================================
header "3. List and Show Tasks"
# =============================================================================

run_cmd "tf list"
run_cmd "tf list --status open"
run_cmd "tf list --priority 0"

echo "Showing task details (using first task ID from list)..."
TASK_ID=$(tf list -j 2>/dev/null | ruby -roj -e 'puts Oj.load(STDIN.read).first["id"]')
run_cmd "tf show $TASK_ID"

pause

# =============================================================================
header "4. Dependencies"
# =============================================================================

echo "Setting up blocking dependencies..."
echo ""

# Get task IDs
SCHEMA_ID=$(tf list -j 2>/dev/null | ruby -roj -e 'tasks = Oj.load(STDIN.read); puts tasks.find{|t| t["title"].include?("schema")}["id"]')
LOGIN_ID=$(tf list -j 2>/dev/null | ruby -roj -e 'tasks = Oj.load(STDIN.read); puts tasks.find{|t| t["title"].include?("login")}["id"]')
TEST_ID=$(tf list -j 2>/dev/null | ruby -roj -e 'tasks = Oj.load(STDIN.read); puts tasks.find{|t| t["title"].include?("tests")}["id"]')

run_cmd "tf dep add $SCHEMA_ID $LOGIN_ID -t blocks"
run_cmd "tf dep add $LOGIN_ID $TEST_ID -t blocks"

echo "Viewing dependency tree..."
run_cmd "tf dep tree $TEST_ID"

pause

# =============================================================================
header "5. Ready Work Detection"
# =============================================================================

echo "Finding tasks that are ready to work on (not blocked)..."
echo ""

run_cmd "tf ready"

pause

# =============================================================================
header "6. Labels"
# =============================================================================

BUG_ID=$(tf list -j 2>/dev/null | ruby -roj -e 'tasks = Oj.load(STDIN.read); puts tasks.find{|t| t["type"] == "bug"}["id"]')

run_cmd "tf label add $BUG_ID critical"
run_cmd "tf label add $BUG_ID security"
run_cmd "tf label list $BUG_ID"
run_cmd "tf label list-all"

pause

# =============================================================================
header "7. Task Lifecycle"
# =============================================================================

echo "Updating task status..."
echo ""

run_cmd "tf update $BUG_ID --status in_progress"
run_cmd "tf show $BUG_ID"

echo "Closing the task..."
run_cmd "tf close $BUG_ID -r 'Fixed regex to allow special characters'"
run_cmd "tf show $BUG_ID"

echo "Reopening if needed..."
run_cmd "tf reopen $BUG_ID -r 'Found another edge case'"
run_cmd "tf show $BUG_ID"

pause

# =============================================================================
header "8. Child Tasks (Epics)"
# =============================================================================

EPIC_ID=$(tf list -j 2>/dev/null | ruby -roj -e 'tasks = Oj.load(STDIN.read); puts tasks.find{|t| t["type"] == "epic"}["id"]')

echo "Creating child tasks under the epic..."
echo ""

run_cmd "tf create 'Setup OAuth providers' --parent $EPIC_ID -p 2"
run_cmd "tf create 'Add 2FA support' --parent $EPIC_ID -p 3"

run_cmd "tf show $EPIC_ID"

pause

# =============================================================================
header "9. Plans and Workflows"
# =============================================================================

echo "Creating a Plan (workflow blueprint)..."
echo ""

run_cmd "tf plan create 'Deploy to Production' -d 'Standard deployment workflow'"

PLAN_ID=$(tf plan list -j 2>/dev/null | ruby -roj -e 'puts Oj.load(STDIN.read).first["id"]')

echo "Adding steps to the Plan..."
run_cmd "tf plan add $PLAN_ID 'Run test suite' -p 1"
run_cmd "tf plan add $PLAN_ID 'Build artifacts' -p 2"
run_cmd "tf plan add $PLAN_ID 'Deploy to staging' -p 2"
run_cmd "tf plan add $PLAN_ID 'Run smoke tests' -p 2"
run_cmd "tf plan add $PLAN_ID 'Deploy to production' -p 1"

run_cmd "tf plan show $PLAN_ID"
run_cmd "tf plan list"

pause

# =============================================================================
header "10. Starting Workflows from Plans"
# =============================================================================

echo "Starting a persistent Workflow from the Plan..."
run_cmd "tf plan start $PLAN_ID"

run_cmd "tf workflow list"

WORKFLOW_ID=$(tf workflow list -j 2>/dev/null | ruby -roj -e 'puts Oj.load(STDIN.read).first["id"]')
run_cmd "tf workflow show $WORKFLOW_ID"

pause

# =============================================================================
header "11. Ephemeral Workflows"
# =============================================================================

echo "Creating an ephemeral (one-shot) Workflow..."
run_cmd "tf plan execute $PLAN_ID"

run_cmd "tf workflow list"
run_cmd "tf workflow list -e"

EPHEMERAL_ID=$(tf workflow list -e -j 2>/dev/null | ruby -roj -e 'puts Oj.load(STDIN.read).first["id"]')

echo "Discarding the ephemeral Workflow..."
run_cmd "tf workflow discard $EPHEMERAL_ID"

run_cmd "tf workflow list"

pause

# =============================================================================
header "12. Admin Commands"
# =============================================================================

echo "Analyzing the database..."
run_cmd "tf admin compact --analyze"

echo "Analyzing the dependency graph..."
run_cmd "tf admin analyze"

pause

# =============================================================================
header "13. JSON Output"
# =============================================================================

echo "All commands support -j for machine-readable output..."
echo ""

run_cmd "tf list -j | head -20"

pause

# =============================================================================
header "14. Syncing with JSONL"
# =============================================================================

echo "TrakFlow stores data in both SQLite and JSONL formats."
echo "The JSONL file is Git-friendly for version control."
echo ""

run_cmd "ls -la .trak_flow/"
run_cmd "head -5 .trak_flow/issues.jsonl"

pause

# =============================================================================
header "Demo Complete!"
# =============================================================================

cat << 'EOF'
What we demonstrated:
  - tf init          Initialize TrakFlow
  - tf create        Create tasks (bug, feature, task, epic, chore)
  - tf list          List tasks with filters
  - tf show          Show task details
  - tf update        Update task attributes
  - tf close         Close a task
  - tf reopen        Reopen a closed task
  - tf ready         Find tasks ready to work on
  - tf dep           Manage dependencies
  - tf label         Manage labels
  - tf plan          Create and manage workflow blueprints
  - tf workflow      Manage running workflows
  - tf admin         Administrative commands

For more help:
  tf --help
  tf <command> --help
EOF

echo ""
echo "Demo directory will be cleaned up on exit."
