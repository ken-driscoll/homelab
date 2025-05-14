#!/bin/bash

# Custom Stepped Fan Control Script for Supermicro X11SSH-F
# Fan setup:
# 0 = FAN1..5
# 1 = FANA..FANC
# - CPU Side (Zone 0): 1x NH-L9x65, 2x NF-F12 PWM
# - HDD Side (Zone 1): 1x NF-F12 PWM, 1x NF-A14 PWM

FAN_ZONE_HDD=1
FAN_ZONE_CPU=0
UPDATE_INTERVAL=30
MIN_PWM=60
LOGFILE="/var/log/fan_control.log"

prev_pwm_hdd=0
prev_pwm_cpu=0

log() {
    echo "$(date '+%F %T') | $*" >> "$LOGFILE"
}

get_spinning_hdd_temps() {
    temps=()
    while read -r device; do
        info=$(smartctl -i "$device" 2>/dev/null)
        if echo "$info" | grep -q "Rotation Rate" && ! echo "$info" | grep -q "Solid State Device"; then
            temp=$(smartctl -A "$device" 2>/dev/null | awk '/Temperature_Celsius/ {print $10}' | head -n1)
            [[ "$temp" =~ ^[0-9]+$ ]] && temps+=("$temp")
        fi
    done < <(smartctl --scan | awk '{print $1}')
    if [ "${#temps[@]}" -eq 0 ]; then echo 0; else
        sum=0; for t in "${temps[@]}"; do ((sum+=t)); done; echo $((sum / ${#temps[@]}))
    fi
}

get_cpu_temp() {
    raw=$(cat /sys/class/thermal/thermal_zone*/temp | head -n1)
    echo $((raw / 1000))
}

set_fan_pwm() {
    zone=$1
    pwm=$2
    (( pwm < MIN_PWM )) && pwm=$MIN_PWM
    (( pwm > 255 )) && pwm=255
    hex_pwm=$(printf "%02x" "$pwm")
    ipmitool raw 0x30 0x70 0x66 0x01 0x0${zone} 0x01 0x$hex_pwm >/dev/null 2>&1
}

fan_curve_hdd() {
    temp=$1
    case $temp in
        [0-39]) echo "80 0–39°C" ;;
        40|41) echo "100 40–41°C" ;;
        42|43) echo "120 42–43°C" ;;
        44|45) echo "140 44–45°C" ;;
        46|47) echo "160 46–47°C" ;;
        *)     echo "180 48°C+" ;;
    esac
}

fan_curve_cpu() {
    temp=$1
    case $temp in
        [0-44]) echo "90 0–44°C" ;;
        45|46) echo "110 45–46°C" ;;
        47|48) echo "130 47–48°C" ;;
        49|50) echo "150 49–50°C" ;;
        51|52) echo "170 51–52°C" ;;
        53|54) echo "190 53–54°C" ;;
        *)     echo "210 55°C+" ;;
    esac
}

while true; do
    hdd_temp=$(get_spinning_hdd_temps)
    cpu_temp=$(get_cpu_temp)

    read pwm_hdd threshold_hdd <<< "$(fan_curve_hdd "$hdd_temp")"
    read pwm_cpu threshold_cpu <<< "$(fan_curve_cpu "$cpu_temp")"

    if [ "$pwm_hdd" -ne "$prev_pwm_hdd" ]; then
        set_fan_pwm "$FAN_ZONE_HDD" "$pwm_hdd"
        log "🧊 HDD Temp: ${hdd_temp}°C → PWM $prev_pwm_hdd → $pwm_hdd (Threshold: $threshold_hdd)"
        prev_pwm_hdd=$pwm_hdd
    fi

    if [ "$pwm_cpu" -ne "$prev_pwm_cpu" ]; then
        set_fan_pwm "$FAN_ZONE_CPU" "$pwm_cpu"
        log "🔥 CPU Temp: ${cpu_temp}°C → PWM $prev_pwm_cpu → $pwm_cpu (Threshold: $threshold_cpu)"
        prev_pwm_cpu=$pwm_cpu
    fi

    sleep $UPDATE_INTERVAL
done
