#!/bin/sh
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if ! command -v dotnet >/dev/null 2>&1; then
  printf '%s\n' 'The free .NET 8 runtime is required: https://dotnet.microsoft.com/download/dotnet/8.0/runtime'
  printf '%s' 'Press Return to close. '; read -r ignored
  exit 1
fi
installed=$(dotnet "$here/DungeonScoresCompanion.dll" --prepare-control) || exit 1
exec dotnet "$installed" --control --config "$(dirname -- "$installed")/watcher-config.json"
