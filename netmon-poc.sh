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

# Temporary files for client tracking and deduplication
PROCESSED_CLIENTS="/tmp/netmon_processed_clients_$$.txt"
PROCESSED_VLAN_CLIENTS="/tmp/netmon_processed_vlan_clients_$$.txt"

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
        GT-BE98_PRO)
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
        GT-AX11000_PRO|GT-AX11000|ZenWiFi_Pro_XT12|ZenWiFi_XT8)
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
# MLO/MLD AWARENESS FUNCTIONS
################################################################################

# Read all DHCP lease files including merged leases for MLO/MLD support
read_all_dhcp_leases() {
    # Include the merged lease file if it exists (for MLO/MLD clients)
    local lease_files="/var/lib/misc/dnsmasq-*.leases /var/lib/misc/dnsmasq.leases"
    if [ -f "/tmp/dnsmasq-merged.leases" ]; then
        lease_files="${lease_files} /tmp/dnsmasq-merged.leases"
    fi
    local all_leases=""
    all_leases=$(${CAT} ${lease_files} 2>/dev/null)
    echo "${all_leases}"
}

# Unified MLD MAC retrieval logic: given the current dhcpleases and association MAC (in lowercase),
# determine the lookup MAC (which may be the MLD MAC if present).
# For WiFi 7 / MLO clients the MAC used by 'wl assoclist' may NOT be the same MAC
# that appears in ARP/DHCP. This function finds the correct MAC to use for lookups.
get_lookup_mac() {
    local maclower="$1"
    local leases="$2"
    local lookup_mac="${maclower}"
    local mld_line=""
    local field_count=""
    local mld_mac=""

    mld_line=$(echo "${leases}" | grep -i "${maclower}" | head -n1)
    if [ -n "${mld_line}" ]; then
        field_count=$(echo "${mld_line}" | awk '{print NF; exit}')
        if [ "${field_count}" -ge 5 ]; then
            mld_mac=$(echo "${mld_line}" | awk '{print $5; exit}')
            if [ -n "${mld_mac}" ] && [ "${mld_mac}" != "*" ]; then
                lookup_mac=$(echo "${mld_mac}" | awk '{print tolower($0)}')
            fi
        fi
    fi
    echo "${lookup_mac}"
}

################################################################################
# UTILITY FUNCTIONS
################################################################################

# Get the bridge name that an interface is enslaved to
get_bridge_for_interface() {
    local iface="$1"
    local bridge_name=""

    for br in $(ls /sys/class/net 2>/dev/null | grep '^br'); do
        if [ -d "/sys/class/net/${br}/brif/${iface}" ]; then
            bridge_name="${br}"
            break
        fi
    done

    echo "${bridge_name}"
}

# Get list of VLAN/AiMesh bridge interfaces from apg_ifnames
get_vlan_bridges() {
    local apg_ifnames=$(${NVRAM} get apg_ifnames 2>/dev/null)
    if [ -n "${apg_ifnames}" ]; then
        echo "${apg_ifnames}"
    fi
}

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

