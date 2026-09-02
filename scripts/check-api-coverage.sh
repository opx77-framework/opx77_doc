#!/usr/bin/env bash
#
# check-api-coverage.sh — fail if OPX//77 publishes a name the site does not document.
#
# The framework and the documentation live in two different repositories, so this
# script needs to be pointed at a checkout of the framework. It looks, in order, at
#
#   $1                     an explicit path, if one is given
#   $OPX77_RESOURCES       an environment variable
#   ../open77_serv/resources
#   ../../open77_serv/resources
#
# and, if it finds none of them, prints a note and exits 0. That is deliberate:
# the docs repository must stay buildable on its own, and CI for the docs site
# has no framework checkout. Run it locally, next to the framework, before you
# push a reference page:
#
#   ./scripts/check-api-coverage.sh
#   OPX77_RESOURCES=/path/to/open77_serv/resources ./scripts/check-api-coverage.sh
#
# What counts as "published":
#
#   * every exports("name", …) in <resource>/client/exports.lua        — client exports
#   * every ^function OPX.Name in opx77_core/{server,shared,client}/   — the in-core server API
#   * every RegisterCommand("name", …) anywhere in a resource          — chat commands
#   * every event-name constant in opx77_core/shared/main.lua          — the four OPX.Events
#                                                                        tables that OPX//77
#                                                                        owns
#
# The OPX.Events.Platform table is excluded on purpose: those names belong to
# OPEN//77, not to OPX//77, and are listed in the core only so there is one place
# to update if the platform moves them.
#
# What counts as "documented": an explicit `{#anchor}` on a heading somewhere
# under docs/reference/<resource>/. The reference grammar requires one on every
# entry heading (see the entry grammar in the docs plan), so the anchor set is
# the published surface. A name and an anchor match when the anchor's slug ENDS
# WITH the name's slug, both reduced the same way: lower case, everything after
# the last `.` or `:`, non-alphanumerics dropped. So `OPX.SetJob` matches
# `{#setjob}`, `opx77:client:setPlayerData` matches `{#setplayerdata}`, and
# `opx77.whois` matches `{#whois}`.
#
# The suffix rule, rather than equality, is there because the reference
# deliberately disambiguates anchors that would otherwise collide on one page:
# `opx77.create` is documented at `{#opx77-create}` next to a dozen other
# commands, and the internal event `opx77:player:jobUpdate` at
# `{#internal-jobupdate}` next to the wire event `opx77:client:onJobUpdate` at
# `{#onjobupdate}`. Requiring a bare `{#create}` would make the anchors worse to
# read and no more stable.
#
# Two known limits, both of which make the check quieter rather than noisier, so
# a pass is weaker than it looks and a failure is always real:
#
#   * A resource that registers a command under a config value rather than a
#     string literal (opx77_hud's /hud, opx77_weather's eight) contributes no
#     command names.
#   * Two names that reduce to the same slug within one resource — the client
#     export `GetPlayerData` and the in-core `OPX.GetPlayerData`, say — are
#     satisfied by a single anchor.
#   * The suffix rule lets a longer anchor stand in for a shorter name inside one
#     resource: `OPX.SetJob`'s `{#setjob}` would satisfy the command `opx77.job`.

set -euo pipefail

DOCS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REFERENCE="$DOCS_ROOT/docs/reference"

RESOURCES="${1:-${OPX77_RESOURCES:-}}"
if [ -z "$RESOURCES" ]; then
  for candidate in \
    "$DOCS_ROOT/../open77_serv/resources" \
    "$DOCS_ROOT/../../open77_serv/resources"; do
    if [ -d "$candidate" ]; then RESOURCES="$candidate"; break; fi
  done
fi

if [ -z "$RESOURCES" ] || [ ! -d "$RESOURCES" ]; then
  echo "check-api-coverage: no framework checkout found — skipping."
  echo "  Pass one as \$1 or set \$OPX77_RESOURCES to open77_serv/resources to run the check."
  exit 0
