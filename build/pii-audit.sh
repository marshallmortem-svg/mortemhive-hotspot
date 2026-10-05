#!/usr/bin/env bash
# pii-audit.sh — fail if personal data appears in the given paths.
#
# Two layers:
#   1. GENERIC patterns below — safe to publish (no literal secrets here):
#      credential-looking lines, coordinate pairs, e-mails, tokens, and
#      US-callsign shapes (case-sensitive, so tech tokens like i2c and hex
#      hashes don't false-positive; public attributions are allowlisted).
#   2. Optional local deny-list at build/pii-audit.local — one literal string
#      per line, gitignored, kept OUT of the repository on purpose. When
#      present it is the strict gate (exact strings + filename scan).
#
# Usage: pii-audit.sh [path ...]   (default: the kit root)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TARGETS=("$@")
if [ ${#TARGETS[@]} -eq 0 ]; then
  TARGETS=("$(cd "$HERE/.." && pwd)")
fi
LOCAL_LIST="$HERE/pii-audit.local"

GENERIC_CI='psk="[^"]|psk=[0-9a-fA-F]{16}|sshpass -p [^$]|[0-9]{1,3}[.][0-9]{4,} *[,/] *-?[0-9]{1,3}[.][0-9]{4,}|@[a-z0-9.-]+[.](com|net|org|edu)|api[_-]?key|secret[=:]|token[=:]'
GENERIC_CS='\b[A-KN-WY-Z][0-9][A-Z]{2,3}\b'
ALLOW='N0CALL|G4KLX|MW0MWZ'

clean_filter() {
  grep -v "Binary file" | grep -v "[.]sha256:" \
    | grep -v "pii-audit[.]sh" | grep -v "pii-audit[.]local" \
    | grep -vE "$ALLOW"
}

_h1=$(grep -rniE --exclude-dir=.git --exclude-dir=release "$GENERIC_CI" "${TARGETS[@]}" 2>/dev/null | clean_filter || true)
_h2=$(grep -rnE  --exclude-dir=.git --exclude-dir=release "$GENERIC_CS" "${TARGETS[@]}" 2>/dev/null | clean_filter || true)
HITS="$_h1"$'\n'"$_h2"

if [ -f "$LOCAL_LIST" ]; then
  echo "strict mode: local deny-list active"
  while IFS= read -r pat; do
    [ -z "$pat" ] && continue
    case "$pat" in \#*) continue;; esac
    h=$(grep -rniF --exclude-dir=.git --exclude-dir=release "$pat" "${TARGETS[@]}" 2>/dev/null \
        | grep -v "Binary file" | grep -v "[.]sha256:" \
        | grep -v "pii-audit[.]local" || true)
    [ -n "$h" ] && HITS="$HITS"$'\n'"$h"
    fh=$(find "${TARGETS[@]}" -path "*/.git" -prune -o -iname "*${pat}*" -print 2>/dev/null || true)
    [ -n "$fh" ] && HITS="$HITS"$'\n'"FNAME: $fh"
  done < "$LOCAL_LIST"
fi

if [ -n "$(printf '%s' "$HITS" | tr -d ' \n')" ]; then
  echo "PII AUDIT FAILED:"
  printf '%s\n' "$HITS" | grep -v '^$'
  exit 1
fi
echo "PII audit clean: ${TARGETS[*]}"