# Get all active wireless interfaces including VIFs (guest networks)
get_wireless_interfaces() {
    local temp_file="/tmp/wireless_ifaces_$$.tmp"

    # Get main wireless interfaces
    ${IFCONFIG} | grep '^eth[0-9]\|^wl[0-9]' | awk '{print $1}' | while read iface; do
        if ${WL} -i "${iface}" status >/dev/null 2>&1; then
            echo "${iface}"
        fi
    done > "${temp_file}"

    # Get VIFs (virtual interfaces for guest networks) from nvram
    for wl_unit in 0 1 2 3; do
        local vifs=$(${NVRAM} get wl${wl_unit}_vifs 2>/dev/null)
        if [ -n "${vifs}" ]; then
            for vif in ${vifs}; do
                # Check if VIF has an SSID configured (indicates it's active)
                local vif_ssid=$(${NVRAM} get ${vif}_ssid 2>/dev/null)
                if [ -n "${vif_ssid}" ] && [ "${vif_ssid}" != " " ]; then
                    # Verify the interface exists and is up
                    if ${IFCONFIG} "${vif}" >/dev/null 2>&1; then
                        echo "${vif}"
                    fi
                fi
            done
        fi
    done >> "${temp_file}"

    # Sort and deduplicate
    sort -u "${temp_file}"
    rm -f "${temp_file}"
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

# Get SSID for a main wireless interface
get_ssid_for_interface() {
    local iface="$1"
    local ssid=""
    
    # Find the wl unit number for this interface
    for wl_unit in 0 1 2 3; do
        local unit_iface=$(${NVRAM} get wl${wl_unit}_ifname 2>/dev/null)
        if [ "${unit_iface}" = "${iface}" ]; then
            ssid=$(${NVRAM} get wl${wl_unit}_ssid 2>/dev/null)
            break
        fi
    done
    
    echo "${ssid}"
}

# Get interface type and band information
# Uses bridge membership to accurately determine guest vs local Wi-Fi
get_interface_info() {
    local iface="$1"
    local band=""
    local type=""
    local guest_ssid=""
    local bridge_name=""

    # Check if this is a guest/VIF interface by looking for it in bridge interfaces
    # Find which bridge this interface is enslaved to
    for br in $(ls /sys/class/net 2>/dev/null | grep '^br'); do
        if [ -d "/sys/class/net/${br}/brif/${iface}" ]; then
            bridge_name="${br}"
            break
        fi
    done

    # Determine if it's a VIF (virtual interface) by checking nvram wlX_vifs
    local is_vif=0
    for wl_unit in 0 1 2 3; do
        local vifs=$(${NVRAM} get wl${wl_unit}_vifs 2>/dev/null)
        if [ -n "${vifs}" ]; then
            for vif in ${vifs}; do
                if [ "${vif}" = "${iface}" ]; then
                    is_vif=1
                    # Get the base interface to determine band
                    local base_iface=$(${NVRAM} get wl${wl_unit}_ifname 2>/dev/null)
                    band=$(get_band_from_interface "${base_iface}")

                    # Get SSID for this VIF
                    guest_ssid=$(${NVRAM} get ${iface}_ssid 2>/dev/null)
                    if [ -z "${guest_ssid}" ] || [ "${guest_ssid}" = " " ]; then
                        guest_ssid="Guest Network"
                    fi
                    break 2
                fi
            done
        fi
    done

    # Determine type based on bridge membership and VIF status
    if [ ${is_vif} -eq 1 ]; then
        # It's a VIF - check which bridge it's on
        if [ -n "${bridge_name}" ] && [ "${bridge_name}" != "br0" ]; then
            type="guest"
        else
            # VIF on br0 is treated as local Wi-Fi
            type="main"
        fi
        echo "${type}|${band}|${guest_ssid}"
        return
    fi

    # Not a VIF - determine band for main interfaces
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

# Get IP address for a MAC from ARP table with MLO/MLD awareness
# Prefers IPs with REACHABLE or DELAY neighbor state for more reliable mapping
get_ip_from_mac() {
    local mac="$1"
    local dhcp_leases="$2"
    local ip=""
    local mac_normalized=""
    mac_normalized=$(echo "${mac}" | tr 'A-F' 'a-f')

    # Get the lookup MAC (may be MLD MAC for WiFi 7 clients)
    local lookup_mac=$(get_lookup_mac "${mac_normalized}" "${dhcp_leases}")

    # Try to find all IPs for this MAC in ARP table
    local ips=""
    if [ -f /proc/net/arp ]; then
        ips=$(awk -v mac="${mac_normalized}" 'BEGIN{IGNORECASE=1} tolower($4)==mac {print $1}' /proc/net/arp 2>/dev/null)
    fi

    # If we have multiple IPs, prefer one that is REACHABLE or DELAY
    if [ -n "${ips}" ]; then
        for candidate_ip in ${ips}; do
            local arp_status=$(ip neigh show | grep -w "${candidate_ip}" | awk '{print $NF}' 2>/dev/null)
            if [ -n "${arp_status}" ] && { [ "${arp_status}" = "REACHABLE" ] || [ "${arp_status}" = "DELAY" ]; }; then
                ip="${candidate_ip}"
                break
            fi
        done
        # If no REACHABLE/DELAY found, use the last IP as fallback
        [ -z "${ip}" ] && ip=$(echo "${ips}" | tail -n 1)
    fi

    # Try DHCP leases using lookup_mac if no IP found
    if [ -z "${ip}" ]; then
        if [ -f /var/lib/misc/dnsmasq.leases ]; then
            ip=$(awk -v mac="${lookup_mac}" '{if (tolower($2) == mac) {print $3; exit}}' /var/lib/misc/dnsmasq.leases 2>/dev/null)
        fi
    fi

    # Fallback to arp command
    if [ -z "${ip}" ]; then
        ip=$(${ARP} -n 2>/dev/null | grep -i "${mac}" | awk '{print $1}' | head -n1)
    fi

    if [ -z "${ip}" ] || [ "${ip}" = "?" ]; then
        echo "Unknown"
    else
        echo "${ip}"
    fi
}

# Get hostname from dnsmasq leases and nvram - MAC-specific with MLO/MLD support
get_hostname() {
    local mac="$1"
    local ip="$2"
    local dhcp_leases="$3"
    local hostname=""
    local mac_normalized=""
    mac_normalized=$(echo "${mac}" | tr 'A-F' 'a-f')

    # Get the lookup MAC (may be MLD MAC for WiFi 7 clients)
    local lookup_mac=$(get_lookup_mac "${mac_normalized}" "${dhcp_leases}")

    # Try custom_clientlist first
    local custom_clients=$(${NVRAM} get custom_clientlist 2>/dev/null)
    if [ -n "${custom_clients}" ]; then
        local mac_upper=$(echo "${mac}" | tr 'a-f' 'A-F')
        hostname=$(echo "${custom_clients}" | grep -o "<[^>]*>${mac_upper}" | sed 's/^<\([^>]*\)>.*/\1/' | head -n1)
    fi

    # Try dnsmasq leases using lookup_mac
    if [ -z "${hostname}" ] || [ "${hostname}" = " " ]; then
        hostname=$(echo "${dhcp_leases}" | grep -i "${lookup_mac}" | awk '{print $4}' | head -n1)
    fi

    # Try static DHCP reservations
    if [ -z "${hostname}" ] || [ "${hostname}" = " " ] || [ "${hostname}" = "*" ]; then
        local dhcp_staticlist=$(${NVRAM} get dhcp_staticlist 2>/dev/null)
        if [ -n "${dhcp_staticlist}" ]; then
            hostname=$(echo "${dhcp_staticlist}" | grep -i "${lookup_mac}" | cut -d'>' -f1 | sed 's/.*<//' | head -n1)
        fi
    fi

    # Fallback to reverse DNS lookup
    if [ -z "${hostname}" ] || [ "${hostname}" = " " ] || [ "${hostname}" = "*" ]; then
        if [ -n "${ip}" ] && [ "${ip}" != "Unknown" ]; then
            hostname=$(nslookup "${ip}" 2>/dev/null | grep 'name =' | awk '{print $4}' | sed 's/\.$//')
        fi
    fi

    # Final fallback
    if [ -z "${hostname}" ] || [ "${hostname}" = " " ] || [ "${hostname}" = "*" ]; then
        hostname="Unknown"
    fi

    echo "${hostname}"
}

get_wireless_clients() {
    local iface="$1"
    ${WL} -i "${iface}" assoclist 2>/dev/null | awk '{print $2}' | tr 'A-F' 'a-f'
}

get_wireless_client_details() {
    local iface="$1"
    local mac="$2"
    local dhcp_leases="$3"
    local mac_normalized=""
    local mac_upper=""
    local clientip=""
    local hostname=""
    local uptime=""
    local tx_bytes=""
    local rx_bytes=""
    local tx_rate=""
    local rx_rate=""
    local rssi=""
    local chanspec=""

    mac_normalized=$(echo "${mac}" | tr 'A-F' 'a-f')
    mac_upper=$(echo "${mac}" | tr 'a-f' 'A-F')

    # Get the lookup MAC for WiFi 7 / MLO clients
    local lookup_mac=$(get_lookup_mac "${mac_normalized}" "${dhcp_leases}")

    # For WiFi 7 / MLO clients the MAC used by wl (assoclist) may NOT be
    # the same MAC that appears in ARP/DHCP. Start with the assoc MAC
    # as canonical, then override if we find a better ARP match.
    local canonical_mac="${mac}"
    local canonlower="${mac_normalized}"
    local canonupper="${mac_upper}"

    # Get client statistics from wl
    local sta_info=$(${WL} -i "${iface}" sta_info "${mac}" 2>/dev/null)

    if [ -n "${sta_info}" ]; then
        local network_time=$(echo "${sta_info}" | awk '/in network/ {print $3}')
        if [ -n "${network_time}" ]; then
            uptime=$(format_uptime "${network_time}")
        else
            uptime="Unknown"
        fi

        tx_bytes=$(echo "${sta_info}" | awk '/tx total bytes:/ {print $4}')
        rx_bytes=$(echo "${sta_info}" | awk '/rx data bytes:/ {print $4}')
        tx_rate=$(echo "${sta_info}" | awk '/rate of last tx pkt:/ {print $6}')
        rx_rate=$(echo "${sta_info}" | awk '/rate of last rx pkt:/ {print $6}')
        rssi=$(echo "${sta_info}" | awk '/smoothed rssi:/ {print $3}')
        chanspec=$(echo "${sta_info}" | awk '/chanspec/ {print $2}')
    fi

    # Try to find IP for this MAC using MLO/MLD aware lookup
    # 1) Try direct match in ARP table - collect all IPs
    local ips=""
    if [ -f /proc/net/arp ]; then
        ips=$(awk -v mac="${mac_normalized}" 'BEGIN{IGNORECASE=1} tolower($4)==mac {print $1}' /proc/net/arp 2>/dev/null)

        # 2) If that fails, try a fuzzy match using the middle 4 bytes of the MAC
        if [ -z "${ips}" ]; then
            local mac_mid4=$(echo "${mac_normalized}" | awk -F: '{print $2":"$3":"$4":"$5}')
            if [ -n "${mac_mid4}" ]; then
                local arp_line=$(awk -v mid="${mac_mid4}" 'BEGIN{IGNORECASE=1} index(tolower($4), mid) > 0 {print; exit}' /proc/net/arp 2>/dev/null)
                if [ -n "${arp_line}" ]; then
                    clientip=$(echo "${arp_line}" | awk '{print $1}')
                    canonical_mac=$(echo "${arp_line}" | awk '{print $4}')
                    canonlower=$(echo "${canonical_mac}" | tr 'A-F' 'a-f')
                    canonupper=$(echo "${canonical_mac}" | tr 'a-f' 'A-F')
                fi
            fi
        fi

        # 3) If we had multiple IPs from direct match, prefer one that is REACHABLE/DELAY
        if [ -z "${clientip}" ] && [ -n "${ips}" ]; then
            for ip in ${ips}; do
                local arp_status=$(ip neigh show | grep -w "${ip}" | awk '{print $NF}' 2>/dev/null)
                if [ -z "${arp_status}" ] || { [ "${arp_status}" != "REACHABLE" ] && [ "${arp_status}" != "DELAY" ]; }; then
                    # Mark as stale if we have no signal strength
                    [ -z "${rssi}" ] && uptime="STALE"
                    continue
                else
                    clientip="${ip}"
                    break
                fi
            done
            # If no REACHABLE/DELAY found, use the last IP as fallback
            [ -z "${clientip}" ] && clientip=$(echo "${ips}" | tail -n 1)
        fi
    fi

    # 4) Final fallback using canonical MAC
    if [ -z "${clientip}" ]; then
        clientip=$(awk -v mac="${canonlower}" 'BEGIN{IGNORECASE=1} tolower($4)==mac {print $1}' /proc/net/arp 2>/dev/null | sort | uniq | tail -n 1)
    fi

    # If still no IP, try DHCP leases with lookup_mac
    if [ -z "${clientip}" ]; then
        clientip=$(echo "${dhcp_leases}" | grep -i "${lookup_mac}" | awk '{print $3}' | head -n1)
    fi

    # For isolated guest networks, client may not appear in main ARP table
    # Still display the client with "Unknown" IP if we have wireless stats
    if [ -z "${clientip}" ]; then
        if [ -n "${rssi}" ]; then
            # Client is actively connected via wireless, just no IP visible
            clientip="Unknown"
        else
            # No IP and no wireless stats - skip this client
            return
        fi
    fi

    # Check if this canonical MAC has already been processed
    # This prevents the same device from appearing in both Wi-Fi and LAN sections
    if [ -f "${PROCESSED_CLIENTS}" ]; then
        if grep -qi "^${canonupper}$" "${PROCESSED_CLIENTS}" 2>/dev/null; then
            return
        fi
    fi

    # Track this canonical MAC as processed
    echo "${canonupper}" >> "${PROCESSED_CLIENTS}"

    # Get hostname using MLO/MLD aware lookup
    hostname=$(get_hostname "${canonical_mac}" "${clientip}" "${dhcp_leases}")

    # Convert traffic values
    local tx_gb=$(bytes_to_gb "${tx_bytes:-0}")
    local rx_gb=$(bytes_to_gb "${rx_bytes:-0}")
    local tx_mbps=$(echo "${tx_rate:-0}" | awk '{printf "%.1f", $1/1000}')
    local rx_mbps=$(echo "${rx_rate:-0}" | awk '{printf "%.1f", $1/1000}')

    # Determine detailed band information (NSS and bandwidth)
    local bandwidth=""
    local bw_mhz=""
    local nss=""

    # Try to extract bandwidth from various fields in sta_info
    # Method 1: Check for "link bandwidth" line
    local link_bw_line=$(echo "${sta_info}" | grep -i 'link bandwidth')
    if [ -n "${link_bw_line}" ]; then
        bw_mhz=$(echo "${link_bw_line}" | grep -o '[0-9]\{2,3\}' | head -n1)
    fi

    # Method 2: Extract from chanspec if bandwidth not found
    if [ -z "${bw_mhz}" ] && [ -n "${chanspec}" ]; then
        local chanspec_line=$(echo "${sta_info}" | grep 'chanspec')
        if [ -n "${chanspec_line}" ]; then
            # Extract bandwidth from chanspec (format: "100/160" where 160 is the bandwidth)
            if echo "${chanspec_line}" | grep '/' >/dev/null 2>&1; then
                bw_mhz=$(echo "${chanspec_line}" | sed 's/.*\/\([0-9]\{2,3\}\).*/\1/')
            else
                bw_mhz=$(echo "${chanspec_line}" | grep -o '[0-9]\{2,3\}' | tail -n1)
            fi
        fi
    fi

    # Method 3: Try OMI line for bandwidth
    if [ -z "${bw_mhz}" ]; then
        local omi_line=$(echo "${sta_info}" | grep 'OMI')
        if [ -n "${omi_line}" ]; then
            bw_mhz=$(echo "${omi_line}" | grep -o '[0-9]\{2,3\}[Mm][Hh][Zz]' | grep -o '[0-9]\{2,3\}')
        fi
    fi

    # Extract NSS (Number of Spatial Streams)
    # Method 1: Check OMI line
    local omi_line=$(echo "${sta_info}" | grep 'OMI')
    if [ -n "${omi_line}" ]; then
        nss=$(echo "${omi_line}" | grep -o 'tx=[0-9]ss' | grep -o '[0-9]' | head -n1)
    fi

    # Method 2: Check nrate line if NSS not found
    if [ -z "${nss}" ]; then
        local nrate_line=$(echo "${sta_info}" | grep 'tx nrate\|rx nrate' | head -n1)
        if [ -n "${nrate_line}" ]; then
            nss=$(echo "${nrate_line}" | grep -o 'Nss [0-9]' | grep -o '[0-9]')
        fi
    fi

    # Method 3: Check VHT SET if NSS still not found
    if [ -z "${nss}" ]; then
        local vht_line=$(echo "${sta_info}" | grep 'VHT SET' -A 1 | tail -n1)
        if [ -n "${vht_line}" ]; then
            nss=$(echo "${vht_line}" | grep -o '[0-9]x[0-9]' | head -n1 | cut -d'x' -f1)
        fi
    fi

    # Format bandwidth display
    if [ -n "${bw_mhz}" ]; then
        if [ -n "${nss}" ]; then
            bandwidth="${nss}x${nss}:${bw_mhz}"
        else
            bandwidth="0x0:${bw_mhz}"
        fi
    else
        # Fallback to basic band from interface or chanspec
        if [ -n "${chanspec}" ]; then
            case "${chanspec}" in
                *6g*) bandwidth="6G" ;;
                *5g*) bandwidth="5G" ;;
                *2g*) bandwidth="2.4G" ;;
                *) bandwidth=$(get_band_from_interface "${iface}" | sed 's/GHz//; s/\.0//; s/-2$/2/') ;;
            esac
        else
            bandwidth=$(get_band_from_interface "${iface}" | sed 's/GHz//; s/\.0//; s/-2$/2/')
        fi

        # If still no bandwidth info, mark as unknown
        [ -z "${bandwidth}" ] && bandwidth="?"
    fi

    printf "  %-14s | %-15s | %-17s | %7s | %5s | %5s | %7s | %7s | %3s | %s\n" \
        "${hostname}" "${clientip}" "${canonupper}" "${uptime}" \
        "${tx_gb}" "${rx_gb}" "${tx_mbps}" "${rx_mbps}" "${rssi:--}" "${bandwidth}"
}

