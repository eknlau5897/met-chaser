#!/bin/bash

# Configuration
STORM_ID="2026wp18"
DIR_URL="https://rammb-data.cira.colostate.edu/tc_realtime/products/storms/${STORM_ID}/ripastbl/"
INTERVAL=21600 # Check every 30 minutes (1800s)

TARGET_DATA_FILE="RIPS.txt"
TARGET_NAME_FILE="data/latest_filename.txt"

mkdir -p data

echo "Starting RAMMB RIPA auto-update daemon for ${STORM_ID}..."

while true; do
    echo "[$(date -u)] Checking RAMMB directory: ${DIR_URL}"

    # 1. Fetch directory listing
    DIR_HTML=$(curl -sL -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "$DIR_URL")

    # 2. Match exact filename pattern (e.g. 2026wp95_ripastbl_202608181800.txt)
    LATEST_FILE=$(echo "$DIR_HTML" | grep -oE "${STORM_ID}_ripastbl_[0-9]{12}\.txt" | sort | tail -n 1)

    # 3. Fallback: If directory listing is blocked, calculate current 6-hour cycle timestamp in UTC
    if [ -z "$LATEST_FILE" ]; then
        echo "[$(date -u)] Directory index restricted. Calculating expected 6-hourly cycle URL..."
        # Calculate latest synoptic hour (00, 06, 12, 18 UTC)
        CURRENT_HOUR=$(($CURRENT_HOUR - 6))
        SYNOP_HOUR=$(printf "%02d" $(( ($CURRENT_HOUR / 6) * 6 )))
        DATE_STAMP=$(date -u +"%Y%m%d")${SYNOP_HOUR}00
        LATEST_FILE="${STORM_ID}_ripastbl_${DATE_STAMP}.txt"
    fi

    FULL_URL="${DIR_URL}${LATEST_FILE}"
    echo "[$(date -u)] Target product URL: ${FULL_URL}"

    # 4. Attempt to fetch product file
    HTTP_STATUS=$(curl -sL -A "Mozilla/5.0" -w "%{http_code}" "$FULL_URL" -o "data/temp_ripa.txt")

    if [ "$HTTP_STATUS" -eq 200 ] && [ -s "data/temp_ripa.txt" ]; then
        # Overwrite destination file
        mv "data/temp_ripa.txt" "$TARGET_DATA_FILE"
        echo "$LATEST_FILE" > "$TARGET_NAME_FILE"

        # 5. Git commit & push if updated
        git add RIPS.txt
        if ! git diff --staged --quiet; then
            echo "[$(date -u)] New product synced (${LATEST_FILE}). Pushing to GitHub..."
            git commit -m "Update live RIPA product: ${LATEST_FILE}"
            git push origin main
        else
            echo "[$(date -u)] No changes detected in latest product."
        fi
    else
        rm -f "data/temp_ripa.txt"
        echo "[$(date -u)] Failed to fetch ${LATEST_FILE} (HTTP ${HTTP_STATUS}). Retrying next cycle..."
    fi

    echo "Sleeping for $((INTERVAL / 60)) minutes..."
    echo "--------------------------------------------------------"
    sleep $INTERVAL
done