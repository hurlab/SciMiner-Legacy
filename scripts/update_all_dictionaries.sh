#!/bin/bash
# ==============================================================================
# update_all_dictionaries.sh
# ==============================================================================
# Purpose:  Master script that runs all SciMiner dictionary update scripts
#           in the correct order. Creates a unified backup before running.
#
# Usage:
#   ./update_all_dictionaries.sh [options]
#
# Options:
#   --dry-run     Pass through to all sub-scripts (no files written)
#   --no-backup   Skip the unified backup step
#   --help        Show this help message
#
# Author: SciMiner Dictionary Update System
# Date:   2026-03-15
# ==============================================================================

set -e

# Parse arguments
DRY_RUN=""
NO_BACKUP=""
HELP=""

for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN="--dry-run"
            ;;
        --no-backup)
            NO_BACKUP="--no-backup"
            ;;
        --help)
            HELP=1
            ;;
    esac
done

if [ -n "$HELP" ]; then
    echo "Usage: $0 [--dry-run] [--no-backup] [--help]"
    echo ""
    echo "Options:"
    echo "  --dry-run     Run all update scripts in dry-run mode (no files written)"
    echo "  --no-backup   Skip the unified backup step"
    echo "  --help        Show this help message"
    echo ""
    echo "This script runs all SciMiner dictionary update scripts in order:"
    echo "  1. update_hgnc_dictionary.pl  (gene symbols, names, and derived files)"
    echo "  2. update_generif.pl          (NCBI GeneRIF data)"
    echo "  3. update_pathways.pl         (KEGG and Reactome pathways)"
    exit 0
fi

# Determine script directory (absolute path)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DICT_DIR="$SCRIPT_DIR/../annotation/SciMinerDB/Work/Dictionary"

# Verify dictionary directory exists
if [ ! -d "$DICT_DIR" ]; then
    echo "ERROR: Dictionary directory not found: $DICT_DIR"
    exit 1
fi

# Resolve to absolute path
DICT_DIR="$(cd "$DICT_DIR" && pwd)"

echo "============================================================"
echo "  SciMiner Dictionary Update - Master Script"
echo "============================================================"
echo "Date:       $(date '+%Y-%m-%d %H:%M:%S')"
echo "Dict Dir:   $DICT_DIR"
echo "Dry Run:    $([ -n "$DRY_RUN" ] && echo "YES" || echo "NO")"
echo "Backup:     $([ -n "$NO_BACKUP" ] && echo "DISABLED" || echo "ENABLED")"
echo "------------------------------------------------------------"
echo ""

# Step 1: Create unified backup of ALL dictionary files
if [ -z "$NO_BACKUP" ] && [ -z "$DRY_RUN" ]; then
    BACKUP_DIR="$DICT_DIR/backup_$(date +%Y%m%d_%H%M%S)"
    echo "[Backup] Creating unified backup at:"
    echo "  $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"

    # Backup all _default and _lst files
    file_count=0
    for f in "$DICT_DIR"/*_default "$DICT_DIR"/*_lst; do
        if [ -f "$f" ]; then
            cp "$f" "$BACKUP_DIR/"
            file_count=$((file_count + 1))
        fi
    done
    echo "[Backup] Backed up $file_count files."
    echo ""

    # Sub-scripts should skip their own backups since we did a unified one
    NO_BACKUP="--no-backup"
fi

# Track results
HGNC_STATUS="NOT RUN"
GENERIF_STATUS="NOT RUN"
PATHWAY_STATUS="NOT RUN"

# Step 2: Run HGNC dictionary update
echo "============================================================"
echo "[1/3] Running HGNC dictionary update..."
echo "============================================================"
echo ""
if perl "$SCRIPT_DIR/update_hgnc_dictionary.pl" $DRY_RUN $NO_BACKUP --dict-dir "$DICT_DIR"; then
    HGNC_STATUS="SUCCESS"
    echo ""
    echo "[1/3] HGNC update: SUCCESS"
else
    HGNC_STATUS="FAILED (exit code: $?)"
    echo ""
    echo "[1/3] HGNC update: FAILED"
    echo "WARNING: Continuing with remaining updates..."
fi
echo ""

# Step 3: Run GeneRIF update
echo "============================================================"
echo "[2/3] Running GeneRIF update..."
echo "============================================================"
echo ""
if perl "$SCRIPT_DIR/update_generif.pl" $DRY_RUN $NO_BACKUP --dict-dir "$DICT_DIR"; then
    GENERIF_STATUS="SUCCESS"
    echo ""
    echo "[2/3] GeneRIF update: SUCCESS"
else
    GENERIF_STATUS="FAILED (exit code: $?)"
    echo ""
    echo "[2/3] GeneRIF update: FAILED"
    echo "WARNING: Continuing with remaining updates..."
fi
echo ""

# Step 4: Run pathway update
echo "============================================================"
echo "[3/3] Running pathway update..."
echo "============================================================"
echo ""
if perl "$SCRIPT_DIR/update_pathways.pl" $DRY_RUN $NO_BACKUP --dict-dir "$DICT_DIR"; then
    PATHWAY_STATUS="SUCCESS"
    echo ""
    echo "[3/3] Pathway update: SUCCESS"
else
    PATHWAY_STATUS="FAILED (exit code: $?)"
    echo ""
    echo "[3/3] Pathway update: FAILED"
fi
echo ""

# Final Summary
echo "============================================================"
echo "  Dictionary Update Summary"
echo "============================================================"
echo "  HGNC (gene dictionaries):  $HGNC_STATUS"
echo "  GeneRIF:                   $GENERIF_STATUS"
echo "  Pathways (KEGG/Reactome):  $PATHWAY_STATUS"
echo "------------------------------------------------------------"

if [ -n "$DRY_RUN" ]; then
    echo ""
    echo "*** DRY RUN - No files were modified ***"
fi

# Show file sizes
if [ -z "$DRY_RUN" ]; then
    echo ""
    echo "Updated dictionary files:"
    echo "------------------------------------------------------------"
    ls -lh "$DICT_DIR"/*_default "$DICT_DIR"/*_lst 2>/dev/null | awk '{printf "  %-40s %s\n", $NF, $5}' | sed "s|$DICT_DIR/||"
fi

echo "============================================================"
echo "  Update complete: $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"

# Exit with error if any step failed
if echo "$HGNC_STATUS $GENERIF_STATUS $PATHWAY_STATUS" | grep -q "FAILED"; then
    echo ""
    echo "WARNING: One or more updates failed. Check output above for details."
    exit 1
fi

exit 0
