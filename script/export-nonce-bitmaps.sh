#!/usr/bin/env bash
set -euo pipefail

# Export non-zero nonce bitmap words from an existing Permit2 deployment.
# Usage:
#   RPC_URL=https://... ./script/export-nonce-bitmaps.sh <permit-address> <owner> <start-word> <end-word>
#
# Mainnet Permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3

PERMIT="${1:?permit contract address}"
OWNER="${2:?owner address}"
START="${3:-0}"
END="${4:-$START}"

if [[ -z "${RPC_URL:-}" ]]; then
  echo "RPC_URL is required" >&2
  exit 1
fi

positions="["
for ((word = START; word <= END; word++)); do
  if [[ $word -ne $START ]]; then
    positions+=","
  fi
  positions+="$word"
done
positions+="]"

forge script script/ExportNonceBitmaps.s.sol \
  --sig "run(address,address,uint256[])" "$PERMIT" "$OWNER" "$positions" \
  --rpc-url "$RPC_URL"
