#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/bin"
TARGET_PATH="${TARGET_DIR}/airdrop"

cd "${SCRIPT_DIR}"

swift build -c release

mkdir -p "${TARGET_DIR}"
install ".build/release/airdrop" "${TARGET_PATH}"

printf 'Installed airdrop to %s\n' "${TARGET_PATH}"
