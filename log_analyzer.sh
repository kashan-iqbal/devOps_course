#!/bin/bash

# Check for argument
if [ -z "$1" ]; then
    echo "Usage: $0 /path/to/logfile"
    exit 1
fi

LOG_FILE="$1"
if [ ! -f "$LOG_FILE" ]; then
    echo "File not found: $LOG_FILE"
    exit 1
fi

# Get basic info
FILE_SIZE_BYTES=$(stat -c%s "$LOG_FILE")
FILE_SIZE_MB=$(echo "scale=1; $FILE_SIZE_BYTES / 1048576" | bc)
NOW=$(date +"%a %b %d %T %Z %Y")
REPORT_FILE="log_analysis_$(date +%Y%m%d_%H%M%S).txt"

# Count messages
COUNT_ERROR=$(grep -c "ERROR" "$LOG_FILE")
COUNT_WARNING=$(grep -c "WARNING" "$LOG_FILE")
COUNT_INFO=$(grep -c "INFO" "$LOG_FILE")

# Top 5 error messages
TOP_ERRORS=$(grep "ERROR" "$LOG_FILE" | cut -d']' -f2- | sed 's/^ *//' | sort | uniq -c | sort -nr | head -5)

# First and last error
FIRST_ERROR=$(grep "ERROR" "$LOG_FILE" | head -1)
LAST_ERROR=$(grep "ERROR" "$LOG_FILE" | tail -1)

# Error frequency by hour
declare -A HOUR_BUCKETS
for hour in {00..04} {04..08} {08..12} {12..16} {16..20} {20..24}; do
    HOUR_BUCKETS["$hour"]=0
done

grep "ERROR" "$LOG_FILE" | while read -r line; do
    timestamp=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}')
    if [[ $timestamp ]]; then
        hour=${timestamp:11:2}
        case $hour in
            00|01|02|03) ((HOUR_BUCKETS["00-04"]++)) ;;
            04|05|06|07) ((HOUR_BUCKETS["04-08"]++)) ;;
            08|09|10|11) ((HOUR_BUCKETS["08-12"]++)) ;;
            12|13|14|15) ((HOUR_BUCKETS["12-16"]++)) ;;
            16|17|18|19) ((HOUR_BUCKETS["16-20"]++)) ;;
            20|21|22|23) ((HOUR_BUCKETS["20-24"]++)) ;;
        esac
    fi
done

# Generate report
{
echo "===== LOG FILE ANALYSIS REPORT ====="
echo "File: $LOG_FILE"
echo "Analyzed on: $NOW"
echo "Size: ${FILE_SIZE_MB}MB ($FILE_SIZE_BYTES bytes)"
echo
echo "MESSAGE COUNTS:"
echo "ERROR: $COUNT_ERROR messages"
echo "WARNING: $COUNT_WARNING messages"
echo "INFO: $COUNT_INFO messages"
echo
echo "TOP 5 ERROR MESSAGES:"
echo "$TOP_ERRORS"
echo
echo "ERROR TIMELINE:"
echo "First error: [$FIRST_ERROR]"
echo "Last error:  [$LAST_ERROR]"
echo
echo "Error frequency by hour:"
for bucket in "00-04" "04-08" "08-12" "12-16" "16-20" "20-24"; do
    count=${HOUR_BUCKETS[$bucket]}
    bars=$(printf '█%.0s' $(seq 1 $((count / 4 + 1))))
    printf "%s: %-40s (%d)\n" "$bucket" "$bars" "$count"
done
echo
echo "Report saved to: $REPORT_FILE"
} | tee "$REPORT_FILE"
