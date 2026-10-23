#!/usr/bin/env bash
set -euo pipefail

export PATH="${HOME:-/root}/.foundry/bin:${PATH}"

if ! command -v forge >/dev/null 2>&1; then
  echo "error: forge not found in PATH (checked ~/.foundry/bin)" >&2
  echo "Install Foundry: https://book.getfoundry.sh/getting-started/installation" >&2
  exit 1
fi

exec forge "$@"
