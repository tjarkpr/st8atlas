#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ST8="${REPO_ROOT}/src/st8atlas.sh"

FAILURES=0

# terraform/terragrunt are stubbed so the tests stay offline and side effect free.
STUB_DIR="$(mktemp -d)"
for stub in terraform terragrunt; do
  printf '#!/usr/bin/env bash\necho "STUB %s $*"\n' "$stub" > "${STUB_DIR}/${stub}"
  chmod +x "${STUB_DIR}/${stub}"
done
PATH="${STUB_DIR}:${PATH}"
export PATH

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$STUB_DIR" "$WORK_DIR"' EXIT

pass() { echo "  ok   - $1"; }
fail() { echo "  FAIL - $1"; FAILURES=$((FAILURES + 1)); }

assert_success() {
  local description="$1"
  shift
  if "$@" > /dev/null 2>&1; then pass "$description"; else fail "$description"; fi
}

assert_failure() {
  local description="$1"
  shift
  if "$@" > /dev/null 2>&1; then fail "$description"; else pass "$description"; fi
}

assert_path() {
  local description="$1" path="$2"
  if [[ -e "$path" ]]; then pass "$description"; else fail "$description ('$path' missing)"; fi
}

assert_no_path() {
  local description="$1" path="$2"
  if [[ ! -e "$path" ]]; then pass "$description"; else fail "$description ('$path' still exists)"; fi
}

assert_file_contains() {
  local description="$1" path="$2" expected="$3"
  if [[ -f "$path" ]] && grep -q -- "$expected" "$path"; then
    pass "$description"
  else
    fail "$description (expected '$expected' in '$path')"
  fi
}

assert_file_lacks() {
  local description="$1" path="$2" unexpected="$3"
  if [[ -f "$path" ]] && grep -q -- "$unexpected" "$path"; then
    fail "$description ('$unexpected' still in '$path')"
  else
    pass "$description"
  fi
}

assert_output() {
  local description="$1" expected="$2"
  shift 2
  local actual
  actual="$("$@" 2>&1 || true)"
  if [[ "$actual" == *"$expected"* ]]; then
    pass "$description"
  else
    fail "$description (expected '$expected' in output)"
    echo "$actual" | sed 's/^/         /'
  fi
}

echo "syntax"
while IFS= read -r script; do
  assert_success "bash -n ${script#"$REPO_ROOT/"}" bash -n "$script"
done < <(find "$REPO_ROOT/src" "$REPO_ROOT/install.sh" -name '*.sh' | sort)

echo "guards"
cd "$WORK_DIR"
assert_failure "stack add outside of a project fails" bash "$ST8" stack add --name demo
assert_failure "unit list outside of a project fails" bash "$ST8" unit list
assert_output "unknown command is reported" "Unknown command" bash "$ST8" bogus

echo "init"
PROJECT_DIR="${WORK_DIR}/project"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"
assert_success "init creates a project" bash "$ST8" init
assert_path "state file exists" "${PROJECT_DIR}/atlas.st8"
assert_path "stacks directory exists" "${PROJECT_DIR}/stacks"
assert_path "units directory exists" "${PROJECT_DIR}/units"
assert_path "modules directory exists" "${PROJECT_DIR}/modules"
assert_no_path "no root.hcl at project level" "${PROJECT_DIR}/root.hcl"
assert_failure "init without --force is not repeatable" bash "$ST8" init
assert_success "init --force re-initializes" bash "$ST8" init --force
assert_failure "unknown init argument rejected" bash "$ST8" init --bogus

echo "stack"
assert_success "stack add" bash "$ST8" stack add --name network --description "Network stack"
assert_path "stack file created" "${PROJECT_DIR}/stacks/network/terragrunt.stack.hcl"
assert_success "stack add with explicit path" bash "$ST8" stack add --name platform --path shared/platform
assert_path "stack file at explicit path" "${PROJECT_DIR}/stacks/shared/platform/terragrunt.stack.hcl"
assert_path "root.hcl at the stacks directory" "${PROJECT_DIR}/stacks/root.hcl"
assert_path "root.hcl at the intermediate level" "${PROJECT_DIR}/stacks/shared/root.hcl"
assert_no_path "no root.hcl in the stack directory" "${PROJECT_DIR}/stacks/shared/platform/root.hcl"
assert_no_path "no root.hcl in a top level stack directory" "${PROJECT_DIR}/stacks/network/root.hcl"
assert_file_lacks "top level root.hcl has no parent" "${PROJECT_DIR}/stacks/root.hcl" "find_in_parent_folders"
assert_file_contains "intermediate root.hcl inherits upwards" "${PROJECT_DIR}/stacks/shared/root.hcl" "find_in_parent_folders"
assert_file_contains "stack file includes the root above" "${PROJECT_DIR}/stacks/shared/platform/terragrunt.stack.hcl" "find_in_parent_folders"
assert_failure "duplicate stack rejected" bash "$ST8" stack add --name network
assert_failure "invalid stack name rejected" bash "$ST8" stack add --name "bad name"
assert_failure "path traversal rejected" bash "$ST8" stack add --name escape --path ../outside
assert_output "stack list shows the stack" "network" bash "$ST8" stack list
assert_output "stack plan delegates to terragrunt" "STUB terragrunt stack run plan" bash "$ST8" stack plan --name network
assert_output "stack format delegates to terragrunt" "STUB terragrunt hclfmt" bash "$ST8" stack format
assert_failure "stack action on unknown stack fails" bash "$ST8" stack plan --name missing

