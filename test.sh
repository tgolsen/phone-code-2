#!/bin/bash
# Phone Code test suite

echo "Phone Code Tests"
echo "================"

PASSED=0
FAILED=0

pass() { echo "  PASS $1"; ((++PASSED)); true; }
fail() { echo "  FAIL $1: $2"; ((++FAILED)); true; }

# ── Script presence ──────────────────────────────────────────

[ -x "./phone-code" ] && pass "phone-code is executable" || fail "phone-code is executable" "not found or not executable"
[ -x "./entrypoint.sh" ] && pass "entrypoint.sh is executable" || fail "entrypoint.sh is executable" "not found or not executable"

# ── Shell scripts syntax check ───────────────────────────────

for script in phone-code entrypoint.sh; do
    if bash -n "$script" 2>/dev/null; then
        pass "$script syntax valid"
    else
        fail "$script syntax valid" "bash -n failed"
    fi
done

# ── Config ───────────────────────────────────────────────────

[ -f "config.example" ] && pass "config.example exists" || fail "config.example exists" "not found"
[ -f "infra/terraform.tfvars.example" ] && pass "terraform.tfvars.example exists" || fail "terraform.tfvars.example exists" "not found"

# ── Dockerfile ───────────────────────────────────────────────

[ -f "Dockerfile" ] && pass "Dockerfile exists" || fail "Dockerfile exists" "not found"

# ── Lambda ───────────────────────────────────────────────────

[ -f "session-broker/index.js" ] && pass "Lambda index.js exists" || fail "Lambda index.js exists" "not found"
[ -f "session-broker/package.json" ] && pass "Lambda package.json exists" || fail "Lambda package.json exists" "not found"

# ── Lambda syntax check (if node available) ──────────────────

if command -v node >/dev/null 2>&1; then
    if node -c session-broker/index.js 2>/dev/null; then
        pass "Lambda index.js syntax valid"
    else
        fail "Lambda index.js syntax valid" "node -c failed"
    fi
fi

# ── Terraform (if available) ─────────────────────────────────

if command -v terraform >/dev/null 2>&1; then
    if terraform fmt -check infra/ 2>/dev/null; then
        pass "Terraform formatting valid"
    else
        echo "  INFO: Terraform formatting needs fixing (run: terraform fmt infra/)"
    fi
fi

# ── Shellcheck (if available) ────────────────────────────────

if command -v shellcheck >/dev/null 2>&1; then
    echo ""
    echo "Shellcheck:"
    shellcheck phone-code entrypoint.sh && pass "Shellcheck passed" || fail "Shellcheck" "issues found"
else
    echo "  INFO: shellcheck not installed (brew install shellcheck)"
fi

# ── Usage message ────────────────────────────────────────────

if ./phone-code --help 2>&1 | grep -q "Usage:"; then
    pass "Usage message displayed"
else
    fail "Usage message displayed" "no Usage: in output"
fi

# ── Summary ──────────────────────────────────────────────────

echo ""
echo "Results: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ] && echo "All tests passed." || exit 1
