#!/bin/sh
################################################################################
# Asus-Merlin Network Client Monitor
# Compatible with GT-AX6000 running Asus-Merlin Firmware 3006.102.6
# Identifies all active interfaces and connected clients across bands
################################################################################

# Enable strict error handling
set -u

################################################################################
# CONSTANTS AND CONFIGURATION
################################################################################
NVRAM="nvram"
WL="wl"
ARP="arp"
IFCONFIG="ifconfig"
CAT="cat"

################################################################################
# UTILITY FUNCTIONS
################################################################################

# Check if IP is a local/private address
is_local_ip() {
    local ip="$1"
    
    # Check for private IP ranges
    case "${ip}" in
        10.*) return 0 ;;
        192.168.*) return 0 ;;
        172.1[6-9].*) return 0 ;;
        172.2[0-9].*) return 0 ;;
        172.3[0-1].*) return 0 ;;
        169.254.*) return 0 ;;  # Link-local
        127.*) return 0 ;;       # Loopback
        *) return 1 ;;
    esac
}

# Get all active wireless interfaces
get_wireless_interfaces() {
    ${IFCONFIG} | grep '^eth[0-9]\|^wl[0-9]' | awk '{print $1}' | while read iface; do
        # Verify interface actually has wireless capability
        if ${WL} -i "${iface}" status >/dev/null 2>&1; then
            echo "${iface}"
        fi
    done | sort -u
}

# Get interface type and band information
get_interface_info() {
    local iface="$1"
    local band=""
    local type=""
    local guest_ssid=""
    
    # Check if it's a guest network interface (e.g., wl0.1, wl1.1)
    if echo "${iface}" | grep '\.' >/dev/null 2>&1; then
        local base_iface=$(echo "${iface}" | cut -d'.' -f1)
        local guest_num=$(echo "${iface}" | cut -d'.' -f2)
        
        # Determine band from base interface
        case "${base_iface}" in
            wl0|eth6) band="2.4GHz" ;;
            wl1|eth7) band="5.0GHz" ;;
            wl2|eth8) band="6.0GHz" ;;
        esac
        
        # Get guest SSID
        guest_ssid=$(${NVRAM} get ${base_iface}.${guest_num}_ssid 2>/dev/null || echo "Guest Network")
        type="guest"
        echo "${type}|${band}|${guest_ssid}"
        return
    fi
    
    # Determine main interface type
    case "${iface}" in
        eth6|wl0) band="2.4GHz"; type="main" ;;
        eth7|wl1) band="5.0GHz"; type="main" ;;
        eth8|wl2) band="6.0GHz"; type="main" ;;
        br0) type="lan" ;;
        *) type="unknown" ;;
    esac
    
    echo "${type}|${band}|"
}

# Convert seconds to hours:minutes format
format_uptime() {
    local seconds="$1"
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    printf "%02dh:%02dm" "${hours}" "${minutes}"
}

# Convert bytes to GB
bytes_to_gb() {
    local bytes="$1"
    if [ "${bytes}" -eq 0 ] 2>/dev/null; then
        echo "0.00"
    else
        echo "${bytes}" | awk '{printf "%.2f", $1/1024/1024/1024}'
    fi
}

# Get IP address for a MAC from ARP table
get_ip_from_mac() {
    local mac="$1"
    local ip=""
    
    # Try /proc/net/arp first (more reliable)
    if [ -f /proc/net/arp ]; then
        ip=$(grep -i "${mac}" /proc/net/arp 2>/dev/null | awk '{print $1}' | head -n1)
    fi
    
    # Fallback to arp command
    if [ -z "${ip}" ]; then
        ip=$(${ARP} -n 2>/dev/null | grep -i "${mac}" | awk '{print $1}' | head -n1)
    fi
    
    # Return IP or Unknown
    if [ -z "${ip}" ] || [ "${ip}" = "?" ]; then
        echo "Unknown"
    else
        echo "${ip}"
    fi
}

