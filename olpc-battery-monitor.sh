#!/usr/bin/env bash

# ==============================================================================
# EndlessOS Battery Diagnostic Monitor
# OLPC / Factory Diagnostic Logger
#
# Script Version: 1.1.2
#
# Features:
# - Laptop SN using sudo /sys/class/dmi/id/product_serial
# - Battery SN, vendor and model
# - EndlessOS and kernel version
# - AC adapter detection
# - Battery charge percentage
# - Charging / discharging status
# - Voltage
# - Current (BMS or calculated)
# - Power (BMS or calculated)
# - Energy now / full / design / remaining
# - Battery health
# - Session statistics
# - CSV logging every 5 seconds
# - Automatic summary when CTRL+C is pressed
# - Two-column terminal interface
# ==============================================================================

SCRIPT_VERSION="1.1.2"
INTERVAL=5

# ------------------------------------------------------------------------------
# Determine real user and HOME
# ------------------------------------------------------------------------------

REAL_USER="${SUDO_USER:-$USER}"

if command -v getent >/dev/null 2>&1; then
    REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
else
    REAL_HOME="$HOME"
fi

if [ -z "$REAL_HOME" ]; then
    REAL_HOME="$HOME"
fi

LOG_DIR="$REAL_HOME/battery-logs"

mkdir -p "$LOG_DIR"

SESSION_TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# ------------------------------------------------------------------------------
# Request sudo privileges
# ------------------------------------------------------------------------------

echo
echo "OLPC EOS Battery Diagnostic Monitor v$SCRIPT_VERSION"
echo
echo "Requesting sudo privileges to read laptop serial number..."
echo

if ! sudo -v; then
    echo
    echo "ERROR: sudo privileges are required."
    exit 1
fi

# ------------------------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------------------------

read_value() {
    local file="$1"

    if [ -r "$file" ]; then
        cat "$file"
    else
        echo "N/A"
    fi
}

to_volts() {
    local value="$1"

    if [[ "$value" =~ ^-?[0-9]+$ ]]; then
        awk -v v="$value" \
            'BEGIN {printf "%.3f", v / 1000000}'
    else
        echo "N/A"
    fi
}

to_amps() {
    local value="$1"

    if [[ "$value" =~ ^-?[0-9]+$ ]]; then
        awk -v v="$value" \
            'BEGIN {printf "%.3f", v / 1000000}'
    else
        echo "N/A"
    fi
}

to_watts() {
    local value="$1"

    if [[ "$value" =~ ^-?[0-9]+$ ]]; then
        awk -v v="$value" \
            'BEGIN {printf "%.3f", v / 1000000}'
    else
        echo "N/A"
    fi
}

to_wh() {
    local value="$1"

    if [[ "$value" =~ ^-?[0-9]+$ ]]; then
        awk -v v="$value" \
            'BEGIN {printf "%.3f", v / 1000000}'
    else
        echo "N/A"
    fi
}

# ------------------------------------------------------------------------------
# Detect battery
# ------------------------------------------------------------------------------

BATTERY=""

for dev in /sys/class/power_supply/BAT*; do
    if [ -d "$dev" ]; then
        BATTERY="$dev"
        break
    fi
done

if [ -z "$BATTERY" ]; then
    echo
    echo "ERROR: No battery detected."
    echo
    exit 1
fi

BAT_NAME=$(basename "$BATTERY")

# ------------------------------------------------------------------------------
# Laptop information
# ------------------------------------------------------------------------------

DEVICE_SN=$(sudo cat /sys/class/dmi/id/product_serial 2>/dev/null)

if [ -z "$DEVICE_SN" ]; then
    DEVICE_SN="N/A"
fi

PRODUCT_NAME=$(read_value /sys/class/dmi/id/product_name)
PRODUCT_VENDOR=$(read_value /sys/class/dmi/id/sys_vendor)

ENDLESS_VERSION=$(
    grep '^VERSION_ID=' /etc/os-release 2>/dev/null |
        cut -d= -f2 |
        tr -d '"'
)

if [ -z "$ENDLESS_VERSION" ]; then
    ENDLESS_VERSION="N/A"
fi

KERNEL_VERSION=$(uname -r)

# ------------------------------------------------------------------------------
# Battery information
# ------------------------------------------------------------------------------

BAT_VENDOR=$(read_value "$BATTERY/manufacturer")
BAT_MODEL=$(read_value "$BATTERY/model_name")
BATTERY_SN=$(read_value "$BATTERY/serial_number")

