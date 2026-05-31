#!/usr/bin/env bash
# Two-process integration tests for bknr-repl replication: the sync scenarios
# that cannot be unit-tested in one image (two live stores share the global CLOS
# class indices, so they must be separate processes).
#
# The scenarios themselves live in integration-test.exp and are driven with
# `expect`, which waits for real output markers ("in sync (bootstrap", "committed
# #", ...) instead of fixed sleeps.  This wrapper just locates and runs that
# script, so `integration-test.sh` remains the entry point.
#
# Uses the `bknr-repl` binary on PATH; override with BKNR_REPL=/path/to/bknr-repl.
# Build first:  ros build bin/bknr-repl.ros && install -m755 bin/bknr-repl ~/.local/bin/
set -uo pipefail

if ! command -v expect >/dev/null 2>&1; then
  echo "integration-test.sh: 'expect' is required to run the integration tests, but was not found." >&2
  echo "Install it (e.g. 'apt install expect') or run the suite directly: expect bin/integration-test.exp" >&2
  exit 127
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec expect "$here/integration-test.exp"
