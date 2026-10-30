#!/bin/sh
set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
has_dotnet_8() {
  command -v dotnet >/dev/null 2>&1 &&
    dotnet --list-runtimes 2>/dev/null | grep -q '^Microsoft\.NETCore\.App 8\.'
}
printf '%s\n\n' 'Dungeon Scores Companion - one-time installation'
if ! has_dotnet_8; then
  printf '%s\n' 'The free .NET 8 runtime must be installed first.'
  printf '%s\n' 'The official Microsoft download page will open now.'
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open 'https://dotnet.microsoft.com/download/dotnet/8.0/runtime' >/dev/null 2>&1 || true
  fi
  printf '%s\n' 'https://dotnet.microsoft.com/download/dotnet/8.0/runtime'
  printf '\n%s' 'Install the .NET 8 runtime, then return here and press Return. '
  read -r ignored
  if ! has_dotnet_8; then
    printf '\n%s\n' '.NET 8 is not available yet. Finish installing it, then run this file again.'
    exit 1
  fi
fi
printf '%s\n' 'Installing and starting automatic Dungeon Scores synchronization...'
if ! dotnet "$here/DungeonScoresCompanion.dll" --install-startup; then
  printf '\n%s\n' 'Installation did not complete. See the message above.'
  exit 1
fi
printf '\n%s\n' 'Installation complete. You do not need to run this file again.'
printf '%s\n' 'From now on, press Send selected score in ESO. That is the normal workflow.'
printf '%s\n' 'The score sends after ESO next saves. Use /reloadui only for an immediate send.'
printf '\n%s\n' 'Opening the companion controls in your browser...'
exec sh "$here/Open-Controls-Linux.sh"
