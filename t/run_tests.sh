#!/bin/bash
################################################################################
#
#   run_tests.sh - SciMiner Legacy v1.1 Test Runner
#
#   Usage: ./t/run_tests.sh
#          or: cd /home/sciminer/legacy && prove -v t/
#
################################################################################
set -e

cd "$(dirname "$0")/.."

echo "=== SciMiner Legacy v1.1 Test Suite ==="
echo "Date: $(date)"
echo "Perl: $(perl -v | head -2 | tail -1)"
echo ""

prove -v t/

echo ""
echo "=== Done ==="
