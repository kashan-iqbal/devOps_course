#!/bin/bash

REFRESH_RATE=3
LOG_FILE="system_alerts.log"

draw_bar() {
    local percent=$1
    local bar=""
    local level="OK"

    if (( percent >= 90 )); then
        color="\e[91m"  # Red
        level="CRITICAL"
    elif (( percent >= 75 )); then
        color="\e[93m"  # Yellow
        level="WARNING"
    else
        color="\e[92m"  # Green
        level="OK"
    fi

    bar=$(printf '█%.0s' $(seq 1 $((percent / 2))))
    bar+=$(printf '░%.0s' $(seq 1 $((50 - percent / 2))))
    echo -e "$color$percent%% $bar [$level]\e[0m"
    echo "$level"
}

monitor() {
    clear
    echo -e "╔════════════ SYSTEM HEALTH MONITOR v1.0 ════════════╗  [R]efresh rate: ${REFRESH_RATE}s"
    echo -e "║ Hostname: $(hostname)          Date: $(date +%F) ║  [Q]uit"
    echo -e "║ Uptime: $(uptime -p | cut -d ' ' -f2-) ║"
    echo -e "╚═══════════════════════════════════════════════════════════════════════╝"

    # CPU Usage
    CPU_IDLE=$(top -bn1 | grep "Cpu" | awk '{print $8}')
    CPU_USAGE=$(printf "%.0f" "$(echo "100 - $CPU_IDLE" | bc)")
    echo -n "CPU USAGE: "
    CPU_LEVEL=$(draw_bar "$CPU_USAGE")

    # Memory Usage
    MEM=$(free -m | awk '/Mem:/ {printf "%.0f %.0f", $3/$2*100, $2}')
    MEM_PERCENT=$(echo $MEM | cut -d' ' -f1)
    MEM_TOTAL=$(echo $MEM | cut -d' ' -f2)
    echo -n "MEMORY: "
    draw_bar "$MEM_PERCENT"
    echo "  Free: $(free -m | awk '/Mem:/ {print $4}')MB | Cache: $(free -m | awk '/Mem:/ {print $6}')MB"

    # Disk Usage
    echo -e "\nDISK USAGE:"
    df -h --output=target,pcent | grep -v 'Mounted' | while read -r mount usage; do
        percent=$(echo "$usage" | tr -d '%')
        echo -n "  $mount : "
        draw_bar "$percent" > /dev/null
    done

    # Network
    RX=$(cat /sys/class/net/eth0/statistics/rx_bytes)
    TX=$(cat /sys/class/net/eth0/statistics/tx_bytes)
    sleep 1
    RX_NEW=$(cat /sys/class/net/eth0/statistics/rx_bytes)
    TX_NEW=$(cat /sys/class/net/eth0/statistics/tx_bytes)
    RX_RATE=$(( (RX_NEW - RX) / 1024 / 1024 ))
    TX_RATE=$(( (TX_NEW - TX) / 1024 / 1024 ))
    echo -e "\nNETWORK:"
    echo "  eth0 (in) : $RX_RATE MB/s"
    echo "  eth0 (out): $TX_RATE MB/s"

    # Load Average
    LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | sed 's/^ //')
    echo -e "\nLOAD AVERAGE: $LOAD"

    # Log anomalies
    if (( CPU_USAGE > 80 )); then
        echo "[$(date +%T)] CPU usage exceeded 80% ($CPU_USAGE%)" >> "$LOG_FILE"
    fi
    if (( MEM_PERCENT > 75 )); then
        echo "[$(date +%T)] Memory usage exceeded 75% ($MEM_PERCENT%)" >> "$LOG_FILE"
    fi
    if (( $(df / | awk 'NR==2 {print $5}' | tr -d '%') > 75 )); then
        echo "[$(date +%T)] Disk usage on / exceeded 75%" >> "$LOG_FILE"
    fi

    echo -e "\nRECENT ALERTS:"
    tail -n 5 "$LOG_FILE"
}

# Main loop
while true; do
    monitor
    echo -e "\nPress 'h' for help, 'q' to quit."
    read -t $REFRESH_RATE -n 1 key
    case $key in
        q|Q) break ;;
        r|R) read -p "Enter new refresh rate: " REFRESH_RATE ;;
    esac
done