# ------------------------------------------------------------------------------
# Safe serial for filenames
# ------------------------------------------------------------------------------

SAFE_SN=$(echo "$DEVICE_SN" | tr -cd '[:alnum:]_-')

if [ -z "$SAFE_SN" ] || [ "$SAFE_SN" = "NA" ]; then
    SAFE_SN="UNKNOWN"
fi

LOG_FILE="$LOG_DIR/battery_${SAFE_SN}_${SESSION_TIMESTAMP}.csv"
SUMMARY_FILE="$LOG_DIR/battery_${SAFE_SN}_${SESSION_TIMESTAMP}_summary.txt"

# ------------------------------------------------------------------------------
# Detect AC adapter
# ------------------------------------------------------------------------------

get_ac_status() {
    local found=0

    for supply in /sys/class/power_supply/*; do

        if [ "$supply" = "$BATTERY" ]; then
            continue
        fi

        if [ -r "$supply/online" ]; then

            found=1

            if [ "$(cat "$supply/online" 2>/dev/null)" = "1" ]; then
                echo "CONNECTED"
                return
            fi
        fi
    done

    if [ "$found" = "1" ]; then
        echo "DISCONNECTED"
    else
        echo "N/A"
    fi
}

# ------------------------------------------------------------------------------
# Session variables
# ------------------------------------------------------------------------------

START_EPOCH=$(date +%s)

INITIAL_CAPACITY=""
INITIAL_ENERGY=""

LAST_CAPACITY="N/A"
LAST_ENERGY="N/A"

SAMPLES=0
POWER_SAMPLES=0

POWER_SUM="0"
POWER_MIN=""
POWER_MAX=""

VOLTAGE_MIN=""
VOLTAGE_MAX=""

# ------------------------------------------------------------------------------
# Generate summary
# ------------------------------------------------------------------------------

generate_summary() {

    END_EPOCH=$(date +%s)
    DURATION=$((END_EPOCH - START_EPOCH))

    HOURS=$((DURATION / 3600))
    MINUTES=$(((DURATION % 3600) / 60))
    SECONDS=$((DURATION % 60))

    AVG_POWER="N/A"

    if [ "$POWER_SAMPLES" -gt 0 ]; then
        AVG_POWER=$(
            awk \
                -v sum="$POWER_SUM" \
                -v n="$POWER_SAMPLES" \
                'BEGIN {printf "%.3f", sum/n}'
        )
    fi

    ENERGY_GAIN="N/A"

    if [[ "$INITIAL_ENERGY" =~ ^-?[0-9.]+$ ]] &&
       [[ "$LAST_ENERGY" =~ ^-?[0-9.]+$ ]]; then

        ENERGY_GAIN=$(
            awk \
                -v start="$INITIAL_ENERGY" \
                -v end="$LAST_ENERGY" \
                'BEGIN {printf "%.3f", end-start}'
        )
    fi

    CAPACITY_GAIN="N/A"

    if [[ "$INITIAL_CAPACITY" =~ ^[0-9]+$ ]] &&
       [[ "$LAST_CAPACITY" =~ ^[0-9]+$ ]]; then

        CAPACITY_GAIN=$((LAST_CAPACITY - INITIAL_CAPACITY))
    fi

    {
        echo "=============================================================================="
        echo " EndlessOS Battery Diagnostic Summary"
        echo " Script Version: $SCRIPT_VERSION"
        echo "=============================================================================="
        echo
        echo "DEVICE INFORMATION"
        echo "------------------------------------------------------------------------------"
        echo "Laptop SN          : $DEVICE_SN"
        echo "Vendor             : $PRODUCT_VENDOR"
        echo "Product            : $PRODUCT_NAME"
        echo "EndlessOS          : $ENDLESS_VERSION"
        echo "Kernel             : $KERNEL_VERSION"
        echo
        echo "BATTERY INFORMATION"
        echo "------------------------------------------------------------------------------"
        echo "Battery            : $BAT_NAME"
        echo "Battery SN         : $BATTERY_SN"
        echo "Vendor             : $BAT_VENDOR"
        echo "Model              : $BAT_MODEL"
        echo
        echo "TEST RESULTS"
        echo "------------------------------------------------------------------------------"
        echo "Start charge       : ${INITIAL_CAPACITY}%"
        echo "End charge         : ${LAST_CAPACITY}%"
        echo "Charge change      : ${CAPACITY_GAIN}%"
        echo
        echo "Start energy       : ${INITIAL_ENERGY} Wh"
        echo "End energy         : ${LAST_ENERGY} Wh"
        echo "Energy change      : ${ENERGY_GAIN} Wh"
        echo
        echo "Power min          : ${POWER_MIN:-N/A} W"
        echo "Power max          : ${POWER_MAX:-N/A} W"
        echo "Power average      : ${AVG_POWER} W"
        echo
        echo "Voltage min        : ${VOLTAGE_MIN:-N/A} V"
        echo "Voltage max        : ${VOLTAGE_MAX:-N/A} V"
        echo
        printf "Duration           : %02d:%02d:%02d\n" \
            "$HOURS" "$MINUTES" "$SECONDS"
        echo "Samples            : $SAMPLES"
        echo
        echo "CSV log:"
        echo "$LOG_FILE"
        echo "=============================================================================="

    } > "$SUMMARY_FILE"

    clear

    cat "$SUMMARY_FILE"

    echo
    echo "FILES GENERATED"
    echo "------------------------------------------------------------------------------"
    echo "$LOG_FILE"
    echo "$SUMMARY_FILE"
    echo
}

trap 'generate_summary; exit 0' INT TERM

# ------------------------------------------------------------------------------
# CSV header
# ------------------------------------------------------------------------------

echo "timestamp,script_version,laptop_serial,device_vendor,device_model,endless_version,kernel,battery,battery_serial,battery_vendor,battery_model,ac,status,charge_percent,voltage_V,current_A,current_source,power_W,power_source,energy_now_Wh,energy_full_Wh,energy_design_Wh,energy_remaining_Wh,battery_health_percent" > "$LOG_FILE"

# ------------------------------------------------------------------------------
# Main loop
# ------------------------------------------------------------------------------

while true; do

    DATE=$(date '+%Y-%m-%d %H:%M:%S')

    STATUS=$(read_value "$BATTERY/status")
    CAPACITY=$(read_value "$BATTERY/capacity")

    VOLTAGE_RAW=$(read_value "$BATTERY/voltage_now")
    CURRENT_RAW=$(read_value "$BATTERY/current_now")
    POWER_RAW=$(read_value "$BATTERY/power_now")

    ENERGY_NOW_RAW=$(read_value "$BATTERY/energy_now")
    ENERGY_FULL_RAW=$(read_value "$BATTERY/energy_full")
    ENERGY_DESIGN_RAW=$(read_value "$BATTERY/energy_full_design")

    VOLTAGE=$(to_volts "$VOLTAGE_RAW")
    CURRENT=$(to_amps "$CURRENT_RAW")
    POWER=$(to_watts "$POWER_RAW")

    ENERGY_NOW=$(to_wh "$ENERGY_NOW_RAW")
    ENERGY_FULL=$(to_wh "$ENERGY_FULL_RAW")
    ENERGY_DESIGN=$(to_wh "$ENERGY_DESIGN_RAW")

    CURRENT_SOURCE="BMS"
    POWER_SOURCE="BMS"

    # --------------------------------------------------------------------------
    # Calculate power if BMS does not expose power_now
    #
    # P = V * I
    # --------------------------------------------------------------------------

    if [ "$POWER" = "N/A" ] &&
       [[ "$VOLTAGE" =~ ^[0-9.]+$ ]] &&
       [[ "$CURRENT" =~ ^-?[0-9.]+$ ]]; then

        POWER=$(
            awk \
                -v v="$VOLTAGE" \
                -v i="$CURRENT" \
                'BEGIN {printf "%.3f", v*i}'
        )

        POWER_SOURCE="CALCULATED"
    fi

    # --------------------------------------------------------------------------
    # Calculate current if BMS does not expose current_now
    #
    # I = P / V
    # --------------------------------------------------------------------------

    if [ "$CURRENT" = "N/A" ] &&
       [[ "$POWER" =~ ^-?[0-9.]+$ ]] &&
       [[ "$VOLTAGE" =~ ^[0-9.]+$ ]]; then

        CURRENT=$(
            awk \
                -v p="$POWER" \
                -v v="$VOLTAGE" \
                'BEGIN {
                    if (v > 0)
                        printf "%.3f", p/v;
                    else
                        print "N/A"
                }'
        )

        CURRENT_SOURCE="CALCULATED"
    fi

    # --------------------------------------------------------------------------
    # Remaining energy
    # --------------------------------------------------------------------------

    ENERGY_REMAINING="N/A"

    if [[ "$ENERGY_FULL" =~ ^[0-9.]+$ ]] &&
       [[ "$ENERGY_NOW" =~ ^[0-9.]+$ ]]; then

        ENERGY_REMAINING=$(
            awk \
                -v full="$ENERGY_FULL" \
                -v now="$ENERGY_NOW" \
                'BEGIN {printf "%.3f", full-now}'
        )
    fi

    # --------------------------------------------------------------------------
    # Battery health
    #
    # energy_full / energy_full_design * 100
    # --------------------------------------------------------------------------

    BATTERY_HEALTH="N/A"

    if [[ "$ENERGY_FULL" =~ ^[0-9.]+$ ]] &&
       [[ "$ENERGY_DESIGN" =~ ^[0-9.]+$ ]]; then

        BATTERY_HEALTH=$(
            awk \
                -v full="$ENERGY_FULL" \
                -v design="$ENERGY_DESIGN" \
                'BEGIN {
                    if (design > 0)
                        printf "%.1f", (full/design)*100;
                    else
                        print "N/A"
                }'
        )
    fi

    AC_STATUS=$(get_ac_status)

    # --------------------------------------------------------------------------
    # Initial values
    # --------------------------------------------------------------------------

    if [ -z "$INITIAL_CAPACITY" ]; then
        INITIAL_CAPACITY="$CAPACITY"
    fi

    if [ -z "$INITIAL_ENERGY" ]; then
        INITIAL_ENERGY="$ENERGY_NOW"
    fi

    LAST_CAPACITY="$CAPACITY"
    LAST_ENERGY="$ENERGY_NOW"

    # --------------------------------------------------------------------------
    # Power statistics
    # --------------------------------------------------------------------------

    if [[ "$POWER" =~ ^-?[0-9.]+$ ]]; then

        POWER_SUM=$(
            awk \
                -v a="$POWER_SUM" \
                -v b="$POWER" \
                'BEGIN {printf "%.6f", a+b}'
        )

        POWER_SAMPLES=$((POWER_SAMPLES + 1))

        if [ -z "$POWER_MIN" ] ||
           awk \
               -v x="$POWER" \
               -v y="$POWER_MIN" \
               'BEGIN {exit !(x<y)}'; then

            POWER_MIN="$POWER"
        fi

        if [ -z "$POWER_MAX" ] ||
           awk \
               -v x="$POWER" \
               -v y="$POWER_MAX" \
               'BEGIN {exit !(x>y)}'; then

            POWER_MAX="$POWER"
        fi
    fi

    # --------------------------------------------------------------------------
    # Voltage statistics
    # --------------------------------------------------------------------------

    if [[ "$VOLTAGE" =~ ^[0-9.]+$ ]]; then

        if [ -z "$VOLTAGE_MIN" ] ||
           awk \
               -v x="$VOLTAGE" \
               -v y="$VOLTAGE_MIN" \
               'BEGIN {exit !(x<y)}'; then

            VOLTAGE_MIN="$VOLTAGE"
        fi

        if [ -z "$VOLTAGE_MAX" ] ||
           awk \
               -v x="$VOLTAGE" \
               -v y="$VOLTAGE_MAX" \
               'BEGIN {exit !(x>y)}'; then

            VOLTAGE_MAX="$VOLTAGE"
        fi
    fi

    SAMPLES=$((SAMPLES + 1))

    # --------------------------------------------------------------------------
    # Current display
    # --------------------------------------------------------------------------

    if [ "$CURRENT_SOURCE" = "CALCULATED" ]; then
        CURRENT_DISPLAY="${CURRENT} A (calc)"
    else
        CURRENT_DISPLAY="${CURRENT} A"
    fi

    # --------------------------------------------------------------------------
    # Power display
    # --------------------------------------------------------------------------

    if [ "$POWER_SOURCE" = "CALCULATED" ]; then
        POWER_DISPLAY="${POWER} W (calc)"
    else
        POWER_DISPLAY="${POWER} W"
    fi

    # --------------------------------------------------------------------------
    # Screen - Two column layout
    # --------------------------------------------------------------------------

    clear

    COL_WIDTH=38

    echo "=============================================================================="
    printf " EndlessOS Battery Diagnostic Monitor                               v%s\n" \
        "$SCRIPT_VERSION"
    echo "=============================================================================="
    echo

    # --------------------------------------------------------------------------
    # DEVICE + BATTERY
    # --------------------------------------------------------------------------

    printf "%-${COL_WIDTH}s | %-${COL_WIDTH}s\n" \
        "DEVICE INFORMATION" \
        "BATTERY INFORMATION"

    echo "---------------------------------------+--------------------------------------"

    printf " %-17s %-19s | %-17s %-19s\n" \
        "Laptop SN:" "$DEVICE_SN" \
        "Battery:" "$BAT_NAME"

    printf " %-17s %-19s | %-17s %-19s\n" \
        "Vendor:" "$PRODUCT_VENDOR" \
        "Battery SN:" "$BATTERY_SN"

    printf " %-17s %-19s | %-17s %-19s\n" \
        "Product:" "$PRODUCT_NAME" \
        "Vendor:" "$BAT_VENDOR"

    printf " %-17s %-19s | %-17s %-19s\n" \
        "EndlessOS:" "$ENDLESS_VERSION" \
        "Model:" "$BAT_MODEL"

    printf " %-17s %-19s | %-17s %-19s\n" \
        "Kernel:" "$KERNEL_VERSION" \
        "" ""

    echo
    echo "=============================================================================="
    echo

    # --------------------------------------------------------------------------
    # LIVE STATUS + SESSION
    # --------------------------------------------------------------------------

    printf "%-${COL_WIDTH}s | %-${COL_WIDTH}s\n" \
        "LIVE STATUS" \
        "SESSION"

    echo "---------------------------------------+--------------------------------------"

    printf " %-17s %-19s | %-17s %-19s\n" \
        "Time:" "$DATE" \
        "Initial charge:" "${INITIAL_CAPACITY}%"

    printf " %-17s %-19s | %-17s %-19s\n" \
        "AC Adapter:" "$AC_STATUS" \
        "Current charge:" "${CAPACITY}%"

    printf " %-17s %-19s | %-17s %-19s\n" \
        "Battery status:" "$STATUS" \
        "Samples:" "$SAMPLES"

    printf " %-17s %-19s | %-17s %-19s\n" \
        "Charge:" "${CAPACITY}%" \
        "Interval:" "${INTERVAL}s"

    printf " %-17s %-19s | %-17s %-19s\n" \
        "Voltage:" "${VOLTAGE} V" \
        "Power min:" "${POWER_MIN:-N/A} W"

    printf " %-17s %-19s | %-17s %-19s\n" \
        "Current:" "$CURRENT_DISPLAY" \
        "Power max:" "${POWER_MAX:-N/A} W"

    printf " %-17s %-19s | %-17s %-19s\n" \
        "Power:" "$POWER_DISPLAY" \
        "Power samples:" "$POWER_SAMPLES"

    printf " %-17s %-19s | %-17s %-19s\n" \
        "Energy now:" "${ENERGY_NOW} Wh" \
        "Voltage min:" "${VOLTAGE_MIN:-N/A} V"

    printf " %-17s %-19s | %-17s %-19s\n" \
        "Energy full:" "${ENERGY_FULL} Wh" \
        "Voltage max:" "${VOLTAGE_MAX:-N/A} V"

    printf " %-17s %-19s | %-17s %-19s\n" \
        "Energy remaining:" "${ENERGY_REMAINING} Wh" \
        "" ""

    printf " %-17s %-19s | %-17s %-19s\n" \
        "Battery health:" "${BATTERY_HEALTH}%" \
        "" ""

    echo
    echo "=============================================================================="
    echo " LOG FILE"
    echo "------------------------------------------------------------------------------"
    echo " $LOG_FILE"
    echo
    echo " CTRL+C to stop monitoring and generate summary"
    echo "=============================================================================="

    # --------------------------------------------------------------------------
    # CSV log
    # --------------------------------------------------------------------------

    echo "\"$DATE\",\"$SCRIPT_VERSION\",\"$DEVICE_SN\",\"$PRODUCT_VENDOR\",\"$PRODUCT_NAME\",\"$ENDLESS_VERSION\",\"$KERNEL_VERSION\",\"$BAT_NAME\",\"$BATTERY_SN\",\"$BAT_VENDOR\",\"$BAT_MODEL\",\"$AC_STATUS\",\"$STATUS\",\"$CAPACITY\",\"$VOLTAGE\",\"$CURRENT\",\"$CURRENT_SOURCE\",\"$POWER\",\"$POWER_SOURCE\",\"$ENERGY_NOW\",\"$ENERGY_FULL\",\"$ENERGY_DESIGN\",\"$ENERGY_REMAINING\",\"$BATTERY_HEALTH\"" \
        >> "$LOG_FILE"

    sleep "$INTERVAL"

done