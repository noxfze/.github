#!/usr/bin/env bash
# Identity guard: every commit in this repository is authored and committed by
# Nox FZE through the noxfze-admin account, and carries no co-author or other
# attribution trailers. Shared by the git hooks (local) and the CI check
# (GitHub), so both enforce exactly the same rule.
#
#   identity-guard.sh config         the repository's git identity is the canonical one
#   identity-guard.sh message <file> a commit message has no attribution trailers
#   identity-guard.sh range <range>  every commit in <range> passes both checks
set -euo pipefail

readonly NAME='Nox FZE'
readonly EMAIL='336414419+noxfze-admin@users.noreply.github.com'
# Attribution trailers of any kind, plus "generated with/by" footers.
readonly FORBIDDEN='^(co-authored-by|[a-z0-9-]*-session|generated-by|signed-off-by)[[:space:]]*:|generated (with|by) '

fail() { echo "identity-guard: $*" >&2; exit 1; }

check_message() {
  if grep -Eiq "$FORBIDDEN" "$1"; then fail "attribution trailer in commit message: $(grep -Ei "$FORBIDDEN" "$1" | head -1)"; fi
  # Optional local denylist (never committed): .git/info/identity-denylist, one word per line.
  local deny; deny="$(git rev-parse --git-dir 2>/dev/null)/info/identity-denylist"
  if [[ -f "$deny" ]] && grep -Fiqf <(grep -v '^\s*$' "$deny") "$1"; then fail 'commit message contains a denylisted word'; fi
}

case "${1:-}" in
  config)
    [[ "$(git config user.name)" == "$NAME" && "$(git config user.email)" == "$EMAIL" ]] \
      || fail "git identity must be '$NAME <$EMAIL>' (git config user.name / user.email)" ;;
  message)
    check_message "$2" ;;
  range)
    tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
    for c in $(git rev-list "$2"); do
      who="$(git log -1 --format='%an <%ae>|%cn <%ce>' "$c")"
      [[ "$who" == "$NAME <$EMAIL>|$NAME <$EMAIL>" ]] || fail "commit ${c:0:7} has identity $who"
      git log -1 --format=%B "$c" > "$tmp"; check_message "$tmp"
    done ;;
  *) fail 'usage: identity-guard.sh config | message <file> | range <range>' ;;
esac
