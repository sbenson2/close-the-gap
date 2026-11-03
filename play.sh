#!/usr/bin/env bash
set -euo pipefail
game_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "${GODOT:-}" ]]; then
  exec "$GODOT" --path "$game_root" "$@"
elif command -v godot >/dev/null 2>&1; then
  exec godot --path "$game_root" "$@"
elif command -v godot4 >/dev/null 2>&1; then
  exec godot4 --path "$game_root" "$@"
elif [[ -x /home/s/.local/share/close-the-gap-tools/Godot_v4.7.2-stable_linux.x86_64 ]]; then
  exec /home/s/.local/share/close-the-gap-tools/Godot_v4.7.2-stable_linux.x86_64 --path "$game_root" "$@"
else
  echo 'Install Godot 4.7.2 or set GODOT to its executable path.' >&2
  exit 1
fi
