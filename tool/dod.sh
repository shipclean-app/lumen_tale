#!/usr/bin/env bash
# The Definition of Done, as ONE command with ONE verdict.
#
# ## Why this file exists
#
# Three consecutive sessions recorded "`consistency-check all` **pass**" in
# `SESSION_LOG.md`. The command's exit code was **1**. They had read the LAST LINE of
# its output — which was `phase_journal: pass` — instead of its status. The suite was
# green the whole time, so nothing looked wrong.
#
# A verdict that can be read off the wrong part of a long output is not a verdict.
# This script therefore:
#
#   * runs every gate and keeps its **EXIT CODE**, never its tail;
#   * prints one line per gate, then **exactly one** summary line;
#   * exits non-zero if any gate is red.
#
# Nothing here decides whether the work is good. It only makes "green" mean one thing.
#
# ## Usage
#
#   tool/dod.sh              # the five gates that need no device
#   tool/dod.sh 3-2          # …and forge-exit for one slice
#
# `SKIP` is never counted as `PASS`. A gate that could not run is reported as
# `SKIP`, and the summary says `INCOMPLETE` rather than `PASS` — a check that does not
# run announces what it did not cover instead of returning a green it did not earn.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

SLICE="${1:-}"

# The Forge guards live in the skill directory, which is NOT vendored into this
# repository (see `.github/workflows/ci.yml`, Gate 5). So they may legitimately be
# absent — and when they are, the summary must not claim they were green.
FORGE="${FORGE:-$HOME/.agents/skills/forge}"

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; OFF=$'\033[0m'
if [ ! -t 1 ]; then RED=""; GREEN=""; YELLOW=""; BOLD=""; OFF=""; fi

names=(); states=(); notes=()
record() { names+=("$1"); states+=("$2"); notes+=("${3:-}"); }
banner() { printf '%s\n' "${BOLD}── $1 ${OFF}"; }

# ── Gate 1 — format ────────────────────────────────────────────────────────────
banner "format"
out="$(dart format --output=none --set-exit-if-changed . 2>&1)"; code=$?
if [ $code -eq 0 ]; then
  record format PASS
  printf '  %sPASS%s  no diff\n' "$GREEN" "$OFF"
else
  record format FAIL "reformat and re-run"
  printf '  %sFAIL%s  dart format would change files\n' "$RED" "$OFF"
  printf '%s\n' "$out" | tail -5 | sed 's/^/        /'
fi

# ── Gate 2 — analyze ───────────────────────────────────────────────────────────
# `--fatal-infos`, because AGENTS.md's item 2 counts zero `info` as a failure. Without
# the flag `flutter analyze` exits 0 with infos, and the gate is decorative.
banner "analyze"
out="$(flutter analyze --fatal-infos 2>&1)"; code=$?
if [ $code -eq 0 ]; then
  record analyze PASS
  printf '  %sPASS%s  zero issues, zero infos\n' "$GREEN" "$OFF"
else
  record analyze FAIL "fix, or weaken nothing"
  printf '  %sFAIL%s\n' "$RED" "$OFF"
  printf '%s\n' "$out" | grep -E '^\s+(error|warning|info)' | head -12 | sed 's/^/        /'
fi

# ── Gate 3 — the host suite ────────────────────────────────────────────────────
banner "test"
out="$(flutter test 2>&1)"; code=$?
# The count is parsed for the reader's benefit only. The VERDICT is `$code`.
summary="$(printf '%s\n' "$out" | grep -oE '\+[0-9]+( ~[0-9]+)?( -[0-9]+)?: (All tests passed|Some tests failed)' | tail -1)"
if [ $code -eq 0 ]; then
  record test PASS "$summary"
  printf '  %sPASS%s  %s\n' "$GREEN" "$OFF" "${summary:-all green}"
else
  record test FAIL "a test failed"
  printf '  %sFAIL%s  %s\n' "$RED" "$OFF" "${summary:-see below}"
  printf '%s\n' "$out" | grep -A 30 '^Failing tests:' | head -14 | sed 's/^/        /'
fi

# ── Gate 4 — the plan corpus ──────────────────────────────────────────────────
banner "plan corpus"
if [ -f .forge/plans/check_plans.py ]; then
  out="$(python3 .forge/plans/check_plans.py 2>&1)"; code=$?
  if [ $code -eq 0 ]; then
    record plan-corpus PASS
    printf '  %sPASS%s  derived counts agree\n' "$GREEN" "$OFF"
  else
    record plan-corpus FAIL
    printf '  %sFAIL%s\n' "$RED" "$OFF"
    printf '%s\n' "$out" | tail -8 | sed 's/^/        /'
  fi
