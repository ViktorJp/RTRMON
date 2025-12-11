#!/bin/sh
################################################################################
# Asus-Merlin Network Client Monitor
# Compatible with multiple Asus router models running Asus-Merlin Firmware
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

# Radio configuration variables
IFNAME_24=""
IFNAME_5=""
IFNAME_5_2=""
IFNAME_6=""
IFNAME_6_2=""

################################################################################
# ROUTER MODEL DETECTION AND INTERFACE MAPPING
################################################################################

# Detect router model and configure interface mappings
detect_router_model() {
    local router_model=$(${NVRAM} get productid 2>/dev/null)
    [ -z "${router_model}" ] && router_model=$(${NVRAM} get model 2>/dev/null)
    
    echo "Detected Router Model: ${router_model}" >&2
    
    # Determine radio configuration based on router model
    case "${router_model}" in
        # Four-band routers: 5GHz, 5GHz, 6GHz, 2.4GHz (wl0=5, wl1=5, wl2=6, wl3=2.4)
        GT-AXE16000|GT-BE98)
            IFNAME_5=$(${NVRAM} get wl0_ifname 2>/dev/null)
            IFNAME_5_2=$(${NVRAM} get wl1_ifname 2>/dev/null)
            IFNAME_6=$(${NVRAM} get wl2_ifname 2>/dev/null)
            IFNAME_24=$(${NVRAM} get wl3_ifname 2>/dev/null)
            ;;
        
        # Four-band routers: 5GHz, 6GHz, 6GHz, 2.4GHz (wl0=5, wl1=6, wl2=6, wl3=2.4)
        GT-BE98_Pro)
            IFNAME_5=$(${NVRAM} get wl0_ifname 2>/dev/null)
            IFNAME_6=$(${NVRAM} get wl1_ifname 2>/dev/null)
            IFNAME_6_2=$(${NVRAM} get wl2_ifname 2>/dev/null)
            IFNAME_24=$(${NVRAM} get wl3_ifname 2>/dev/null)
            ;;
        
        # Three-band routers: 2.4GHz, 5GHz, 6GHz (wl0=2.4, wl1=5, wl2=6)
        GT-AXE11000|ZenWiFi_ET8|RT-BE96U|RT-BE92U)
            IFNAME_24=$(${NVRAM} get wl0_ifname 2>/dev/null)
            IFNAME_5=$(${NVRAM} get wl1_ifname 2>/dev/null)
            IFNAME_6=$(${NVRAM} get wl2_ifname 2>/dev/null)
            ;;
        
        # Three-band routers: 2.4GHz, 5GHz, 5GHz (wl0=2.4, wl1=5, wl2=5)
        GT-AX11000_Pro|GT-AX11000|ZenWiFi_Pro_XT12|ZenWiFi_XT8)
            IFNAME_24=$(${NVRAM} get wl0_ifname 2>/dev/null)
            IFNAME_5=$(${NVRAM} get wl1_ifname 2>/dev/null)
            IFNAME_5_2=$(${NVRAM} get wl2_ifname 2>/dev/null)
            ;;
        
        # Default two-band routers: 2.4GHz, 5GHz (wl0=2.4, wl1=5)
        *)
            IFNAME_24=$(${NVRAM} get wl0_ifname 2>/dev/null)
            IFNAME_5=$(${NVRAM} get wl1_ifname 2>/dev/null)
            ;;
    esac
    
    # Log detected interfaces
    echo "Interface Mapping:" >&2
    [ -n "${IFNAME_24}" ] && echo "  2.4GHz: ${IFNAME_24}" >&2
    [ -n "${IFNAME_5}" ] && echo "  5.0GHz: ${IFNAME_5}" >&2
    [ -n "${IFNAME_5_2}" ] && echo "  5.0GHz-2: ${IFNAME_5_2}" >&2
    [ -n "${IFNAME_6}" ] && echo "  6.0GHz: ${IFNAME_6}" >&2
    [ -n "${IFNAME_6_2}" ] && echo "  6.0GHz-2: ${IFNAME_6_2}" >&2
}

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
        169.254.*) return 0 ;;
        127.*) return 0 ;;
        *) return 1 ;;
    esac
}

