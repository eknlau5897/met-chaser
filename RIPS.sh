#!/bin/bash

# Configuration
STORM_ID="2026wp95"
BASE_URL="https://rammb-data.cira.colostate.edu/tc_realtime/products/storms/${STORM_ID}/ripastbl/"
INTERVAL=21600 # Check every 30 minutes

TARGET_DATA_FILE="RIPS.txt"
TARGET_NAME_FILE="data/latest_filename.txt"

mkdir -p data

echo "Starting RAMMB RIPA auto-update daemon for Storm ${STORM_ID}..."

while true; do
    echo "[$(date -u)] Checking RAMMB server at: ${BASE_URL}"

    # 1. Fetch directory HTML silently with location redirect following (-L)
    DIR_HTML=$(curl -sL -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "$BASE_URL")

    # 2. Match any .txt file in href tags (flexible pattern)
    LATEST_FILE=$(echo "$DIR_HTML" | grep -oE 'href=["'\''][^"'\'']+\.txt' | sed -E 's/href=["'\'']//g' | sort | tail -n 1)

    if [ -n "$LATEST_FILE" ]; then
        echo "[$(date -u)] Found latest file: ${LATEST_FILE}"

        # Build full download URL if LATEST_FILE is relative
        if [[ "$LATEST_FILE" =~ ^http ]]; then
            DOWNLOAD_URL="$LATEST_FILE"
            FILE_NAME=$(basename "$LATEST_FILE")
        else
            DOWNLOAD_URL="${BASE_URL}${LATEST_FILE}"
            FILE_NAME="$LATEST_FILE"
        fi

        # 3. Download product file and record name
        curl -sL -A "Mozilla/5.0" "$DOWNLOAD_URL" -o "$TARGET_DATA_FILE"
        echo "$FILE_NAME" > "$TARGET_NAME_FILE"

        # 4. Commit and push if content changed
        git add data/
        if ! git diff --staged --quiet; then
            echo "[$(date -u)] New product run detected (${FILE_NAME})! Pushing to GitHub..."
            git commit -m "Update live RIPA product: ${FILE_NAME}"
            git push origin main
        else
            echo "[$(date -u)] No new changes. Latest synced run: ${FILE_NAME}"
        fi
    else
        echo "[$(date -u)] Warning: Could not parse file list from RAMMB server."
        echo "[$(date -u)] Debug: Testing direct URL fetch for HTML output length: ${#DIR_HTML} characters."
    fi

    echo "Sleeping for $((INTERVAL / 60)) minutes..."
    echo "--------------------------------------------------------"
    sleep $INTERVAL
done