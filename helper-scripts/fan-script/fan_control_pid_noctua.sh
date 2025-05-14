#!/bin/bash

# PID Fan Control Script for Supermicro X11SSH-F
# Fan setup:
# 0 = FAN1..5
# 1 = FANA..FANC
# - CPU Side (Zone 0): NH-L9x65 + 2x NF-F12 PWM
# - HDD Side (Zone 1): NF-F12 + NF-A14 PWM

FAN_ZONE_HDD=1
FAN_ZONE_CPU=0
UPDATE_INTERVAL=30
MIN_PWM=60
LOGFILE="/var/log/fan_control.log"

# Target temperatures
TARGET_CPU_TEMP=45
TARGET_HDD_TEMP=38

# PID tuning values (can be adjusted)
CPU_KP=6
CPU_KI=0.3
CPU_KD=3

HDD_KP=4
HDD_KI=0.2
HDD_KD=2

# Previous values for PID computation
declare -A prev_error integral

prev_pwm_cpu=0
prev_pwm_hdd=0

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

compute_pid_pwm() {
    zone="$1"
    current_temp="$2"
    target_temp="$3"
    kp="$4"
    ki="$5"
    kd="$6"

    error=$((current_temp - target_temp))
    integral[$zone]=$((integral[$zone] + error * UPDATE_INTERVAL))
    delta=$((error - ${prev_error[$zone]:-0}))
    derivative=$((delta / UPDATE_INTERVAL))

    # Calculate PID output and convert to integer
    pwm_delta=$(echo "$kp * $error + $ki * ${integral[$zone]} + $kd * $derivative" | bc -l)
    pwm_delta=${pwm_delta%.*}
    pwm=$((128 + pwm_delta))

    prev_error[$zone]=$error
    echo "$pwm"
}

while true; do
    cpu_temp=$(get_cpu_temp)
    hdd_temp=$(get_spinning_hdd_temps)

    pwm_cpu=$(compute_pid_pwm "cpu" "$cpu_temp" "$TARGET_CPU_TEMP" $CPU_KP $CPU_KI $CPU_KD)
    pwm_hdd=$(compute_pid_pwm "hdd" "$hdd_temp" "$TARGET_HDD_TEMP" $HDD_KP $HDD_KI $HDD_KD)

    if [ "$pwm_cpu" -ne "$prev_pwm_cpu" ]; then
        set_fan_pwm "$FAN_ZONE_CPU" "$pwm_cpu"
        log "🔥 CPU Temp: ${cpu_temp}°C | PWM: $prev_pwm_cpu → $pwm_cpu"
        prev_pwm_cpu=$pwm_cpu
    fi

    if [ "$pwm_hdd" -ne "$prev_pwm_hdd" ]; then
        set_fan_pwm "$FAN_ZONE_HDD" "$pwm_hdd"
        log "🧊 HDD Temp: ${hdd_temp}°C | PWM: $prev_pwm_hdd → $pwm_hdd"
        prev_pwm_hdd=$pwm_hdd
    fi

    sleep $UPDATE_INTERVAL
done
