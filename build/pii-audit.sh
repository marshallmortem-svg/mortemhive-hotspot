#!/usr/bin/env bash
# pii-audit.sh — fail if personal data appears in the given paths.
#
# Layers:
#   1. GENERIC patterns (safe to publish, no literal secrets): credential
#      assignments, coordinate lines (paired or keyed), e-mail addresses,
#      tokens, and US-callsign shapes (case-sensitive; public attributions
#      and documented placeholder values are excluded per-match).
#   2. Optional local deny-list at build/pii-audit.local (gitignored, NEVER in
#      the repo). Format, one entry per line:
#         plain string   -> content scan (case-insensitive literal)
#         F:string       -> filename scan (substring of a file/folder NAME)
#         #comment       -> ignored
#      Use F: only for DISTINCTIVE identifiers (common surnames as filename
#      rules collide with stock packages and stock timezone data).
#
# Modes:
#   pii-audit.sh [path ...]              full (generic + local list)
#   pii-audit.sh --filename-only [p...]  names only (for whole-image sweeps)
#
# Fails CLOSED: an unreadable/missing target is an error, not a pass.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

FILENAME_ONLY=0
if [ "${1:-}" = "--filename-only" ]; then
  FILENAME_ONLY=1
  shift
fi

TARGETS=("$@")
if [ ${#TARGETS[@]} -eq 0 ]; then
  TARGETS=("$(cd "$HERE/.." && pwd)")
fi
LOCAL_LIST="$HERE/pii-audit.local"

for t in "${TARGETS[@]}"; do
  if [ ! -e "$t" ]; then
    echo "PII AUDIT ERROR: target does not exist: $t"
    exit 2
  fi
done

# credential-looking assignments; keys; paired OR keyed coordinates; e-mails
GENERIC_CI='psk=[^ "]{8,}|psk="[^"]+"|sshpass -p [^$]|[0-9]{1,3}[.][0-9]{4,} *[,/] *-?[0-9]{1,3}[.][0-9]{4,}|(Latitude|Longitude)[=:] *[-+]?[0-9]{1,3}[.][0-9]{4,}|@[a-z0-9.-]+[.](com|net|org|edu)|api[_-]?key|secret[=:]|token[=:]|[Pp]assword["]?[=:] *["]?[^" ]+'
# US-callsign shapes: 1x, 2x1, 2x2, 2x3 prefixes; case-SENSITIVE so lower-case
# tech tokens and hex do not false-positive. Public credits / placeholders are
# evaluated per matched fragment, not by dropping the whole line.
GENERIC_CS='\b[AKNW][A-Z]?[0-9][A-Z]{1,3}\b'
ALLOW_FRAG='^(N0CALL|G4KLX|MW0MWZ)$'
# documented placeholder VALUES (not secrets) that may appear in a clean kit
ALLOW_VAL='[Pp]assword["]?[=:] *["]?(CHANGE_ME|PASSWORD|none|NONE|YOUR_[A-Z_]+|raspberry)["]? *$'

clean_filter() {
  grep -v "Binary file" | grep -v "[.]sha256:" \
    | grep -v "pii-audit[.]local" \
    | grep -vE "$ALLOW_VAL" \
    | grep -vE "pii-audit[.]sh:[0-9]+:(GENERIC_CI|GENERIC_CS|ALLOW_FRAG|ALLOW_VAL|HITS)="
}

HITS=""
if [ "$FILENAME_ONLY" -eq 0 ]; then
  _h1=$(grep -rniE -I --exclude-dir=.git "$GENERIC_CI" "${TARGETS[@]}" 2>/dev/null | clean_filter || true)
  _h2=$(grep -rnE -I --exclude-dir=.git "$GENERIC_CS" "${TARGETS[@]}" 2>/dev/null \
    | while IFS= read -r ln; do
        f=$(printf '%s' "$ln" | grep -oE "$GENERIC_CS" | grep -vE "$ALLOW_FRAG" || true)
        [ -n "$f" ] && printf '%s\n' "$ln"
      done | grep -v "Binary file" | grep -v "[.]sha256:" || true)
  HITS="$_h1"$'\n'"$_h2"
fi

if [ -f "$LOCAL_LIST" ]; then
  echo "strict mode: local deny-list active"
  while IFS= read -r entry || [ -n "$entry" ]; do
    [ -z "$entry" ] && continue
    case "$entry" in \#*) continue;; esac
    case "$entry" in
      F:*)
        pat="${entry#F:}"
        fh=$(find "${TARGETS[@]}" \( -path "*/.git" -o -path "*/usr/share/zoneinfo" \) -prune \
             -o -iname "*${pat}*" -print 2>/dev/null || true)
        [ -n "$fh" ] && HITS="$HITS"$'\n'"FNAME: $fh"
        ;;
      *)
        if [ "$FILENAME_ONLY" -eq 0 ]; then
          h=$(grep -rniF -I -e "$entry" --exclude-dir=.git "${TARGETS[@]}" 2>/dev/null \
              | grep -v "Binary file" | grep -v "[.]sha256:" \
              | grep -v "pii-audit[.]local" || true)
          [ -n "$h" ] && HITS="$HITS"$'\n'"$h"
        fi
        ;;
    esac
  done < "$LOCAL_LIST"
fi

if [ -n "$(printf '%s' "$HITS" | tr -d ' \n')" ]; then
  echo "PII AUDIT FAILED:"
  printf '%s\n' "$HITS" | grep -v '^$'
  exit 1
fi
echo "PII audit clean: ${TARGETS[*]}"
