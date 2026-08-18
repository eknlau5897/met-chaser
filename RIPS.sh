#!/bin/bash

# Configuration
STORM_ID="2026wp95"
BASE_URL="https://rammb-data.cira.colostate.edu/tc_realtime/products/storms/${STORM_ID}/ripastbl/"
INTERVAL=21600 # Check every 30 minutes (1800 seconds)

# Target fixed paths (Overwritten on new updates)
TARGET_DATA_FILE="RIPS.txt"
TARGET_NAME_FILE="data/latest_filename.txt"

mkdir -p data

echo "Starting RAMMB RIPA auto-update daemon for Storm ${STORM_ID}..."

while true; do
    echo "[$(date -u)] Checking RAMMB server for latest run..."

    # 1. Fetch directory index
    DIR_HTML=$(curl -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "$BASE_URL")

    # 2. Extract the newest filename from directory listing
    LATEST_FILE=$(echo "$DIR_HTML" | grep -oE "${STORM_ID}_ripastbl_[0-9]+\.txt" | sort | tail -n 1)

    if [ -n "$LATEST_FILE" ]; then
        # 3. Overwrite latest_ripa.txt and latest_filename.txt directly
        curl -s -A "Mozilla/5.0" "${BASE_URL}${LATEST_FILE}" -o "$TARGET_DATA_FILE"
        echo "$LATEST_FILE" > "$TARGET_NAME_FILE"

        # 4. Commit & push ONLY if the content of latest_ripa.txt actually changed
        git add data/
        if ! git diff --staged --quiet; then
            echo "[$(date -u)] New run detected (${LATEST_FILE})! Overwriting and pushing..."
            git commit -m "Update live RIPA product: ${LATEST_FILE}"
            git push origin main
        else
            echo "[$(date -u)] Latest run (${LATEST_FILE}) already synced. No changes."
        fi
    else
        echo "[$(date -u)] Warning: Could not parse file list from RAMMB server."
    fi

    echo "Sleeping for $((INTERVAL / 60)) minutes..."
    echo "--------------------------------------------------------"
    sleep $INTERVAL
done