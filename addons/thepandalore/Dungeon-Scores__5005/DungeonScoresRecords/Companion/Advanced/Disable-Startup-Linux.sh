#!/bin/sh
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if ! command -v dotnet >/dev/null 2>&1; then
  printf '%s\n' 'Dungeon Scores Companion requires the free .NET 8 runtime.'
  printf '%s\n' 'https://dotnet.microsoft.com/download/dotnet/8.0/runtime'
  exit 1
fi
dotnet "$here/../DungeonScoresCompanion.dll" --uninstall-startup