fi

RESOURCES="$(cd "$RESOURCES" && pwd)"
echo "check-api-coverage: framework at $RESOURCES"

if [ ! -d "$REFERENCE" ]; then
  echo "check-api-coverage: docs/reference does not exist yet — nothing to check against." >&2
  exit 1
fi

# slug NAME -> the comparable form of a published name or of an anchor.
slug() {
  printf '%s' "$1" \
    | sed 's/.*[.:]//' \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cd 'a-z0-9'
}

failures=0
total=0

for resource_dir in "$RESOURCES"/opx77_*; do
  [ -d "$resource_dir" ] || continue
  resource="$(basename "$resource_dir")"
  doc_dir="$REFERENCE/$resource"

  published="$(mktemp)"

  # Client exports.
  if [ -f "$resource_dir/client/exports.lua" ]; then
    grep -hoE 'exports\("[A-Za-z0-9_]+"' "$resource_dir/client/exports.lua" \
      | sed 's/^exports("//; s/"$//' >> "$published" || true
  fi

  # Chat commands. A resource that registers under a config value rather than a
  # literal contributes nothing here; that is a limit of the check, not a pass.
  grep -rhoE 'RegisterCommand\("[A-Za-z0-9_.]+"' "$resource_dir" --include='*.lua' \
    | sed 's/^RegisterCommand("//; s/"$//' >> "$published" || true

  # The core alone publishes an in-VM server API and the event vocabulary.
  if [ "$resource" = "opx77_core" ]; then
    grep -rhoE '^function OPX\.[A-Za-z0-9_]+' \
      "$resource_dir/server" "$resource_dir/shared" "$resource_dir/client" \
      | sed 's/^function //' >> "$published" || true

    # Every OPX//77 event name is `opx77:<side>:<subject>`, so matching the
    # prefix picks up the Client, Server, Local and Internal tables and leaves
    # the Platform table (whose names are the host's) out by construction.
    if [ -f "$resource_dir/shared/main.lua" ]; then
      grep -hoE '"opx77:[A-Za-z0-9_:]+"' "$resource_dir/shared/main.lua" \
        | tr -d '"' >> "$published" || true
    fi
  fi

  sort -u -o "$published" "$published"
  count="$(wc -l < "$published" | tr -d ' ')"
  total=$((total + count))
  [ "$count" -gt 0 ] || { rm -f "$published"; continue; }

  documented="$(mktemp)"
  if [ -d "$doc_dir" ]; then
    grep -rhoE '\{#[A-Za-z0-9_-]+\}' "$doc_dir" --include='*.md' \
      | sed 's/^{#//; s/}$//' >> "$documented" || true
  fi

  missing=""
  while IFS= read -r name; do
    want="$(slug "$name")"
    [ -n "$want" ] || continue
    if ! awk -v want="$want" '
           { s = tolower($0); gsub(/^.*[.:]/, "", s); gsub(/[^a-z0-9]/, "", s)
             if (s == want) { found = 1 }
             else if (length(s) > length(want) \
                      && substr(s, length(s) - length(want) + 1) == want) { found = 1 } }
           END { exit found ? 0 : 1 }' "$documented"; then
      missing="$missing  $name"$'\n'
    fi
  done < "$published"

  if [ -n "$missing" ]; then
    echo "FAIL $resource — published but not documented under docs/reference/$resource/:" >&2
    printf '%s' "$missing" >&2
    failures=$((failures + 1))
  else
    echo "ok   $resource — $count published name(s), all documented"
  fi

  rm -f "$published" "$documented"
done

echo "check-api-coverage: $total published name(s) across the framework."
if [ "$failures" -gt 0 ]; then
  echo "check-api-coverage: $failures resource(s) have undocumented public names." >&2
  exit 1
fi
echo "check-api-coverage: complete."
