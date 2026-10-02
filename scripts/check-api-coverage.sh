#!/usr/bin/env bash
#
# check-api-coverage.sh — fail if opx_infinity or opx_lib publishes a name the
# documentation does not document.
#
# The framework and the documentation live in different repositories, so this
# script has to be pointed at a checkout of the framework. It looks for
# opx_infinity, in order, at
#
#   $1                       an explicit path, if one is given
#   $OPX_INFINITY            an environment variable
#   ../opx_infinity  ../../opx_infinity  ../../../opx_infinity
#                            (relative to this repository)
#
# and for opx_lib at $OPX_LIB_PATH, then next to opx_infinity. With no
# opx_infinity checkout in reach it prints a note and exits 0: the docs
# repository must stay buildable on its own, and the docs CI runner has no
# framework checkout. Run it locally before you push:
#
#   npm run check:api
#   ./scripts/check-api-coverage.sh /path/to/opx_infinity
#
# It needs desktop Lua 5.4 (`lua5.4` or `lua` on the PATH) and Node. The
# published surface is not grepped, it is DUMPED: scripts/dump-surface.lua boots
# the real manifest against the framework's own stub host
# (opx_infinity/tests/host.lua) and prints every name the runtime registers.
# Most commands are registered under a name held in a variable or a config
# table, which a regular expression over the source cannot see.
#
# An entry is documented by an ANCHOR on a page of content/docs. An anchor is
# what scripts/anchors.mjs reads (and what Fumadocs renders as an id):
#
#   ## SetTime [#server-weather-settime]     a heading's explicit id
#   ## Commands                              a heading's generated id (#commands)
#   <a id="config-weather-enabled" />        an id attribute, e.g. in a table cell
#
# The anchor is the SLUG of the name: lower case, every run of characters
# outside [a-z0-9] replaced by one `-`, leading and trailing `-` dropped.
#
#   what                        anchor                                where (under content/docs/)
#   a module                    (the page itself)                     opx_infinity/<id>/index.mdx
#   a contract member           <side>-<contract>-<member>            opx_infinity/<contract>/
#   a chat command              <command>                             opx_infinity/<owner>/ (core: anywhere)
#   a command alias             the alias in backticks                opx_infinity/core/
#   a module event (net, on)    <event>                               opx_infinity/
#   an Open77 export            export-<side>-<name>                  creators/
#   a net event listened on     <event>                               anywhere
#   a page -> Lua channel       page-<channel>                        anywhere
#   a module config key         config-<module>-<KEY>                 opx_infinity/<module>/
#   a runtime config key        config-<shared|server|client>-<KEY>   opx_infinity/core/
#   a function on OPX           <OPX.Path>                            anywhere
#   an opx_lib function         lib-<Module>-<function>               opx_lib/
#
# Examples: `server-character-addmoney`, `opx-admin-player-goto`,
# `opx-net-chat-say`, `page-menu-choose`, `config-hud-anchor`,
# `config-server-command-aliases`, `opx-scheduler-every`, `lib-rpc-call`.
#
# `opx:in:` events are private to one module and are not checked. A module that
# does not reach `started` under the stub host is a failure, because the dump
# would then be missing its names without saying so.

set -euo pipefail

DOCS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTENT="$DOCS_ROOT/content/docs"

INFINITY="${1:-${OPX_INFINITY:-}}"
if [ -z "$INFINITY" ]; then
  for candidate in "$DOCS_ROOT/../opx_infinity" "$DOCS_ROOT/../../opx_infinity" "$DOCS_ROOT/../../../opx_infinity"; do
    if [ -f "$candidate/open77.lua" ]; then INFINITY="$candidate"; break; fi
  done
fi

if [ -z "$INFINITY" ] || [ ! -f "$INFINITY/open77.lua" ]; then
  echo "check-api-coverage: no opx_infinity checkout found — skipping."
  echo "  Pass one as \$1 or set \$OPX_INFINITY to run the check."
  exit 0
fi
INFINITY="$(cd "$INFINITY" && pwd)"

LIB="${OPX_LIB_PATH:-$INFINITY/../opx_lib}"
if [ ! -f "$LIB/init.lua" ]; then
  echo "check-api-coverage: no opx_lib checkout at $LIB — set \$OPX_LIB_PATH." >&2
  exit 1
fi
LIB="$(cd "$LIB" && pwd)"

LUA=""
for candidate in lua5.4 lua54 lua; do
  if command -v "$candidate" >/dev/null 2>&1; then LUA="$candidate"; break; fi
done
if [ -z "$LUA" ]; then
  echo "check-api-coverage: no Lua 5.4 interpreter on the PATH." >&2
  exit 1
fi
if ! command -v node >/dev/null 2>&1; then
  echo "check-api-coverage: no node on the PATH." >&2
  exit 1
fi

echo "check-api-coverage: opx_infinity at $INFINITY"
echo "check-api-coverage: opx_lib at $LIB"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# 1. The published surface.
( cd "$INFINITY" && OPX_LIB_PATH="$LIB" "$LUA" "$DOCS_ROOT/scripts/dump-surface.lua" ) \
  | tr -d '\r' > "$work/surface.txt"

