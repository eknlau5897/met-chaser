#!/bin/bash

# Configuration
STORM_ID="2026wp18"
DIR_URL="https://rammb-data.cira.colostate.edu/tc_realtime/products/storms/${STORM_ID}/ripastbl/"
INTERVAL=21600 # Check every 6 hours

TARGET_DATA_FILE="RIPS.txt"
TARGET_NAME_FILE="data/latest_filename.txt"

mkdir -p data

# Function to calculate date string for 6 hours ago (handles both macOS and Linux)
get_prior_date_parts() {
    if date -v-6H >/dev/null 2>&1; then
        # macOS / BSD Date Syntax
        PREV_DATE=$(date -u -v-6H +"%Y%m%d")
        PREV_HR=$(date -u -v-6H +"%H")
    else
        # Linux / GNU Date Syntax
        PREV_DATE=$(date -u -d "6 hours ago" +"%Y%m%d")
        PREV_HR=$(date -u -d "6 hours ago" +"%H")
    fi
}

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
        
        get_prior_date_parts
        
        # Clean leading zeros safely for arithmetic calculations
        HR_NUM=$((10#$PREV_HR))
        SYNOP_NUM=$(( (HR_NUM / 6) * 6 ))
        SYNOP_HOUR=$(printf "%02d" $SYNOP_NUM)
        
        DATE_STAMP="${PREV_DATE}${SYNOP_HOUR}00"
        LATEST_FILE="${STORM_ID}_ripastbl_${DATE_STAMP}.txt"
    fi

    FULL_URL="${DIR_URL}${LATEST_FILE}"
    echo "[$(date -u)] Target prior product URL: ${FULL_URL}"

    # 4. Attempt to fetch product file
    HTTP_STATUS=$(curl -sL -A "Mozilla/5.0" -w "%{http_code}" "$FULL_URL" -o "data/temp_ripa.txt")

        # Overwrite destination file
    mv "data/temp_ripa.txt" "$TARGET_DATA_FILE"
    echo "$LATEST_FILE" > "$TARGET_NAME_FILE"

        # 5. Git commit & push if updated
    git add RIPS.txt
    git commit -m "Auto-update: Fetched ${LATEST_FILE} for ${STORM_ID} (6-hour prior)"
    git push origin main
    echo "[$(date -u)] Successfully fetched and updated ${LATEST_FILE}."

    echo "Sleeping for $((INTERVAL / 60)) minutes..."
    echo "--------------------------------------------------------"
    sleep $INTERVAL
done