#!/bin/bash
# Script to set fixed device paths for eth0 and eth1 on a NanoPi R5C / R5S on systems running a Rockchip kernel
# Based on MichaIng's work: https://dietpi.com/forum/t/nanopi-r5c-eth0-and-eth1-swapping/24845/2

# Function to print interface details
print_iface_info() {
    local IFACE="$1"
    if ip link show "$IFACE" &>/dev/null; then
        echo "- $IFACE exists"
        if [ -e "/sys/class/net/$IFACE/device" ]; then
            echo "-   Path: $(readlink -f /sys/class/net/$IFACE/device)"
        fi
    else
        echo "- $IFACE does not exist"
    fi
}

# Check OS is DietPi 
if [ -f /boot/dietpi/.version ] || [ -d /etc/dietpi ]; then
    echo "> DietPi detected"
else
    echo "! Not running DietPi - exiting"
    exit 0
fi

# Check hardware model is NanoPi R5S / R5C
if grep -q "NanoPi R5S/R5C" /boot/dietpi/.hw_model; then
    echo "> NanoPi R5S/R5C hardware detected"
else
    echo "! Unsupported hardware"
    exit 0
fi

# Check if the running kernel contains "rockchip"
if uname -r | grep -qi rockchip; then
    echo "> Rockchip kernel detected"
else
    echo "! Rockchip kernel not detected - no changes made"
fi

# Check if eth0 device path contains "3c0400000"
ETH0_PATH=$(readlink -f /sys/class/net/eth0/device 2>/dev/null || echo "")

if [[ "$ETH0_PATH" == *"3c0400000"* ]]; then
    echo "> eth0 path correct"
    LAN_IF="${ETH0_PATH##*/}"
    ETH1_PATH=$(readlink -f /sys/class/net/eth1/device 2>/dev/null)
    WAN_IF="${ETH1_PATH##*/}"
else
    echo "! eth0 path incorrect"
    WAN_IF="${ETH0_PATH##*/}"
    ETH1_PATH=$(readlink -f /sys/class/net/eth1/device 2>/dev/null)
    LAN_IF="${ETH1_PATH##*/}"
fi
echo ""

echo "> Before udev rules applied:"
print_iface_info eth0
print_iface_info eth1
echo ""

sudo tee /etc/udev/rules.d/99-dietpi-nanopir5c.rules > /dev/null <<EOT
# NanoPi R5C eth0 eth1 fix
# https://github.com/MDBInd/DietPi-Scripts/blob/main/Nanopi_R5C_R5S-Rockchip-fix.sh
SUBSYSTEM=="net", KERNEL=="eth0", KERNELS=="$WAN_IF", RUN:="/bin/true"
SUBSYSTEM=="net", KERNEL=="eth1", KERNELS=="$LAN_IF", NAME="to_eth0", RUN:="/bin/true"
SUBSYSTEM=="net", KERNEL=="to_eth0", RUN="/bin/ip l s dev eth0 name eth1", RUN+="/bin/ip l s dev to_eth0 name eth0", RUN+="/bin/udevadm trigger -c add /sys/class/net/eth0 /sys/class/net/eth1"
EOT

echo "> udev rules written to /etc/udev/rules.d/99-dietpi-nanopir5c.rules"
echo ""

echo "> Reloading udev ..."

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "> Reboot for changes to take effect..."