# opx_lib: `Lib.<Name> = require('@opx_lib/<tier>.<file>')` in init.lua names
# the module, and every `function <Local>.<fn>` (or `:<fn>`) at the start of a
# line in that file is one of its functions.
grep -oE "^Lib\.[A-Za-z]+ = require\('@opx_lib/(pure|client)\.[a-z_]+'\)" "$LIB/init.lua" \
  | sed -E "s/^Lib\.([A-Za-z]+) = require\('@opx_lib\/(pure|client)\.([a-z_]+)'\)/\1 \2\/\3.lua/" \
  | while read -r name file; do
      { grep -hoE '^function [A-Za-z_]+[.:][A-Za-z_][A-Za-z0-9_]*' "$LIB/$file" || true; } \
        | sed -E "s/^function [A-Za-z_]+[.:]//; s/^/lib $name /"
    done >> "$work/surface.txt"

# 2. Every anchor, as "<file relative to content/docs>\t<anchor>".
node "$DOCS_ROOT/scripts/anchors.mjs" | tr -d '\r' > "$work/anchors.tsv"

# 3. Backticked words under opx_infinity/core/, for the aliases.
( grep -rhoE '`[a-z0-9_.:-]+`' --include='*.mdx' "$CONTENT/opx_infinity/core" 2>/dev/null || true ) \
  | tr -d '`\r' | sort -u > "$work/core-words.txt"

# 4. Requirements: kind, label, required location prefix ('' = anywhere), anchor.
awk '
  function slug(s) { s = tolower(s); gsub(/[^a-z0-9]+/, "-", s); gsub(/^-+|-+$/, "", s); return s }
  $1 == "module"     { print "module\t" $3 "\t" $4; next }
  $1 == "api"        { print "need\tcontract member " $2 " " $3 "." $4 "\topx_infinity/" $3 "/\t" slug($2 "-" $3 "-" $4); next }
  $1 == "command"    { d = ($4 == "core") ? "" : "opx_infinity/" $4 "/"
                       print "need\tcommand " $2 "\t" d "\t" slug($2); next }
  $1 == "alias"      { print "alias\t" $2 "\t" $3; next }
  $1 == "export"     { print "need\texport " $2 " " $3 "\tcreators/\t" slug("export-" $2 "-" $3); next }
  $1 == "net"        { print "need\tnet event " $3 "\t\t" slug($3); next }
  $1 == "event"      { if ($3 ~ /^opx:(net|on):/) print "need\tevent " $3 "\topx_infinity/\t" slug($3); next }
  $1 == "channel"    { print "need\tpage channel " $2 "\t\tpage-" slug($2); next }
  $1 == "config"     { print "need\tconfig " $2 "." $3 "\topx_infinity/" $2 "/\t" slug("config-" $2 "-" $3); next }
  $1 == "coreconfig" { print "need\tconfig " toupper($2) "." $3 "\topx_infinity/core/\t" slug("config-" $2 "-" $3); next }
  $1 == "core"       { print "need\t" $2 "\t\t" slug($2); next }
  $1 == "lib"        { print "need\topx_lib Lib." $2 "." $3 "\topx_lib/\t" slug("lib-" $2 "-" $3); next }
' "$work/surface.txt" | sort -u > "$work/requirements.tsv"

# 5. Check.
failures=0
total=0

while IFS=$'\t' read -r kind a b c; do
  case "$kind" in
    module)
      total=$((total + 1))
      if [ ! -f "$CONTENT/opx_infinity/$a/index.mdx" ]; then
        echo "FAIL module $a has no page at content/docs/opx_infinity/$a/index.mdx" >&2
        failures=$((failures + 1))
      fi
      case "$b" in
        started|absent|disabled) ;;
        *) echo "FAIL module $a is '$b' under the stub host — the dump is incomplete" >&2
           failures=$((failures + 1)) ;;
      esac
      ;;
    alias)
      total=$((total + 1))
      if ! grep -qxF "$a" "$work/core-words.txt"; then
        echo "FAIL alias \`$a\` (for $b) is not named under content/docs/opx_infinity/core/" >&2
        failures=$((failures + 1))
      fi
      ;;
  esac
done < "$work/requirements.tsv"

awk -F'\t' '
  NR == FNR { have[$2] = have[$2] "\n" $1; next }
  $1 != "need" { next }
  {
    total++
    found = 0
    if ($4 in have) {
      if ($3 == "") found = 1
      else {
        n = split(substr(have[$4], 2), files, "\n")
        for (i = 1; i <= n; i++) if (index(files[i], $3) == 1) { found = 1; break }
      }
    }
    if (!found) print "  " $2 "  ->  " $4 (($3 == "") ? "" : "  in " $3) > "/dev/stderr"
    else ok++
  }
  END { print total " " (total - ok) }
' "$work/anchors.tsv" "$work/requirements.tsv" > "$work/count.txt" 2> "$work/missing.txt"

read -r needs missed < "$work/count.txt"
total=$((total + needs))
if [ "$missed" -gt 0 ]; then
  echo "FAIL $missed published name(s) not documented:" >&2
  cat "$work/missing.txt" >&2
  failures=$((failures + missed))
fi

echo "check-api-coverage: $total published name(s) checked."
if [ "$failures" -gt 0 ]; then
  echo "check-api-coverage: $failures failure(s)." >&2
  exit 1
fi
echo "check-api-coverage: complete — every published name is documented."
