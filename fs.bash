#!/bin/bash

set -e

INSTALL_PATH="/usr/local/bin/fs"
CONFIG_FILE="/etc/fan_speed_config"

echo "Install Dell Server Fan Speed Adjustment Tool..."

if ! command -v ipmitool &>/dev/null; then
    echo "ipmitool is not installed yet, installing..."
    sudo apt update
    sudo apt install -y ipmitool
else
    echo "ipmitool is installed."
fi

cat << 'EOF' > "$INSTALL_PATH"
#!/bin/bash

CONFIG_FILE="/etc/fan_speed_config"

if [[ "$1" == "set" ]]; then
    if [[ $EUID -ne 0 ]]; then
        echo "Please use sudo to execute 'fs set'"
        exit 1
    fi

    read -p "Please enter the iDRAC address: " IDRAC_IP
    read -p "Please enter the iDRAC username: " IDRAC_USER
    read -s -p "Please enter the iDRAC password: " IDRAC_PASS
    echo
    {
        echo "IDRAC_IP=\"$IDRAC_IP\""
        echo "IDRAC_USER=\"$IDRAC_USER\""
        echo "IDRAC_PASS=\"$IDRAC_PASS\""
    } > "$CONFIG_FILE"

    chmod 600 "$CONFIG_FILE"
    echo "Settings saved to $CONFIG_FILE。"
    exit 0
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file not found. Please use 'sudo fs set' to configure first."
    exit 1
fi

source "$CONFIG_FILE"

if ! [[ "$1" =~ ^[0-9]+$ ]]; then
    echo "Please enter an integer between 0 and 100."
    exit 1
fi

VALUE=$1

if (( VALUE < 0 || VALUE > 100 )); then
    echo "The value must be between 0 and 100."
    exit 1
fi

ipmitool -I lanplus -H "$IDRAC_IP" -U "$IDRAC_USER" -P "$IDRAC_PASS" raw 0x30 0x30 0x01 0x00

HEX_VALUE=$(printf "0x%02x" "$VALUE")
ipmitool -I lanplus -H "$IDRAC_IP" -U "$IDRAC_USER" -P "$IDRAC_PASS" raw 0x30 0x30 0x02 0xff "$HEX_VALUE"
EOF

chmod +x "$INSTALL_PATH"
echo "Installed Dell Server Fan Speed Adjustment Tool to $INSTALL_PATH"

if [[ ! -f "$CONFIG_FILE" ]]; then
    touch "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    echo "Config file created: $CONFIG_FILE"
fi

echo
echo "Installation complete! Usage:"
echo "  ➤ Settings iDRAC: sudo fs set"
echo "  ➤ Set fan speed: fs <數值 0~100>"
