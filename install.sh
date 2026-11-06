#!/usr/bin/env sh
set -eu

# This installer is intentionally user-scoped. It never invokes sudo or
# attempts to elevate privileges.

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
target_root=${SKILLS_HOME:-"$HOME/.agents/skills"}

if [ "${1:-}" = "--codex" ]; then
  target_root=${CODEX_HOME:-"$HOME/.codex"}/skills
  shift
elif [ "${1:-}" = "--target" ]; then
  if [ "$#" -lt 2 ]; then
    echo "Usage: ./install.sh [--codex | --target PATH]" >&2
    exit 2
  fi
  target_root=$2
  shift 2
elif [ "$#" -gt 0 ]; then
  echo "Usage: ./install.sh [--codex | --target PATH]" >&2
  exit 2
fi

if ! mkdir -p "$target_root"; then
  echo "Cannot create $target_root with the current user account." >&2
  echo "Choose a user-owned path with --target or SKILLS_HOME; do not use sudo." >&2
  exit 1
fi

if [ ! -w "$target_root" ]; then
  echo "$target_root is not writable by the current user." >&2
  echo "Choose a user-owned path with --target or SKILLS_HOME; do not use sudo." >&2
  exit 1
fi

installed=0
for skill_file in "$script_dir"/*/SKILL.md; do
  [ -f "$skill_file" ] || continue
  skill_dir=$(dirname -- "$skill_file")
  skill_name=$(basename -- "$skill_dir")
  destination="$target_root/$skill_name"

  if ! mkdir -p "$destination" || ! cp -R "$skill_dir"/* "$destination"/; then
    echo "Could not install $skill_name with the current user account." >&2
    echo "Choose a user-owned path; the installer will not request elevated access." >&2
    exit 1
  fi
  echo "Installed $skill_name -> $destination"
  installed=$((installed + 1))
done

if [ "$installed" -eq 0 ]; then
  echo "No skill directories containing SKILL.md were found in $script_dir" >&2
  exit 1
fi

echo "Installed $installed skill(s) into $target_root without sudo or elevated access."
