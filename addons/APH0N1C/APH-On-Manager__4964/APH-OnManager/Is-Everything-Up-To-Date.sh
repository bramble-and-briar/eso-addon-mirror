#!/bin/bash
# Copyright © 2026 @APHONlC. All rights reserved.
#
# No copying, modification, distribution, or sale without prior written permission.
# AI/ML ingestion and training are strictly prohibited (TDM opt-out).
#
# See LICENSE.md for full terms and maintenance exceptions.

_d() {
	local h="$1" s="$2" o="" i b
	for (( i = 0; i < ${#h}; i += 2 )); do
		s=$(( (s * 73 + 41) % 256 ))
		b=$(( 16#${h:i:2} ^ s ))
		o="${o}$(printf "\\$(printf '%03o' "$b")")"
	done
	printf '%s' "$o"
}

REPO="$(_d 7571da8442f9e55021d9729e7b930306e69085fe2e 151)"
API_BASE="${AOM_API_BASE:-$(_d d0d5663bff2f09d08179d31dd314ba8f7d134c78b388 23)}"
RAW_ROOT="${AOM_RAW_ROOT:-$(_d abb079ae04222e5dd98d02a838291d72e676a85d221ab2ad154820b85bbe5a050e 202)}"
REPO_RAW_BASE="${RAW_ROOT}/${REPO}/main/DATA"
WORKFLOW_DIR="$(_d 6fd58258ddb3fdafde35a13f7b02e8df622d 88)"
UPDATE_WORKFLOWS="${WORKFLOW_DIR}data-tables-refresh.yml ${WORKFLOW_DIR}console-data-refresh.yml"
ACCEPT="Accept: $(_d e72f300573f075a9472806feb415586bb146e4511f014fc70d78d6 117)"
WAIT_SECONDS="${AOM_WAIT_SECONDS:-30}"
MAX_WAITS=20
TABLES=(
	"KnownLibraries.lua"
	"KnownAddonVersions.lua"
	"KnownAddonDependencies.lua"
	"SuggestedCategories.lua"
	"KnownConsoleAddons.lua"
	"KnownConsoleLibraries.lua"
	"KnownConsoleAddonDependencies.lua"
	"ConsoleSuggestedCategories.lua"
)

if [[ -t 0 ]]; then
	trap 'echo ""; read -r -p "Press Enter to close this window..."' EXIT
fi

echo "> Is Everything Up to Date?"
echo ""

cd "$(dirname "$0")" || exit 1

if [[ ! -f "merge-known-tables.awk" ]]; then
	echo "ERROR: merge-known-tables.awk not found next to this script."
	exit 1
fi

for file_name in "${TABLES[@]}"; do
	if [[ ! -f "DATA/${file_name}" ]]; then
		echo "ERROR: DATA/${file_name} not found. Run this script from inside your APH-OnManager addon folder."
		exit 1
	fi
done

repo_update_state() {
	local runs pending_path="" line value
	runs=$(curl -fsS -H "$ACCEPT" "${API_BASE}/repos/${REPO}/actions/runs?per_page=30" 2>/dev/null) || { echo "unknown"; return; }
	while IFS= read -r line; do
		value="${line#*: }"
		value="${value#\"}"
		value="${value%\"}"
		case "$line" in
			\"path\"*) pending_path="$value" ;;
			\"status\"*)
				if [[ -n "$pending_path" && " ${UPDATE_WORKFLOWS} " == *" ${pending_path} "* && "$value" != "completed" ]]; then
					echo "updating"
					return
				fi
				pending_path=""
				;;
		esac
	done < <(printf '%s' "$runs" | grep -oE '"path": *"[^"]*"|"status": *"[^"]*"')
	echo "idle"
}

state=$(repo_update_state)
if [[ "$state" == "updating" ]]; then
	echo "The data tables are being updated right now."
	echo "Waiting for that to finish before downloading anything..."
	waits=0
	while [[ "$state" == "updating" ]]; do
		if (( waits >= MAX_WAITS )); then
			echo "  Still being updated after $(( MAX_WAITS * WAIT_SECONDS / 60 )) minutes. Nothing was changed; run this again a little later."
			exit 1
		fi
		waits=$(( waits + 1 ))
		echo "  Checking again in ${WAIT_SECONDS} seconds (${waits}/${MAX_WAITS})..."
		sleep "$WAIT_SECONDS"
		state=$(repo_update_state)
	done
	echo "  The update has finished."
	echo ""
elif [[ "$state" == "unknown" ]]; then
	echo "(Could not check whether the tables are being updated right now, so going ahead.)"
	echo ""
fi

download_base="$REPO_RAW_BASE"
commit_json=$(curl -fsS -H "$ACCEPT" "${API_BASE}/repos/${REPO}/commits/main" 2>/dev/null)
commit_sha=$(printf '%s' "$commit_json" | grep -oE '"sha": *"[0-9a-f]{40}"' | head -n 1 | grep -oE '[0-9a-f]{40}')
if [[ -n "$commit_sha" ]]; then
	download_base="${RAW_ROOT}/${REPO}/${commit_sha}/DATA"
fi

tmp_dir=$(mktemp -d)
cleanup() { rm -rf "$tmp_dir"; }
trap 'cleanup' INT TERM

for file_name in "${TABLES[@]}"; do
	if ! curl -fsSL "${download_base}/${file_name}" -o "${tmp_dir}/${file_name}"; then
		echo "  ERROR: could not download ${file_name}."
		echo "  Check your internet connection, or the data tables might be being updated right now."
		echo "  Nothing was changed."
		cleanup
		exit 1
	fi
done

sync_table() {
	local file_name="$1"
	local local_file="DATA/${file_name}"
	local tmp_remote="${tmp_dir}/${file_name}"
	local tmp_merged="${tmp_dir}/${file_name}.merged"
	local tmp_stats="${tmp_dir}/${file_name}.stats"

	echo "Checking ${file_name} ..."
	ADDED=0
	UPDATED=0
	LC_ALL=C awk -f merge-known-tables.awk "$local_file" "$tmp_remote" > "$tmp_merged" 2> "$tmp_stats"
	source "$tmp_stats"

	if cmp -s "$local_file" "$tmp_merged"; then
		echo "  Already up to date."
	else
		mv "$tmp_merged" "$local_file"
		echo "  Updated: ${UPDATED:-0} entr$([[ "${UPDATED:-0}" == "1" ]] && echo y || echo ies) changed, ${ADDED:-0} new entr$([[ "${ADDED:-0}" == "1" ]] && echo y || echo ies) added."
		while IFS= read -r detail_line; do
			echo "    ${detail_line#\# }"
		done < <(grep '^# ' "$tmp_stats")
	fi
}

for file_name in "${TABLES[@]}"; do
	sync_table "$file_name"
done
cleanup

echo ""
echo "Reload your UI (/reloadui) for any change to take effect."