else
  record plan-corpus SKIP "check_plans.py absent"
  printf '  %sSKIP%s  .forge/plans/check_plans.py not found\n' "$YELLOW" "$OFF"
fi

# ── Gate 5 — the architecture boundary ─────────────────────────────────────────
# ⚠️ **NEW, and it exists because F-018 was invisible for sessions.** Ten cross-feature
# imports — a DATABASE provider reached through a *history* feature, the library providers
# reached through a library *screen* — and `flutter analyze` does not check architecture.
#
# A crossing is either fixed or declared in `tool/boundaries.allowlist`; an undeclared one
# fails. "Declared" is not "allowed": the declaration is the record.
banner "boundaries"
if [ -f tool/check_boundaries.py ]; then
  out="$(python3 tool/check_boundaries.py . 2>&1)"; code=$?
  declared="$(printf '%s\n' "$out" | grep -c 'DECLARED crossing' || true)"
  if [ $code -eq 0 ]; then
    record boundaries PASS
    printf '  %sPASS%s  no undeclared crossings' "$GREEN" "$OFF"
    if [ "${declared:-0}" -gt 0 ]; then
      printf ' (%s declared)\n' "$declared"
      printf '%s\n' "$out" | grep -oE '^  lib/[^ ]+' | sed 's/^/        /'
    else
      printf '\n'
    fi
  else
    record boundaries FAIL "cross-feature import"
    printf '  %sFAIL%s\n' "$RED" "$OFF"
    printf '%s\n' "$out" | grep -E '^  lib/' | head -10 | sed 's/^/        /'
  fi
else
  record boundaries SKIP "check_boundaries.py absent"
  printf '  %sSKIP%s  tool/check_boundaries.py not found\n' "$YELLOW" "$OFF"
fi

# ── Gates 6 and 7 — the Forge guards ──────────────────────────────────────────
run_forge() {
  local label="$1" script="$2"; shift 2
  if [ ! -f "$FORGE/scripts/$script" ]; then
    record "$label" SKIP "$script absent at $FORGE"
    printf '  %sSKIP%s  %s not found — set FORGE=<skill dir>\n' "$YELLOW" "$OFF" "$script"
    return
  fi
  local out; out="$(node "$FORGE/scripts/$script" "$@" 2>&1)"; local code=$?
  if [ $code -eq 0 ]; then
    record "$label" PASS
    printf '  %sPASS%s  %s\n' "$GREEN" "$OFF" "$script"
  else
    record "$label" FAIL "$script exited $code"
    printf '  %sFAIL%s  %s exited %s\n' "$RED" "$OFF" "$script" "$code"
    # ⚠️ The failing CHECKS, not the tail. Reading the tail is what produced three
    # sessions of recorded green that were a 1.
    printf '%s\n' "$out" \
      | grep -B 2 -E '"status"[[:space:]]*:[[:space:]]*"(fail|warn)"' \
      | grep -E '"check"|"status"' | head -12 | sed 's/^/        /'
  fi
}

banner "forge guards"
run_forge forge-guard  forge-guard.js      all .
run_forge consistency  consistency-check.js all .

if [ -n "$SLICE" ]; then
  banner "forge-exit $SLICE"
  run_forge "forge-exit $SLICE" forge-exit.js . "$SLICE"
fi

# ── ONE verdict ───────────────────────────────────────────────────────────────
green=0; red=0; skipped=0; red_names=(); skip_names=()
for i in "${!names[@]}"; do
  case "${states[$i]}" in
    PASS)    green=$((green + 1)) ;;
    FAIL)    red=$((red + 1));   red_names+=("${names[$i]}") ;;
    SKIP)    skipped=$((skipped + 1)); skip_names+=("${names[$i]}") ;;
  esac
done
total=${#names[@]}

banner "verdict"
printf '\n'
if [ $red -gt 0 ]; then
  printf '%sDoD: FAIL%s — %s of %s gates red: %s\n' \
    "$RED$BOLD" "$OFF" "$red" "$total" "$(IFS=, ; echo "${red_names[*]}")"
  exit 1
elif [ $skipped -gt 0 ]; then
  # ⚠️ **SKIP IS NOT PASS.** A gate that could not run has not cleared anything, and
  # reporting `INCOMPLETE` is the whole reason this branch exists.
  printf '%sDoD: INCOMPLETE%s — %s of %s green, %s could not run: %s\n' \
    "$YELLOW$BOLD" "$OFF" "$green" "$total" "$skipped" "$(IFS=, ; echo "${skip_names[*]}")"
  exit 2
else
  printf '%sDoD: PASS%s — %s of %s gates green\n' "$GREEN$BOLD" "$OFF" "$green" "$total"
  exit 0
fi