get_lan_clients() {
    local dhcp_leases="$1"
    local temp_file="/tmp/lan_clients_$$.tmp"

    if [ -f /proc/net/arp ]; then
        ${CAT} /proc/net/arp | awk 'NR>1 && $3!="0x0" && $4!="00:00:00:00:00:00" {print $1, $4}' > "${temp_file}"
    else
        ${ARP} -n 2>/dev/null | awk 'NR>1 && $1!="?" {print $1, $3}' > "${temp_file}"
    fi

    # Group IPs by MAC to handle multiple IPs per MAC
    local processed_macs_local=""

    while read ip mac; do
        [ -z "${mac}" ] || [ -z "${ip}" ] && continue
        [ "${ip}" = "IP" ] && continue

        if ! is_local_ip "${ip}"; then
            continue
        fi

        local mac_normalized=$(echo "${mac}" | tr 'A-F' 'a-f')
        local mac_upper=$(echo "${mac}" | tr 'a-f' 'A-F')

        # Skip if already processed this MAC in this function
        echo "${processed_macs_local}" | grep -q "${mac_normalized}" && continue

        # Skip if this MAC was already shown in wireless section
        if [ -f "${PROCESSED_CLIENTS}" ]; then
            if grep -qi "^${mac_upper}$" "${PROCESSED_CLIENTS}" 2>/dev/null; then
                continue
            fi
        fi

        # Track this MAC as processed
        echo "${mac_upper}" >> "${PROCESSED_CLIENTS}"

        # Find all IPs for this MAC and prefer REACHABLE/DELAY
        local all_ips=$(grep -i "${mac}" "${temp_file}" | awk '{print $1}')
        local best_ip=""

        if [ -n "${all_ips}" ]; then
            for candidate_ip in ${all_ips}; do
                local arp_status=$(ip neigh show | grep -w "${candidate_ip}" | awk '{print $NF}' 2>/dev/null)
                if [ -n "${arp_status}" ] && { [ "${arp_status}" = "REACHABLE" ] || [ "${arp_status}" = "DELAY" ]; }; then
                    best_ip="${candidate_ip}"
                    break
                fi
            done
            # Fallback to first IP if no REACHABLE/DELAY found
            [ -z "${best_ip}" ] && best_ip=$(echo "${all_ips}" | head -n1)
        else
            best_ip="${ip}"
        fi

        local hostname=$(get_hostname "${mac}" "${best_ip}" "${dhcp_leases}")
        printf "  %-14s | %-15s | %s\n" "${hostname}" "${best_ip}" "${mac}"
        processed_macs_local="${processed_macs_local} ${mac_normalized}"
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

# Get subnet for a specific bridge interface
get_bridge_subnet() {
    local bridge="$1"
    local bridge_ip=$(${IFCONFIG} "${bridge}" 2>/dev/null | grep 'inet addr:' | awk '{print $2}' | cut -d':' -f2)
    if [ -z "${bridge_ip}" ]; then
        bridge_ip=$(${IFCONFIG} "${bridge}" 2>/dev/null | awk '/inet / {print $2}')
    fi

    if [ -n "${bridge_ip}" ]; then
        echo "${bridge_ip}" | awk -F'.' '{print $1"."$2"."$3".0/24"}'
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

get_bridge_clients() {
    local bridge="$1"
    local dhcp_leases="$2"
    local temp_file="/tmp/bridge_clients_$$.tmp"

    # Get clients from ARP table that are on this specific bridge (Device column)
    if [ -f /proc/net/arp ]; then
        ${CAT} /proc/net/arp | awk -v bridge="${bridge}" 'NR>1 && $3!="0x0" && $4!="00:00:00:00:00:00" && $6==bridge {print $1, $4, $6}' > "${temp_file}"
    else
        # Fallback: if arp command is used, we won't have bridge info
        rm -f "${temp_file}"
        return
    fi

    # Group IPs by MAC to handle multiple IPs per MAC
    local processed_macs_local=""

    while read ip mac device; do
        [ -z "${mac}" ] || [ -z "${ip}" ] && continue

        local mac_normalized=$(echo "${mac}" | tr 'A-F' 'a-f')
        local mac_upper=$(echo "${mac}" | tr 'a-f' 'A-F')

        # Skip if already processed this MAC in this function
        echo "${processed_macs_local}" | grep -q "${mac_normalized}" && continue

        # Skip if this MAC was already shown in wireless section
        if [ -f "${PROCESSED_CLIENTS}" ]; then
            if grep -qi "^${mac_upper}$" "${PROCESSED_CLIENTS}" 2>/dev/null; then
                continue
            fi
        fi

        # Track this MAC as processed
        echo "${mac_upper}" >> "${PROCESSED_CLIENTS}"

        # Find all IPs for this MAC on this bridge and prefer REACHABLE/DELAY
        local all_ips=$(grep -i "${mac}" "${temp_file}" | awk '{print $1}')
        local best_ip=""

        if [ -n "${all_ips}" ]; then
            for candidate_ip in ${all_ips}; do
                local arp_status=$(ip neigh show | grep -w "${candidate_ip}" | awk '{print $NF}' 2>/dev/null)
                if [ -n "${arp_status}" ] && { [ "${arp_status}" = "REACHABLE" ] || [ "${arp_status}" = "DELAY" ]; }; then
                    best_ip="${candidate_ip}"
                    break
                fi
            done
            # Fallback to first IP if no REACHABLE/DELAY found
            [ -z "${best_ip}" ] && best_ip=$(echo "${all_ips}" | head -n1)
        else
            best_ip="${ip}"
        fi

        local hostname=$(get_hostname "${mac}" "${best_ip}" "${dhcp_leases}")
        printf "  %-14s | %-15s | %s\n" "${hostname}" "${best_ip}" "${mac}"
        processed_macs_local="${processed_macs_local} ${mac_normalized}"
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

    # Initialize processed client tracking files
    > "${PROCESSED_CLIENTS}"
    > "${PROCESSED_VLAN_CLIENTS}"

    # Read DHCP leases once for MLO/MLD awareness
    local dhcp_leases=$(read_all_dhcp_leases)

    echo ""
    echo "================================================================================"
    echo "  ASUS Network Client Monitor PoC v12"
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

        # Get bridge information for display
        local bridge_name=$(get_bridge_for_interface "${iface}")
        local bridge_info=""
        if [ -n "${bridge_name}" ]; then
            bridge_info=" (Bridge: ${bridge_name})"
        fi

        if [ "${iface_type}" = "guest" ]; then
            echo " Guest ${band} Wi-Fi: ${guest_ssid}${bridge_info} - IFace: ${iface}"
        elif [ "${iface_type}" = "main" ]; then
            # Get SSID for main wireless interfaces
            local main_ssid=$(get_ssid_for_interface "${iface}")
            if [ -n "${main_ssid}" ]; then
                echo " Local ${band} Wi-Fi: ${main_ssid}${bridge_info} - IFace: ${iface}"
            else
                echo " Local ${band}${bridge_info} - IFace: ${iface}"
            fi
        fi

        if [ "${iface_type}" = "main" ] || [ "${iface_type}" = "guest" ]; then
            printf "  %-14s | %-15s | %-17s | %7s | %5s | %5s | %7s | %7s | %3s | %s\n" \
                "Name" "IP" "MAC" "Uptime" "TX GB" "RX GB" "TX Mbps" "RX Mbps" "Sig" "Band"

            if [ -n "${client_list}" ]; then
                local temp_output="/tmp/netmon_client_output_$$.tmp"
                > "${temp_output}"

                for mac in ${client_list}; do
                    get_wireless_client_details "${iface}" "${mac}" "${dhcp_leases}" >> "${temp_output}"
                done

                if [ -s "${temp_output}" ]; then
                    ${CAT} "${temp_output}"
                else
                    echo "  No wireless clients connected"
                fi
                rm -f "${temp_output}"
            else
                echo "  No wireless clients connected"
            fi
            echo ""
        fi
    done

    # Get VLAN/AiMesh bridges from apg_ifnames (more accurate than subnet detection)
    local vlan_bridges=$(get_vlan_bridges)

    if [ -n "${vlan_bridges}" ]; then
        for bridge in ${vlan_bridges}; do
            # Get subnet for this bridge if available
            local bridge_subnet=$(get_bridge_subnet "${bridge}")

            if [ -n "${bridge_subnet}" ]; then
                echo " Local VLAN/AiMesh VLAN ${bridge_subnet} - IFace: ${bridge}"
            else
                echo " Local VLAN/AiMesh VLAN - IFace: ${bridge}"
            fi

            printf "  %-14s | %-15s | %s\n" "Name" "IP" "MAC"

            # Use bridge-based client detection
            local bridge_client_output=$(get_bridge_clients "${bridge}" "${dhcp_leases}")

            if [ -n "${bridge_client_output}" ]; then
                echo "${bridge_client_output}"
            else
                echo "  No wired clients found"
            fi
            echo ""
        done
    fi

    local primary_subnet=$(get_primary_subnet)
    echo " Local LAN/Non-VLAN AiMesh - Subnet: ${primary_subnet} - IFace: br0"
    printf "  %-14s | %-15s | %s\n" "Name" "IP" "MAC"

    # Use bridge-based detection for br0 clients
    local br0_clients=$(get_bridge_clients "br0" "${dhcp_leases}")
    if [ -n "${br0_clients}" ]; then
        echo "${br0_clients}"
    else
        echo "  No wired clients found"
    fi

    echo ""
    echo "================================================================================"

    # Cleanup tracking files
    rm -f "${PROCESSED_CLIENTS}" "${PROCESSED_VLAN_CLIENTS}"
}

################################################################################
# ENTRY POINT
################################################################################

detect_router_model

display_network_clients

exit 0
