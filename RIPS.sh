#!/bin/bash

# Configuration
STORM_ID="2026wp18"
DIR_URL="https://rammb-data.cira.colostate.edu/tc_realtime/products/storms/${STORM_ID}/ripastbl/"
INTERVAL=21600 # Check every 6 hours (1800s or adjust to your preference)

TARGET_DATA_FILE="RIPS.txt"
TARGET_NAME_FILE="data/latest_filename.txt"

mkdir -p data

echo "Starting RAMMB RIPA auto-update daemon for ${STORM_ID} (6-hour prior mode)..."

while true; do
    echo "[$(date -u)] Checking RAMMB directory: ${DIR_URL}"

    # 1. Fetch directory listing
    DIR_HTML=$(curl -sL -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "$DIR_URL")

    # 2. Match all filenames and pick the SECOND TO LAST (6 hours prior to latest)
    LATEST_FILE=$(echo "$DIR_HTML" | grep -oE "${STORM_ID}_ripastbl_[0-9]{12}\.txt" | sort | tail -n 2 | head -n 1)

    # 3. Fallback: If directory listing fails, calculate the previous 6-hour cycle timestamp manually
    if [ -z "$LATEST_FILE" ]; then
        echo "[$(date -u)] Directory index restricted. Calculating expected 6-hourly prior cycle URL..."
        # Subtract 6 hours from current UTC time to get the prior cycle slot
        PREV_EPOCH=$(date -u -d "6 hours ago" +%s)
        PREV_DATE=$(date -u -d "@$PREV_EPOCH" +"%Y%m%d")
        PREV_HR=$(date -u -d "@$PREV_EPOCH" +"%H")
        SYNOP_HOUR=$(printf "%02d" $(( (10#$PREV_HR / 6) * 6 )))
        DATE_STAMP="${PREV_DATE}${SYNOP_HOUR}00"
        LATEST_FILE="${STORM_ID}_ripastbl_${DATE_STAMP}.txt"
    fi

    FULL_URL="${DIR_URL}${LATEST_FILE}"
    echo "[$(date -u)] Target prior product URL: ${FULL_URL}"

    # 4. Attempt to fetch product file
    HTTP_STATUS=$(curl -sL -A "Mozilla/5.0" -w "%{http_code}" "$FULL_URL" -o "data/temp_ripa.txt")

    if [ "$HTTP_STATUS" -eq 200 ] && [ -s "data/temp_ripa.txt" ]; then
        # Overwrite destination file
        mv "data/temp_ripa.txt" "$TARGET_DATA_FILE"
        echo "$LATEST_FILE" > "$TARGET_NAME_FILE"

        # 5. Git commit & push if updated
        git add RIPS.txt
        if ! git diff --staged --quiet; then
            echo "[$(date -u)] New prior product synced (${LATEST_FILE}). Pushing to GitHub..."
            git commit -m "Update prior RIPA product: ${LATEST_FILE}"
            git push origin main
        else
            echo "[$(date -u)] No changes detected in prior product."
        fi
    else
        rm -f "data/temp_ripa.txt"
        echo "[$(date -u)] Failed to fetch ${LATEST_FILE} (HTTP ${HTTP_STATUS}). Retrying next cycle..."
    fi

    echo "Sleeping for $((INTERVAL / 60)) minutes..."
    echo "--------------------------------------------------------"
    sleep $INTERVAL
done