# Get hostname from dnsmasq leases and nvram - MAC-specific
get_hostname() {
    local mac="$1"
    local ip="$2"
    local hostname=""
    local mac_normalized=$(echo "${mac}" | tr 'A-F' 'a-f')
    
    # Try dnsmasq leases first - match by MAC
    if [ -f /var/lib/misc/dnsmasq.leases ]; then
        hostname=$(awk -v mac="${mac_normalized}" 'tolower($2) == mac {print $4; exit}' /var/lib/misc/dnsmasq.leases 2>/dev/null)
    fi
    
    # Try matching by IP in dnsmasq if MAC didn't work
    if [ -z "${hostname}" ] || [ "${hostname}" = "*" ]; then
        if [ -f /var/lib/misc/dnsmasq.leases ] && [ "${ip}" != "Unknown" ]; then
            hostname=$(awk -v ip="${ip}" '$3 == ip {print $4; exit}' /var/lib/misc/dnsmasq.leases 2>/dev/null)
        fi
    fi
    
    # Try nvram custom_clientlist - format is <name>MAC>IP
    if [ -z "${hostname}" ] || [ "${hostname}" = "*" ]; then
        local clientlist=$(${NVRAM} get custom_clientlist 2>/dev/null)
        if [ -n "${clientlist}" ]; then
            # Parse custom_clientlist entries
            hostname=$(echo "${clientlist}" | tr '<' '\n' | grep -i "${mac}" | cut -d'>' -f1 | head -n1)
        fi
    fi
    
    # Fallback to networkmap data
    if [ -z "${hostname}" ] || [ "${hostname}" = "*" ]; then
        if [ -f /var/lib/misc/networkmap.log ]; then
            hostname=$(grep -i "${mac}" /var/lib/misc/networkmap.log 2>/dev/null | awk '{print $1}' | head -n1)
        fi
    fi
    
    # Last resort: use MAC address as identifier
    if [ -z "${hostname}" ] || [ "${hostname}" = "*" ]; then
        hostname="${mac}"
    fi
    
    echo "${hostname}"
}

################################################################################
# WIRELESS CLIENT ENUMERATION
################################################################################

# Get wireless clients for a specific interface
get_wireless_clients() {
    local iface="$1"
    
    # Use wl to get associated stations - extract MAC addresses
    ${WL} -i "${iface}" assoclist 2>/dev/null | awk '/assoclist/ {print $2}'
}

