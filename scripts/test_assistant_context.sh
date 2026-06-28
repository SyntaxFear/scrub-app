#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/assistant-context-tests"
mkdir -p "$BUILD_DIR"

swiftc \
  "$ROOT_DIR/Scrub/Models/AssistantContext.swift" \
  "$ROOT_DIR/scripts/AssistantContextSerializationTests.swift" \
  -o "$BUILD_DIR/assistant-context-tests"

"$BUILD_DIR/assistant-context-tests"
