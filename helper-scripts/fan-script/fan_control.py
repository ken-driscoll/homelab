#!/usr/bin/env python3
import subprocess
import time
import logging

# === CONFIGURATION ===

LOG_FILE = "/var/log/fan_control.log"
HD_POLLING_INTERVAL = 180  # seconds between control loop
CPU_FAN_ZONE = 0           # zone 0: CPU/case
HD_FAN_ZONE = 1            # zone 1: HDDs
CPU_FAN_HEADER = "FAN1"    # for logging, adjust as needed
HD_FAN_HEADER = "FANA"
HD_LIST = []               # autodetect
SMARTCTL_PATH = "/usr/sbin/smartctl"
IPMITOOL_PATH = "/usr/bin/ipmitool"

# PID Config
CONFIG_NUM_DISKS = 8      # number of warmest disks to average
CONFIG_TA = 37.625        # target temp for avg of warmest disks
CONFIG_KP = 8/3
CONFIG_KI = 0
CONFIG_KD = 36
CONFIG_HD_FAN_START = 36

HD_MAX_ALLOWED_TEMP = 40  # °C: any disk at/above this triggers 100% fans

FAN_DUTY_HIGH = 100
FAN_DUTY_MED = 60
FAN_DUTY_LOW = 30

HIGH_CPU_TEMP = 55
MED_CPU_TEMP = 45
LOW_CPU_TEMP = 35

# === END CONFIGURATION ===

logging.basicConfig(filename=LOG_FILE,
                    level=logging.INFO,
                    format="%(asctime)s %(message)s")

last_cpu_pwm = None
last_hd_pwm = None
integral = 0
prev_error = 0

def run(cmd):
    """Run a shell command, return output as string."""
    result = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return result.stdout.strip()

def get_drive_list():
    # Returns a list of /dev/sdX device names with rotational=1 (spinning disks only)
    output = run("lsblk -dn -o NAME,ROTA | awk '$2==1{print $1}'")
    drives = [d for d in output.split() if d.startswith('sd')]
    return drives

def get_hd_temps(devs):
    temps = []
    for dev in devs:
        # Try to get temp for each drive
        out = run(f"{SMARTCTL_PATH} -A /dev/{dev} | grep -i temperature_celsius | awk '{{print $10}}'")
        try:
            t = int(out)
            temps.append(t)
        except Exception:
            continue
    return temps

def get_cpu_temp():
    # Find highest core temp
    output = run("sensors | grep -E 'Core [0-9]+:' | awk '{print $3}' | tr -d '+°C'")
    temps = []
    for t in output.split():
        try:
            temps.append(float(t))
        except Exception:
            continue
    return max(temps) if temps else None

def set_fan_pwm(zone, pwm):
    pwm = int(round(pwm))
    pwm = max(20, min(100, pwm))
    run(f"{IPMITOOL_PATH} raw 0x30 0x70 0x66 0x01 {zone} {pwm}")

def main():
    global last_cpu_pwm, last_hd_pwm, integral, prev_error

    # Set both fan zones to full for direct PWM control
    run(f"{IPMITOOL_PATH} raw 0x30 0x45 0x01 0x01")  # full speed mode

    time.sleep(5)
    logging.info("Fan control script started.")

    while True:
        drives = get_drive_list()
        if not drives:
            logging.warning("No drives found.")
            time.sleep(HD_POLLING_INTERVAL)
            continue

        temps = get_hd_temps(drives)
        if not temps:
            logging.warning("No HDD temps found.")
            time.sleep(HD_POLLING_INTERVAL)
            continue

        warmest = sorted(temps, reverse=True)[:CONFIG_NUM_DISKS]
        hd_avg_temp = sum(warmest) / len(warmest)
        hd_max_temp = max(temps)

        # PID control for HD fans
        error = hd_avg_temp - CONFIG_TA
        integral += error * HD_POLLING_INTERVAL / 60
        derivative = (error - prev_error) * 60 / HD_POLLING_INTERVAL
        hd_pwm = (last_hd_pwm or CONFIG_HD_FAN_START) + CONFIG_KP * error + CONFIG_KI * integral + CONFIG_KD * derivative
        prev_error = error

        if hd_max_temp >= HD_MAX_ALLOWED_TEMP:
            hd_pwm = FAN_DUTY_HIGH

        hd_pwm = int(round(min(max(hd_pwm, FAN_DUTY_LOW), FAN_DUTY_HIGH)))

        # Set HD fan zone
        if hd_pwm != last_hd_pwm:
            logging.info(f"🔄 HD Avg Temp: {hd_avg_temp:.1f}°C | Max: {hd_max_temp}°C | PWM: {last_hd_pwm} → {hd_pwm}")
            set_fan_pwm(HD_FAN_ZONE, hd_pwm)
            last_hd_pwm = hd_pwm

        # CPU fan logic (step-based, can adapt to PID if desired)
        cpu_temp = get_cpu_temp()
        cpu_pwm = FAN_DUTY_LOW
        if cpu_temp is not None:
            if cpu_temp >= HIGH_CPU_TEMP:
                cpu_pwm = FAN_DUTY_HIGH
            elif cpu_temp >= MED_CPU_TEMP:
                cpu_pwm = FAN_DUTY_MED
            elif cpu_temp >= LOW_CPU_TEMP:
                cpu_pwm = FAN_DUTY_LOW
            if cpu_pwm != last_cpu_pwm:
                logging.info(f"🔥 CPU Temp: {cpu_temp}°C | PWM: {last_cpu_pwm} → {cpu_pwm}")
                set_fan_pwm(CPU_FAN_ZONE, cpu_pwm)
                last_cpu_pwm = cpu_pwm

        time.sleep(HD_POLLING_INTERVAL)

if __name__ == "__main__":
    main()