echo "unit"
assert_success "unit add" bash "$ST8" unit add --name storage --description "Storage unit"
assert_path "unit file created" "${PROJECT_DIR}/units/storage/terragrunt.hcl"
assert_path "module main.tf created" "${PROJECT_DIR}/modules/storage/main.tf"
assert_path "module variables.tf created" "${PROJECT_DIR}/modules/storage/variables.tf"
assert_path "module outputs.tf created" "${PROJECT_DIR}/modules/storage/outputs.tf"
assert_failure "duplicate unit rejected" bash "$ST8" unit add --name storage
assert_output "unit list shows the unit" "storage" bash "$ST8" unit list
assert_output "unit validate delegates to terragrunt" "STUB terragrunt validate" bash "$ST8" unit validate --name storage

echo "relations"
assert_success "unit add for selection" bash "$ST8" unit add --name database --description "Database unit"
assert_success "stack units selects units" bash "$ST8" stack units --name network --units storage,database
assert_file_contains "stack file references the unit" "${PROJECT_DIR}/stacks/network/terragrunt.stack.hcl" 'unit "storage"'
assert_failure "unknown unit in --units rejected" bash "$ST8" stack units --name network --units nope
assert_success "stack add with --units" bash "$ST8" stack add --name edge --units database
assert_file_contains "new stack references the unit" "${PROJECT_DIR}/stacks/edge/terragrunt.stack.hcl" 'unit "database"'
assert_output "stack list reports the unit count" "UNITS" bash "$ST8" stack list
assert_output "unit list reports the stack count" "STACKS" bash "$ST8" unit list

if bash "$ST8" stack list | grep -E '^network' | grep -qE '\s2\s'; then
  pass "stack list counts two units"
else
  fail "stack list counts two units"
fi
if bash "$ST8" unit list | grep -E '^database' | grep -qE '\s2\s'; then
  pass "unit list counts two stacks"
else
  fail "unit list counts two stacks"
fi

assert_failure "removing a used unit is refused" bash "$ST8" unit remove --name database
assert_path "refused removal keeps the unit" "${PROJECT_DIR}/units/database/terragrunt.hcl"
assert_success "--force removes a used unit" bash "$ST8" unit remove --name database --force
assert_no_path "forced removal deletes the unit" "${PROJECT_DIR}/units/database"
assert_success "stack units clears the selection" bash "$ST8" stack units --name network --units storage
assert_file_lacks "cleared unit is gone from the stack" "${PROJECT_DIR}/stacks/network/terragrunt.stack.hcl" 'unit "database"'
assert_success "stack remove for the extra stack" bash "$ST8" stack remove --name edge

echo "sync"
mkdir -p "${PROJECT_DIR}/stacks/manual"
touch "${PROJECT_DIR}/stacks/manual/terragrunt.stack.hcl"
assert_success "stack sync" bash "$ST8" stack sync
assert_output "stack sync registers manual stacks" "manual" bash "$ST8" stack list
assert_no_path "stack sync keeps the stack directory free of root.hcl" "${PROJECT_DIR}/stacks/manual/root.hcl"
assert_path "stack sync backfills the root.hcl above" "${PROJECT_DIR}/stacks/root.hcl"
rm -rf "${PROJECT_DIR}/stacks/manual"
assert_success "stack sync after removal" bash "$ST8" stack sync
if bash "$ST8" stack list 2>&1 | grep -q manual; then
  fail "stack sync drops removed stacks"
else
  pass "stack sync drops removed stacks"
fi

mkdir -p "${PROJECT_DIR}/units/manual" "${PROJECT_DIR}/modules/manual"
touch "${PROJECT_DIR}/units/manual/terragrunt.hcl"
assert_success "unit sync" bash "$ST8" unit sync
assert_output "unit sync registers manual units" "manual" bash "$ST8" unit list

echo "remove"
assert_success "stack remove" bash "$ST8" stack remove --name network
assert_no_path "stack directory removed" "${PROJECT_DIR}/stacks/network"
assert_success "unit remove" bash "$ST8" unit remove --name storage
assert_no_path "unit directory removed" "${PROJECT_DIR}/units/storage"
assert_no_path "module directory removed" "${PROJECT_DIR}/modules/storage"
assert_failure "removing an unknown stack fails" bash "$ST8" stack remove --name network

echo
if [[ $FAILURES -eq 0 ]]; then
  echo "All checks passed."
else
  echo "${FAILURES} check(s) failed."
  exit 1
fi