# Get detailed wireless client information
get_wireless_client_details() {
    local iface="$1"
    local mac="$2"
    local ip=""
    local hostname=""
    local uptime="0"
    local tx_bytes="0"
    local rx_bytes="0"
    local tx_rate="0"
    local rx_rate="0"
    local signal="0"
    local bandwidth=""
    
    # Get IP from MAC address
    ip=$(get_ip_from_mac "${mac}")
    
    # Get hostname
    hostname=$(get_hostname "${mac}" "${ip}")
    
    # Get wireless statistics using wl sta_info
    if sta_info=$(${WL} -i "${iface}" sta_info "${mac}" 2>/dev/null); then
        # Parse uptime (in seconds)
        uptime=$(echo "${sta_info}" | grep 'in network' | awk '{for(i=1;i<=NF;i++){if($i=="network"){print $(i+1); exit}}}')
        [ -z "${uptime}" ] && uptime="0"
        
        # Parse signal strength
        signal=$(echo "${sta_info}" | grep 'RSSI:' | head -n1 | awk '{print $2}')
        [ -z "${signal}" ] && signal="0"
        
        # Parse rates (in Kbps, convert to Mbps)
        tx_rate=$(echo "${sta_info}" | grep 'rate of last tx pkt:' | awk '{print $6}')
        rx_rate=$(echo "${sta_info}" | grep 'rate of last rx pkt:' | awk '{print $6}')
        [ -z "${tx_rate}" ] && tx_rate="0"
        [ -z "${rx_rate}" ] && rx_rate="0"
        
        # Parse bandwidth/channel width
        bandwidth=$(echo "${sta_info}" | grep 'chanspec:' | head -n1 | awk '{for(i=1;i<=NF;i++){if($i=="chanspec:"){for(j=i+1;j<=NF;j++){if($j ~ /\)$/){print $(i+1); exit} else {printf "%s ", $(i+1); i++}}}}}')
        [ -z "${bandwidth}" ] && bandwidth="Unknown"
    fi
    
    # Get traffic statistics from /proc/net/nf_conntrack (approximation)
    if [ "${ip}" != "Unknown" ] && [ -f /proc/net/nf_conntrack ]; then
        tx_bytes=$(grep "${ip}" /proc/net/nf_conntrack 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
        rx_bytes=$(grep "${ip}" /proc/net/nf_conntrack 2>/dev/null | awk '{sum+=$2} END {print sum+0}')
        [ -z "${tx_bytes}" ] && tx_bytes="0"
        [ -z "${rx_bytes}" ] && rx_bytes="0"
    fi
    
    # Format output
    printf "  %-14s | %-15s | %-17s | %7s | %5s | %5s | %7.1f | %7.1f | %3s | %s\n" \
        "${hostname}" \
        "${ip}" \
        "${mac}" \
        "$(format_uptime ${uptime})" \
        "$(bytes_to_gb ${tx_bytes})" \
        "$(bytes_to_gb ${rx_bytes})" \
        "$(echo ${tx_rate} | awk '{printf "%.1f", $1/1000}')" \
        "$(echo ${rx_rate} | awk '{printf "%.1f", $1/1000}')" \
        "${signal}" \
        "${bandwidth}"
}

################################################################################
# LAN CLIENT ENUMERATION
################################################################################

# Get LAN/br0 clients (non-wireless)
get_lan_clients() {
    local wireless_macs=""
    local iface
    local temp_file="/tmp/lan_clients_$$.tmp"
    
    # Collect all wireless MACs to exclude them
    for iface in $(get_wireless_interfaces); do
        local clients=$(get_wireless_clients "${iface}")
        if [ -n "${clients}" ]; then
            wireless_macs="${wireless_macs} ${clients}"
        fi
    done
    
    # Normalize wireless MACs to lowercase
    wireless_macs=$(echo "${wireless_macs}" | tr 'A-F' 'a-f')
    
    # Get all ARP entries from /proc/net/arp and store in temp file
    if [ -f /proc/net/arp ]; then
        ${CAT} /proc/net/arp | awk 'NR>1 && $3!="0x0" && $4!="00:00:00:00:00:00" {print $1, $4}' > "${temp_file}"
    else
        # Fallback to arp command
        ${ARP} -n 2>/dev/null | awk 'NR>1 && $1!="?" {print $1, $3}' > "${temp_file}"
    fi
    
    # Process ARP entries
    while read ip mac; do
        # Skip empty lines
        [ -z "${mac}" ] || [ -z "${ip}" ] && continue
        [ "${ip}" = "IP" ] && continue
        
        # Filter out non-local IP addresses
        if ! is_local_ip "${ip}"; then
            continue
        fi
        
        # Normalize MAC to lowercase
        local mac_normalized=$(echo "${mac}" | tr 'A-F' 'a-f')
        
        # Skip if MAC is in wireless list
        local is_wireless=0
        for wmac in ${wireless_macs}; do
            if [ "${mac_normalized}" = "${wmac}" ]; then
                is_wireless=1
                break
            fi
        done
        
        if [ ${is_wireless} -eq 0 ]; then
            local hostname=$(get_hostname "${mac}" "${ip}")
            printf "  %-14s | %-15s | %s\n" "${hostname}" "${ip}" "${mac}"
        fi
    done < "${temp_file}" | sort -u
    
    # Clean up temp file
    rm -f "${temp_file}"
}

################################################################################
# MAIN DISPLAY ROUTINE
################################################################################

display_network_clients() {
    local iface
    local info_str
    local iface_type
    local band
    local guest_ssid
    local client_count
    
    echo ""
    echo "================================================================================"
    echo "  ASUS GT-AX6000 Network Client Monitor"
    echo "  Asus-Merlin Firmware 3006.102.6"
    echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "================================================================================"
    echo ""
    
    # Process each wireless interface
    for iface in $(get_wireless_interfaces); do
        info_str=$(get_interface_info "${iface}")
        iface_type=$(echo "${info_str}" | cut -d'|' -f1)
        band=$(echo "${info_str}" | cut -d'|' -f2)
        guest_ssid=$(echo "${info_str}" | cut -d'|' -f3)
        
        # Skip unknown interfaces
        [ "${iface_type}" = "unknown" ] && continue
        
        # Get clients for this interface
        client_count=0
        client_list=$(get_wireless_clients "${iface}")
        
        if [ -n "${client_list}" ]; then
            client_count=$(echo "${client_list}" | wc -l)
        fi
        
        # Display header based on interface type
        if [ "${iface_type}" = "guest" ]; then
            echo " Guest Wi-Fi: ${guest_ssid} - IFace: ${iface}"
        elif [ "${iface_type}" = "main" ]; then
            echo " Local ${band} - IFace: ${iface}"
        fi
        
        # Display column headers for wireless
        if [ "${iface_type}" = "main" ] || [ "${iface_type}" = "guest" ]; then
            printf "  %-14s | %-15s | %-17s | %7s | %5s | %5s | %7s | %7s | %3s | %s\n" \
                "Name" "IP" "MAC" "Uptime" "TX GB" "RX GB" "TX Mbps" "RX Mbps" "Sig" "Band"
            
            # Display clients
            if [ -n "${client_list}" ]; then
                for mac in ${client_list}; do
                    get_wireless_client_details "${iface}" "${mac}"
                done
            else
                echo "  No clients connected"
            fi
            echo ""
        fi
    done
    
    # Display LAN/br0 clients
    echo " Local LAN/Non-VLAN AiMesh - IFace: br0"
    printf "  %-14s | %-15s | %s\n" "Name" "IP" "MAC"
    get_lan_clients
    echo ""
    echo "================================================================================"
}

################################################################################
# ENTRY POINT
################################################################################

# Execute main routine
display_network_clients

exit 0