# Get all active wireless interfaces
get_wireless_interfaces() {
    ${IFCONFIG} | grep '^eth[0-9]\|^wl[0-9]' | awk '{print $1}' | while read iface; do
        if ${WL} -i "${iface}" status >/dev/null 2>&1; then
            echo "${iface}"
        fi
    done | sort -u
}

# Get band name from interface name based on detected configuration
get_band_from_interface() {
    local iface="$1"
    
    if [ "${iface}" = "${IFNAME_24}" ]; then
        echo "2.4GHz"
    elif [ "${iface}" = "${IFNAME_5}" ]; then
        echo "5.0GHz"
    elif [ -n "${IFNAME_5_2}" ] && [ "${iface}" = "${IFNAME_5_2}" ]; then
        echo "5.0GHz-2"
    elif [ -n "${IFNAME_6}" ] && [ "${iface}" = "${IFNAME_6}" ]; then
        echo "6.0GHz"
    elif [ -n "${IFNAME_6_2}" ] && [ "${iface}" = "${IFNAME_6_2}" ]; then
        echo "6.0GHz-2"
    else
        echo ""
    fi
}

# Get interface type and band information
get_interface_info() {
    local iface="$1"
    local band=""
    local type=""
    local guest_ssid=""
    
    echo "${iface}" | grep '\.' >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        local base_iface=$(echo "${iface}" | cut -d'.' -f1)
        local guest_num=$(echo "${iface}" | cut -d'.' -f2)
        
        band=$(get_band_from_interface "${base_iface}")
        
        local wl_unit=""
        
        echo "${base_iface}" | grep '^wl[0-9]$' >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            wl_unit=$(echo "${base_iface}" | grep -o '[0-9]')
        else
            local unit
            for unit in 0 1 2 3; do
                local unit_iface=$(${NVRAM} get wl${unit}_ifname 2>/dev/null)
                if [ "${unit_iface}" = "${base_iface}" ]; then
                    wl_unit="${unit}"
                    break
                fi
            done
        fi
        
        if [ -n "${wl_unit}" ]; then
            guest_ssid=$(${NVRAM} get wl${wl_unit}.${guest_num}_ssid 2>/dev/null)
            if [ -z "${guest_ssid}" ] || [ "${guest_ssid}" = " " ]; then
                guest_ssid="Guest Network"
            fi
        else
            guest_ssid="Guest Network"
        fi
        
        type="guest"
        echo "${type}|${band}|${guest_ssid}"
        return
    fi
    
    band=$(get_band_from_interface "${iface}")
    
    if [ -n "${band}" ]; then
        type="main"
    elif [ "${iface}" = "br0" ]; then
        type="lan"
    else
        type="unknown"
    fi
    
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
    
    if [ -f /proc/net/arp ]; then
        ip=$(grep -i "${mac}" /proc/net/arp 2>/dev/null | awk '{print $1}' | head -n1)
    fi
    
    if [ -z "${ip}" ]; then
        ip=$(${ARP} -n 2>/dev/null | grep -i "${mac}" | awk '{print $1}' | head -n1)
    fi
    
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
    local mac_normalized=""
    mac_normalized=$(echo "${mac}" | tr 'A-F' 'a-f')
    
    if [ -f /var/lib/misc/dnsmasq.leases ]; then
        hostname=$(awk -v mac="${mac_normalized}" '{if (tolower($2) == mac) {print $4; exit}}' /var/lib/misc/dnsmasq.leases 2>/dev/null)
    fi
    
    if [ -z "${hostname}" ] || [ "${hostname}" = "*" ]; then
        if [ -f /var/lib/misc/dnsmasq.leases ] && [ "${ip}" != "Unknown" ]; then
            hostname=$(awk -v ip="${ip}" '{if ($3 == ip) {print $4; exit}}' /var/lib/misc/dnsmasq.leases 2>/dev/null)
        fi
    fi
    
    if [ -z "${hostname}" ] || [ "${hostname}" = "*" ]; then
        local clientlist=$(${NVRAM} get custom_clientlist 2>/dev/null)
        if [ -n "${clientlist}" ]; then
            hostname=$(echo "${clientlist}" | tr '<' '\n' | grep -i "${mac}" | cut -d'>' -f1 | head -n1)
        fi
    fi
    
    if [ -z "${hostname}" ] || [ "${hostname}" = "*" ]; then
        if [ -f /var/lib/misc/networkmap.log ]; then
            hostname=$(grep -i "${mac}" /var/lib/misc/networkmap.log 2>/dev/null | awk '{print $1}' | head -n1)
        fi
    fi
    
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
    
    ip=$(get_ip_from_mac "${mac}")
    hostname=$(get_hostname "${mac}" "${ip}")
    
    sta_info=$(${WL} -i "${iface}" sta_info "${mac}" 2>/dev/null)
    if [ -n "${sta_info}" ]; then
        uptime=$(echo "${sta_info}" | grep 'in network' | awk '{for(i=1;i<=NF;i++){if($i=="network"){print $(i+1); exit}}}')
        [ -z "${uptime}" ] && uptime="0"
        
        signal=$(echo "${sta_info}" | grep 'RSSI:' | head -n1 | awk '{print $2}')
        [ -z "${signal}" ] && signal="0"
        
        tx_rate=$(echo "${sta_info}" | grep 'rate of last tx pkt:' | awk '{print $6}')
        rx_rate=$(echo "${sta_info}" | grep 'rate of last rx pkt:' | awk '{print $6}')
        [ -z "${tx_rate}" ] && tx_rate="0"
        [ -z "${rx_rate}" ] && rx_rate="0"
        
        # Get TX/RX bytes from wl sta_info
        tx_bytes=$(echo "${sta_info}" | awk '/tx total bytes:/ {print $4}')
        rx_bytes=$(echo "${sta_info}" | awk '/rx data bytes:/ {print $4}')
        [ -z "${tx_bytes}" ] && tx_bytes="0"
        [ -z "${rx_bytes}" ] && rx_bytes="0"
        
        local bw_mhz=""
        local nss=""
        
        local link_bw_line=$(echo "${sta_info}" | grep -i 'link bandwidth')
        if [ -n "${link_bw_line}" ]; then
            bw_mhz=$(echo "${link_bw_line}" | grep -o '[0-9]\{2,3\}' | head -n1)
        fi
        
        if [ -z "${bw_mhz}" ]; then
            local chanspec_line=$(echo "${sta_info}" | grep 'chanspec')
            if [ -n "${chanspec_line}" ]; then
                # Extract bandwidth from chanspec (format: "100/160" where 160 is the bandwidth)
                # Check if there's a / in the chanspec line
                if echo "${chanspec_line}" | grep '/' >/dev/null 2>&1; then
                    bw_mhz=$(echo "${chanspec_line}" | sed 's/.*\/\([0-9]\{2,3\}\).*/\1/')
                else
                    bw_mhz=$(echo "${chanspec_line}" | grep -o '[0-9]\{2,3\}' | tail -n1)
                fi
            fi
        fi
        
        if [ -z "${bw_mhz}" ]; then
            local omi_line=$(echo "${sta_info}" | grep 'OMI')
            if [ -n "${omi_line}" ]; then
                bw_mhz=$(echo "${omi_line}" | grep -o '[0-9]\{2,3\}[Mm][Hh][Zz]' | grep -o '[0-9]\{2,3\}')
            fi
        fi
        
        local omi_line=$(echo "${sta_info}" | grep 'OMI')
        if [ -n "${omi_line}" ]; then
            nss=$(echo "${omi_line}" | grep -o 'tx=[0-9]ss' | grep -o '[0-9]' | head -n1)
        fi
        
        if [ -z "${nss}" ]; then
            local nrate_line=$(echo "${sta_info}" | grep 'tx nrate\|rx nrate' | head -n1)
            if [ -n "${nrate_line}" ]; then
                nss=$(echo "${nrate_line}" | grep -o 'Nss [0-9]' | grep -o '[0-9]')
            fi
        fi
        
        if [ -z "${nss}" ]; then
            local vht_line=$(echo "${sta_info}" | grep 'VHT SET' -A 1 | tail -n1)
            if [ -n "${vht_line}" ]; then
                nss=$(echo "${vht_line}" | grep -o '[0-9]x[0-9]' | head -n1 | cut -d'x' -f1)
            fi
        fi
        
        if [ -n "${bw_mhz}" ]; then
            if [ -n "${nss}" ]; then
                bandwidth="${nss}x${nss}:${bw_mhz}"
            else
                bandwidth="${bw_mhz}"
            fi
        else
            bandwidth="Unknown"
        fi
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

get_lan_clients() {
    local wireless_macs=""
    local iface
    local temp_file="/tmp/lan_clients_$$.tmp"
    
    for iface in $(get_wireless_interfaces); do
        local clients=$(get_wireless_clients "${iface}")
        if [ -n "${clients}" ]; then
            wireless_macs="${wireless_macs} ${clients}"
        fi
    done
    
    wireless_macs=$(echo "${wireless_macs}" | tr 'A-F' 'a-f')
    
    if [ -f /proc/net/arp ]; then
        ${CAT} /proc/net/arp | awk 'NR>1 && $3!="0x0" && $4!="00:00:00:00:00:00" {print $1, $4}' > "${temp_file}"
    else
        ${ARP} -n 2>/dev/null | awk 'NR>1 && $1!="?" {print $1, $3}' > "${temp_file}"
    fi
    
    while read ip mac; do
        [ -z "${mac}" ] || [ -z "${ip}" ] && continue
        [ "${ip}" = "IP" ] && continue
        
        if ! is_local_ip "${ip}"; then
            continue
        fi
        
        local mac_normalized=$(echo "${mac}" | tr 'A-F' 'a-f')
        
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
    
    rm -f "${temp_file}"
}

get_primary_subnet() {
    local br0_ip=$(${IFCONFIG} br0 2>/dev/null | grep 'inet addr:' | awk '{print $2}' | cut -d':' -f2)
    if [ -z "${br0_ip}" ]; then
        br0_ip=$(${IFCONFIG} br0 2>/dev/null | awk '/inet / {print $2}')
    fi
    
    if [ -n "${br0_ip}" ]; then
        echo "${br0_ip}" | awk -F'.' '{print $1"."$2"."$3".0/24"}'
    fi
}

get_unique_subnets() {
    local temp_file="/tmp/subnets_$$.tmp"
    local primary_subnet=$(get_primary_subnet)
    
    if [ -f /proc/net/arp ]; then
        ${CAT} /proc/net/arp | awk 'NR>1 && $3!="0x0" && $1!="0.0.0.0" {print $1}' > "${temp_file}"
    else
        ${ARP} -n 2>/dev/null | awk 'NR>1 && $1!="?" {print $1}' > "${temp_file}"
    fi
    
    while read ip; do
        if is_local_ip "${ip}"; then
            local subnet=$(echo "${ip}" | awk -F'.' '{print $1"."$2"."$3".0/24"}')
            if [ "${subnet}" != "${primary_subnet}" ]; then
                echo "${subnet}"
            fi
        fi
    done < "${temp_file}" | sort -u
    
    rm -f "${temp_file}"
}

get_vlan_interface() {
    local subnet="$1"
    local subnet_prefix=$(echo "${subnet}" | cut -d'/' -f1 | sed 's/\.0$//')
    
    ${IFCONFIG} | grep "^br[0-9]\|^vlan[0-9]" | awk '{print $1}' | while read iface; do
        local iface_ip=$(${IFCONFIG} "${iface}" 2>/dev/null | grep 'inet addr:' | awk '{print $2}' | cut -d':' -f2)
        if [ -z "${iface_ip}" ]; then
            iface_ip=$(${IFCONFIG} "${iface}" 2>/dev/null | awk '/inet / {print $2}')
        fi
        
        if [ -n "${iface_ip}" ]; then
            local iface_subnet=$(echo "${iface_ip}" | awk -F'.' '{print $1"."$2"."$3}')
            if [ "${iface_subnet}" = "${subnet_prefix}" ]; then
                echo "${iface}"
                return
            fi
        fi
    done
}

get_vlan_clients() {
    local subnet="$1"
    local wireless_macs="$2"
    local subnet_prefix=$(echo "${subnet}" | cut -d'/' -f1 | sed 's/\.0$//')
    local temp_file="/tmp/vlan_clients_$$.tmp"
    
    if [ -f /proc/net/arp ]; then
        ${CAT} /proc/net/arp | awk -v prefix="${subnet_prefix}" 'NR>1 && $3!="0x0" && $4!="00:00:00:00:00:00" && $1 ~ "^"prefix {print $1, $4}' > "${temp_file}"
    else
        ${ARP} -n 2>/dev/null | awk -v prefix="${subnet_prefix}" 'NR>1 && $1!="?" && $1 ~ "^"prefix {print $1, $3}' > "${temp_file}"
    fi
    
    while read ip mac; do
        [ -z "${mac}" ] || [ -z "${ip}" ] && continue
        
        local mac_normalized=$(echo "${mac}" | tr 'A-F' 'a-f')
        
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
    done < "${temp_file}"
    
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
    local wireless_macs=""
    
    echo ""
    echo "================================================================================"
    echo "  ASUS Network Client Monitor"
    echo "  Asus-Merlin Firmware"
    echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "================================================================================"
    echo ""
    
    for iface in $(get_wireless_interfaces); do
        info_str=$(get_interface_info "${iface}")
        iface_type=$(echo "${info_str}" | cut -d'|' -f1)
        band=$(echo "${info_str}" | cut -d'|' -f2)
        guest_ssid=$(echo "${info_str}" | cut -d'|' -f3)
        
        [ "${iface_type}" = "unknown" ] && continue
        
        client_count=0
        client_list=$(get_wireless_clients "${iface}")
        
        if [ -n "${client_list}" ]; then
            client_count=$(echo "${client_list}" | wc -l)
        fi
        
        if [ "${iface_type}" = "guest" ]; then
            echo " Guest Wi-Fi: ${guest_ssid} - IFace: ${iface}"
        elif [ "${iface_type}" = "main" ]; then
            echo " Local ${band} - IFace: ${iface}"
        fi
        
        if [ "${iface_type}" = "main" ] || [ "${iface_type}" = "guest" ]; then
            printf "  %-14s | %-15s | %-17s | %7s | %5s | %5s | %7s | %7s | %3s | %s\n" \
                "Name" "IP" "MAC" "Uptime" "TX GB" "RX GB" "TX Mbps" "RX Mbps" "Sig" "Band"
            
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
    
    for iface in $(get_wireless_interfaces); do
        local clients=$(get_wireless_clients "${iface}")
        if [ -n "${clients}" ]; then
            wireless_macs="${wireless_macs} ${clients}"
        fi
    done
    wireless_macs=$(echo "${wireless_macs}" | tr 'A-F' 'a-f')
    
    local primary_subnet=$(get_primary_subnet)
    local vlan_subnets=$(get_unique_subnets)
    local has_vlans=0
    
    if [ -n "${vlan_subnets}" ]; then
        has_vlans=1
    fi
    
    if [ ${has_vlans} -eq 1 ]; then
        echo " Local VLAN/AiMesh VLAN"
        echo ""
        
        for subnet in ${vlan_subnets}; do
            local subnet_prefix=$(echo "${subnet}" | cut -d'/' -f1 | sed 's/\.0$//')
            local vlan_iface=$(get_vlan_interface "${subnet}")
            
            if [ -n "${vlan_iface}" ]; then
                echo "  VLAN ${subnet} - IFace: ${vlan_iface}"
            else
                echo "  VLAN ${subnet}"
            fi
            
            printf "  %-14s | %-15s | %s\n" "Name" "IP" "MAC"
            
            local vlan_clients=$(get_vlan_clients "${subnet}" "${wireless_macs}")
            
            if [ -n "${vlan_clients}" ]; then
                echo "${vlan_clients}"
            else
                echo "  No wired clients found"
            fi
            echo ""
        done
    fi
    
    echo " Local LAN/Non-VLAN AiMesh - Subnet: ${primary_subnet} - IFace: br0"
    printf "  %-14s | %-15s | %s\n" "Name" "IP" "MAC"
    
    if [ -n "${primary_subnet}" ]; then
        local primary_clients=$(get_vlan_clients "${primary_subnet}" "${wireless_macs}")
        if [ -n "${primary_clients}" ]; then
            echo "${primary_clients}"
        else
            echo "  No wired clients found"
        fi
    else
        get_lan_clients
    fi
    
    echo ""
    echo "================================================================================"
}

################################################################################
# ENTRY POINT
################################################################################

detect_router_model

display_network_clients

exit 0
