#!/bin/sh
#
# KILLMON v1.1.3 - Asus-Merlin IP4/IP6 Kill Switch Monitor & Configurator by Viktor Jaep, 2022
#
# KILLMON is a shell script that provides additional capabilities outside of the VPN kill switch functionality that is
# currently integrated into the Asus-Merlin Firmware. KILLMON builds on the excellent kill switch script originally
# provided by @Eibgrad, and provides a user interface to help monitor, enable, or disable kill switch operations, as well
# as allowing you to choose how to implement the kill switch for both IP4 and IP6 traffic. Currently, KILLMON provides
# traffic kill modes for 3 different scenarios...
#
# (1) Paranoid mode - All LAN traffic is forbidden from using the current WAN interface
# (2) IP Range mode - All LAN traffic within specified IP Range is forbidden from using the current WAN interface
# (3) Single IP mode - All LAN traffic on specified IP is forbidden from using the current WAN interface
#
# In each instance,a valid VPN tunnel must be up and running for traffic to make it out to the internet, preventing any
# possible traffic leaks while a VPN tunnel is down, thus the necessity for a kill switch.
#
# IMPORTANT NOTE: Many kill switches do not consider IP6, or recommend just completely disabling IP6 on the router itself.
# KILLMON may very well be one of the first kill switches that both embraces and kills the sh*t out of unwanted IP6 traffic
# when your VPN connection goes down. Please note that if IPv6 is enabled on your router and are using a kill switch of any
# kind that does not specifically block IP6, any and all traffic that utilizes IPv6 addressing will be leaking traffic
# around your IP4 VPN tunnel over your WAN when it goes down.
#
# Last Updated: 2026-Apr-28

#Preferred standard router binaries path
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:$PATH"
unset LD_LIBRARY_PATH

##-------------------------------------##
## Added by Martinski W. [2026-Apr-13] ##
##-------------------------------------##
[ "$HOME" != "/root" ] && export HOME="/root"
export SCREENDIR="${HOME}/.screen"

# -------------------------------------------------------------------------------------------------------------------------
# System Variables (Do not change beyond this point or this may change the programs ability to function correctly)
# -------------------------------------------------------------------------------------------------------------------------
Version="1.1.3"
Beta=0
APPPATH="/jffs/scripts/killmon.sh"
CFGPATH="/jffs/addons/killmon.d/killmon.cfg"
LOGFILE="/jffs/addons/killmon.d/killmon.log"
DLVERPATH="/jffs/addons/killmon.d/version.txt"
FW_CHAIN="KILLMON"
FW6_CHAIN="KILLMON6"
killswitchstatus="DISABLED" # ENABLED OR DISABLED
killswitch6status="DISABLED" # ENABLED OR DISABLED
killswitchautostart="DISABLED" # ENABLED OR DISABLED
killswitchmode="INACTIVE" # PARANOID, IP RANGE, SINGLEIP, OR INACTIVE
killswitch6mode="INACTIVE" # PARANOID, IP RANGE, SINGLEIP, OR INACTIVE
iprangenotation=1 # 0=CIDR, 1=Range
ip6rangenotation=1 # 0=CIDR, 1=Range
iprangecidr="192.168.1.0/24"
ip6rangecidr="2601:04c1:417f:e91c:0000:0000:0000:0000/64" # Local IPv6 Subnet /64
iprangefrom="192.168.1.50"
ip6rangefrom="2601:04c1:417f:e91c:0000:0000:0000:0000" # Local IPv6 Subnet Start
iprangeto="192.168.1.60"
ip6rangeto="2601:04c1:417f:e91c:0000:0000:0000:000f" # Local IPv6 Subnet End with 16 sample usable addresses
ipsingle="192.168.1.150"
ip6single="fe80::92ca:faff:fe22:97bf"
WANIFUSED=0 # 0=WAN0, 1=WAN1, OR 2=WAN0/1
WAN0IFNAME="eth0"
WAN1IFNAME="None"
hideoptions=1

# To support automatic script updates from AMTM #
doScriptUpdateFromAMTM=true

# Color variables
CBlack="\e[1;30m"
InvBlack="\e[1;40m"
CRed="\e[1;31m"
InvRed="\e[1;41m"
CGreen="\e[1;32m"
InvGreen="\e[1;42m"
CDkGray="\e[1;90m"
InvDkGray="\e[1;100m"
InvLtGray="\e[1;47m"
CYellow="\e[1;33m"
InvYellow="\e[1;43m"
CBlue="\e[1;34m"
InvBlue="\e[1;44m"
CMagenta="\e[1;35m"
CCyan="\e[1;36m"
InvCyan="\e[1;46m"
CWhite="\e[1;37m"
InvWhite="\e[1;107m"
CClear="\e[0m"

# -------------------------------------------------------------------------------------------------------------------------
# Functions
# -------------------------------------------------------------------------------------------------------------------------

# LogoNM is a function that displays the KILLMON script name in a cool ASCII font without menu options
logoNM () {
echo -e "${CYellow}     __ __ ______    __    __  _______  _   __"
echo -e "    / //_//  _/ /   / /   /  |/  / __ \/ | / /  ${CGreen}v$Version${CYellow}"
echo -e "   / ,<   / // /   / /   / /|_/ / / / /  |/ /"
echo -e "  / /| |_/ // /___/ /___/ /  / / /_/ / /|  /"
echo -e " /_/ |_/___/_____/_____/_/  /_/\____/_/ |_/${CClear}"
}

# LogoNM is a function that displays the KILLMON script name in a cool ASCII font without menu options
logo () {
echo -e "${CYellow}     __ __ ______    __    __  _______  _   __"
echo -e "    / //_//  _/ /   / /   /  |/  / __ \/ | / /  ${CGreen}v$Version${CYellow}"
echo -e "   / ,<   / // /   / /   / /|_/ / / / /  |/ /  ${CRed}(S)${CGreen}etup${CYellow}"
echo -e "  / /| |_/ // /___/ /___/ /  / / /_/ / /|  /   ${CRed}(I)${CGreen}structions${CYellow}"
echo -e " /_/ |_/___/_____/_____/_/  /_/\____/_/ |_/    ${CRed}(E)${CGreen}xit${CClear}"
}

# -------------------------------------------------------------------------------------------------------------------------

# promptyn takes input for Y/N questions
promptyn () {   # No defaults, just y or n
  while true; do
    read -p "[y/n]? " -n 1 -r yn
      case "${yn}" in
        [Yy]* ) return 0 ;;
        [Nn]* ) return 1 ;;
        * ) echo -e "\nPlease answer y or n.";;
      esac
  done
}

##-------------------------------------------##
## Borrwed from ExtremeFiretop [2026-Apr-11] ##
##-------------------------------------------##
ScriptUpdateFromAMTM()
{
    if ! "$doScriptUpdateFromAMTM"
    then
        printf "Automatic script updates via AMTM are currently disabled.\n\n"
        return 1
    fi

    if [ $# -gt 0 ] && [ "$1" = "check" ]
    then return 0
    fi

    # Force a BACKUPMON download and update
    echo -e "${CClear}[i] Force Downloading KILLMON... Please stand by..."
    curl --silent --fail --retry 3 "https://raw.githubusercontent.com/ViktorJp/KILLMON/main/killmon.sh" -o "/jffs/scripts/killmon.sh" && chmod 755 "/jffs/scripts/killmon.sh"
    DLsuccess=$?
    if [ "$DLsuccess" -eq 0 ]; then
      echo -e "${CClear}[i] KILLMON Download/Update Success."
    else
      echo -e "${CClear}[X] KILLMON Download/Update Failed."
    fi

    return "$DLsuccess"
}

# -------------------------------------------------------------------------------------------------------------------------

# Separated these out to get the ifname for a dual-wan/failover situation where both WAN connections are on
get_wan_setting0() {
  local varname varval
  varname="${1}"
  prefixes="wan0_"

  if [ "$($timeoutcmd$timeoutsec nvram get wans_mode)" = "lb" ] ; then
      for prefix in $prefixes; do
          state="$($timeoutcmd$timeoutsec nvram get "${prefix}"state_t)"
          sbstate="$($timeoutcmd$timeoutsec nvram get "${prefix}"sbstate_t)"
          auxstate="$($timeoutcmd$timeoutsec nvram get "${prefix}"auxstate_t)"

          # is_wan_connect()
          [ "${state}" = "2" ] || continue
          [ "${sbstate}" = "0" ] || continue
          [ "${auxstate}" = "0" ] || [ "${auxstate}" = "2" ] || continue

          # get_wan_ifname()
          proto="$($timeoutcmd$timeoutsec nvram get "${prefix}"proto)"
          if [ "${proto}" = "pppoe" ] || [ "${proto}" = "pptp" ] || [ "${proto}" = "l2tp" ] ; then
              varval="$($timeoutcmd$timeoutsec nvram get "${prefix}"pppoe_"${varname}")"
          else
              varval="$($timeoutcmd$timeoutsec nvram get "${prefix}""${varname}")"
          fi
      done
  else
      for prefix in $prefixes; do
          primary="$($timeoutcmd$timeoutsec nvram get "${prefix}"primary)"
          [ "${primary}" = "1" ] && break
      done

      proto="$($timeoutcmd$timeoutsec nvram get "${prefix}"proto)"
      if [ "${proto}" = "pppoe" ] || [ "${proto}" = "pptp" ] || [ "${proto}" = "l2tp" ] ; then
          varval="$($timeoutcmd$timeoutsec nvram get "${prefix}"pppoe_"${varname}")"
      else
          varval="$($timeoutcmd$timeoutsec nvram get "${prefix}""${varname}")"
      fi
  fi
  printf "%s" "${varval}"
} # get_wan_setting

# Separated these out to get the ifname for a dual-wan/failover situation where both WAN connections are on
get_wan_setting1() {
  local varname varval
  varname="${1}"
  prefixes="wan1_"

  if [ "$($timeoutcmd$timeoutsec nvram get wans_mode)" = "lb" ] ; then
      for prefix in $prefixes; do
          state="$($timeoutcmd$timeoutsec nvram get "${prefix}"state_t)"
          sbstate="$($timeoutcmd$timeoutsec nvram get "${prefix}"sbstate_t)"
          auxstate="$($timeoutcmd$timeoutsec nvram get "${prefix}"auxstate_t)"

          # is_wan_connect()
          [ "${state}" = "2" ] || continue
          [ "${sbstate}" = "0" ] || continue
          [ "${auxstate}" = "0" ] || [ "${auxstate}" = "2" ] || continue

          # get_wan_ifname()
          proto="$($timeoutcmd$timeoutsec nvram get "${prefix}"proto)"
          if [ "${proto}" = "pppoe" ] || [ "${proto}" = "pptp" ] || [ "${proto}" = "l2tp" ] ; then
              varval="$($timeoutcmd$timeoutsec nvram get "${prefix}"pppoe_"${varname}")"
          else
              varval="$($timeoutcmd$timeoutsec nvram get "${prefix}""${varname}")"
          fi
      done
  else
      for prefix in $prefixes; do
          primary="$($timeoutcmd$timeoutsec nvram get "${prefix}"primary)"
          [ "${primary}" = "1" ] && break
      done

      proto="$($timeoutcmd$timeoutsec nvram get "${prefix}"proto)"
      if [ "${proto}" = "pppoe" ] || [ "${proto}" = "pptp" ] || [ "${proto}" = "l2tp" ] ; then
          varval="$($timeoutcmd$timeoutsec nvram get "${prefix}"pppoe_"${varname}")"
      else
          varval="$($timeoutcmd$timeoutsec nvram get "${prefix}""${varname}")"
      fi
  fi
  printf "%s" "${varval}"
} # get_wan_setting

# -------------------------------------------------------------------------------------------------------------------------
# iptables commands for the various modes

paranoidmode () {

  iptables -N $FW_CHAIN
  if [ $WANIFUSED -eq 0 ]; then
    iptables -I FORWARD -i br+ -o $WAN0IFNAME -j $FW_CHAIN
    iptables -A $FW_CHAIN -i br+ -o $WAN0IFNAME -j REJECT
  elif [ $WANIFUSED -eq 1 ]; then
    iptables -I FORWARD -i br+ -o $WAN1IFNAME -j $FW_CHAIN
    iptables -A $FW_CHAIN -i br+ -o $WAN1IFNAME -j REJECT
  elif [ $WANIFUSED -eq 2 ]; then
    iptables -I FORWARD -i br+ -o $WAN0IFNAME -j $FW_CHAIN
    iptables -I FORWARD -i br+ -o $WAN1IFNAME -j $FW_CHAIN
    iptables -A $FW_CHAIN -i br+ -o $WAN0IFNAME -j REJECT
    iptables -A $FW_CHAIN -i br+ -o $WAN1IFNAME -j REJECT
  fi

}

paranoidmode6 () {

  ip6tables -N $FW6_CHAIN
  if [ $WANIFUSED -eq 0 ]; then
    ip6tables -I FORWARD -i br+ -o $WAN0IFNAME -j $FW6_CHAIN
    ip6tables -A $FW6_CHAIN -i br+ -o $WAN0IFNAME -j REJECT
  elif [ $WANIFUSED -eq 1 ]; then
    ip6tables -I FORWARD -i br+ -o $WAN1IFNAME -j $FW6_CHAIN
    ip6tables -A $FW6_CHAIN -i br+ -o $WAN1IFNAME -j REJECT
  elif [ $WANIFUSED -eq 2 ]; then
    ip6tables -I FORWARD -i br+ -o $WAN0IFNAME -j $FW6_CHAIN
    ip6tables -I FORWARD -i br+ -o $WAN1IFNAME -j $FW6_CHAIN
    ip6tables -A $FW6_CHAIN -i br+ -o $WAN0IFNAME -j REJECT
    ip6tables -A $FW6_CHAIN -i br+ -o $WAN1IFNAME -j REJECT
  fi

}

iprangemode () {

  iptables -N $FW_CHAIN
  if [ $iprangenotation -eq 0 ]; then
    if [ $WANIFUSED -eq 0 ]; then
      iptables -I FORWARD -i br+ -o $WAN0IFNAME -j $FW_CHAIN
      iptables -A $FW_CHAIN -s $iprangecidr -o $WAN0IFNAME -j REJECT
    elif [ $WANIFUSED -eq 1 ]; then
      iptables -I FORWARD -i br+ -o $WAN1IFNAME -j $FW_CHAIN
      iptables -A $FW_CHAIN -s $iprangecidr -o $WAN1IFNAME -j REJECT
    elif [ $WANIFUSED -eq 2 ]; then
      iptables -I FORWARD -i br+ -o $WAN0IFNAME -j $FW_CHAIN
      iptables -I FORWARD -i br+ -o $WAN1IFNAME -j $FW_CHAIN
      iptables -A $FW_CHAIN -s $iprangecidr -o $WAN0IFNAME -j REJECT
      iptables -A $FW_CHAIN -s $iprangecidr -o $WAN1IFNAME -j REJECT
    fi
  elif [ $iprangenotation -eq 1 ]; then
    if [ $WANIFUSED -eq 0 ]; then
      iptables -I FORWARD -i br+ -o $WAN0IFNAME -j $FW_CHAIN
      iptables -A $FW_CHAIN -m iprange --src-range $iprangefrom"-"$iprangeto -j REJECT
    elif [ $WANIFUSED -eq 1 ]; then
      iptables -I FORWARD -i br+ -o $WAN1IFNAME -j $FW_CHAIN
      iptables -A $FW_CHAIN -m iprange --src-range $iprangefrom"-"$iprangeto -j REJECT
    elif [ $WANIFUSED -eq 2 ]; then
      iptables -I FORWARD -i br+ -o $WAN0IFNAME -j $FW_CHAIN
      iptables -I FORWARD -i br+ -o $WAN1IFNAME -j $FW_CHAIN
      iptables -A $FW_CHAIN -m iprange --src-range $iprangefrom"-"$iprangeto -j REJECT
    fi
  fi

}

iprangemode6 () {

  ip6tables -N $FW6_CHAIN
  if [ $ip6rangenotation -eq 0 ]; then
    if [ $WANIFUSED -eq 0 ]; then
      ip6tables -I FORWARD -i br+ -o $WAN0IFNAME -j $FW6_CHAIN
      ip6tables -A $FW6_CHAIN -s $ip6rangecidr -o $WAN0IFNAME -j REJECT
    elif [ $WANIFUSED -eq 1 ]; then
      ip6tables -I FORWARD -i br+ -o $WAN1IFNAME -j $FW6_CHAIN
      ip6tables -A $FW6_CHAIN -s $ip6rangecidr -o $WAN1IFNAME -j REJECT
    elif [ $WANIFUSED -eq 2 ]; then
      ip6tables -I FORWARD -i br+ -o $WAN0IFNAME -j $FW6_CHAIN
      ip6tables -I FORWARD -i br+ -o $WAN1IFNAME -j $FW6_CHAIN
      ip6tables -A $FW6_CHAIN -s $ip6rangecidr -o $WAN0IFNAME -j REJECT
      ip6tables -A $FW6_CHAIN -s $ip6rangecidr -o $WAN1IFNAME -j REJECT
    fi
  elif [ $ip6rangenotation -eq 1 ]; then
    if [ $WANIFUSED -eq 0 ]; then
      ip6tables -I FORWARD -i br+ -o $WAN0IFNAME -j $FW6_CHAIN
      ip6tables -A $FW6_CHAIN -m iprange --src-range $ip6rangefrom"-"$ip6rangeto -j REJECT
    elif [ $WANIFUSED -eq 1 ]; then
      ip6tables -I FORWARD -i br+ -o $WAN1IFNAME -j $FW6_CHAIN
      ip6tables -A $FW6_CHAIN -m iprange --src-range $ip6rangefrom"-"$ip6rangeto -j REJECT
    elif [ $WANIFUSED -eq 2 ]; then
      ip6tables -I FORWARD -i br+ -o $WAN0IFNAME -j $FW6_CHAIN
      ip6tables -I FORWARD -i br+ -o $WAN1IFNAME -j $FW6_CHAIN
      ip6tables -A $FW6_CHAIN -m iprange --src-range $ip6rangefrom"-"$ip6rangeto -j REJECT
    fi
  fi

}

singleipmode () {

  iptables -N $FW_CHAIN
  if [ $WANIFUSED -eq 0 ]; then
    iptables -I FORWARD -i br+ -o $WAN0IFNAME -j $FW_CHAIN
    iptables -A $FW_CHAIN -s $ipsingle -o $WAN0IFNAME -j REJECT
  elif [ $WANIFUSED -eq 1 ]; then
    iptables -I FORWARD -i br+ -o $WAN1IFNAME -j $FW_CHAIN
    iptables -A $FW_CHAIN -s $ipsingle -o $WAN1IFNAME -j REJECT
  elif [ $WANIFUSED -eq 2 ]; then
    iptables -I FORWARD -i br+ -o $WAN0IFNAME -j $FW_CHAIN
    iptables -I FORWARD -i br+ -o $WAN1IFNAME -j $FW_CHAIN
    iptables -A $FW_CHAIN -s $ipsingle -o $WAN0IFNAME -j REJECT
    iptables -A $FW_CHAIN -s $ipsingle -o $WAN1IFNAME -j REJECT
  fi

}

singleipmode6 () {

  ip6tables -N $FW6_CHAIN
  if [ $WANIFUSED -eq 0 ]; then
    ip6tables -I FORWARD -i br+ -o $WAN0IFNAME -j $FW6_CHAIN
    ip6tables -A $FW6_CHAIN -s $ip6single -o $WAN0IFNAME -j REJECT
  elif [ $WANIFUSED -eq 1 ]; then
    ip6tables -I FORWARD -i br+ -o $WAN1IFNAME -j $FW6_CHAIN
    ip6tables -A $FW6_CHAIN -s $ip6single -o $WAN1IFNAME -j REJECT
  elif [ $WANIFUSED -eq 2 ]; then
    ip6tables -I FORWARD -i br+ -o $WAN0IFNAME -j $FW6_CHAIN
    ip6tables -I FORWARD -i br+ -o $WAN1IFNAME -j $FW6_CHAIN
    ip6tables -A $FW6_CHAIN -s $ip6single -o $WAN0IFNAME -j REJECT
    ip6tables -A $FW6_CHAIN -s $ip6single -o $WAN1IFNAME -j REJECT
  fi

}

reverserules () {

  # Reverse Paranoid Mode iptables rules
  iptables -D $FW_CHAIN -i br+ -o $WAN0IFNAME -j REJECT >/dev/null 2>/dev/null
  iptables -D $FW_CHAIN -i br+ -o $WAN1IFNAME -j REJECT >/dev/null 2>/dev/null
  # Reverse IP Range Mode iptables rules
  iptables -D $FW_CHAIN -s $iprangecidr -o $WAN0IFNAME -j REJECT >/dev/null 2>/dev/null
  iptables -D $FW_CHAIN -s $iprangecidr -o $WAN1IFNAME -j REJECT >/dev/null 2>/dev/null
  iptables -D $FW_CHAIN -m iprange --src-range $iprangefrom"-"$iprangeto -j REJECT >/dev/null 2>/dev/null
  # Reverse Single IP Mode iptables rules
  iptables -D $FW_CHAIN -s $ipsingle -o $WAN0IFNAME -j REJECT >/dev/null 2>/dev/null
  iptables -D $FW_CHAIN -s $ipsingle -o $WAN1IFNAME -j REJECT >/dev/null 2>/dev/null
  # Remove custom chain name
  iptables -D FORWARD -i br+ -o $WAN0IFNAME -j $FW_CHAIN >/dev/null 2>/dev/null
  iptables -D FORWARD -i br+ -o $WAN1IFNAME -j $FW_CHAIN >/dev/null 2>/dev/null
  iptables -F $FW_CHAIN >/dev/null 2>/dev/null && iptables -X $FW_CHAIN >/dev/null 2>/dev/null

}

reverserules6 () {

  # Reverse Paranoid Mode ip6tables rules
  ip6tables -D $FW6_CHAIN -i br+ -o $WAN0IFNAME -j REJECT >/dev/null 2>/dev/null
  ip6tables -D $FW6_CHAIN -i br+ -o $WAN1IFNAME -j REJECT >/dev/null 2>/dev/null
  # Reverse IP Range Mode iptables rules
  ip6tables -D $FW6_CHAIN -s $ip6rangecidr -o $WAN0IFNAME -j REJECT >/dev/null 2>/dev/null
  ip6tables -D $FW6_CHAIN -s $ip6rangecidr -o $WAN1IFNAME -j REJECT >/dev/null 2>/dev/null
  ip6tables -D $FW6_CHAIN -m iprange --src-range $ip6rangefrom"-"$ip6rangeto -j REJECT >/dev/null 2>/dev/null
  # Reverse Single IP Mode iptables rules
  ip6tables -D $FW6_CHAIN -s $ip6single -o $WAN0IFNAME -j REJECT >/dev/null 2>/dev/null
  ip6tables -D $FW6_CHAIN -s $ip6single -o $WAN1IFNAME -j REJECT >/dev/null 2>/dev/null
  # Remove custom chain name
  ip6tables -D FORWARD -i br+ -o $WAN0IFNAME -j $FW6_CHAIN >/dev/null 2>/dev/null
  ip6tables -D FORWARD -i br+ -o $WAN1IFNAME -j $FW6_CHAIN >/dev/null 2>/dev/null
  ip6tables -F $FW6_CHAIN >/dev/null 2>/dev/null && ip6tables -X $FW6_CHAIN >/dev/null 2>/dev/null

}

# -------------------------------------------------------------------------------------------------------------------------

# vsetup is a function that sets up, confiures and allows you to launch KILLMON on your router...
vsetup () {

  while true; do
    clear
    logoNM
    echo ""
    echo -e "${CYellow}Setup Utility${CClear}" # Provide main setup menu
    echo ""
    echo -e "${CGreen}----------------------------------------------------------------"
    echo -e "${CGreen}Setup Operations"
    echo -e "${CGreen}----------------------------------------------------------------"
    echo -e "${InvDkGray}${CWhite} mc ${CClear}${CCyan}: Monitor and Configure KILLMON"
    echo -e "${InvDkGray}${CWhite} fr ${CClear}${CCyan}: Force Re-install Entware Dependencies"
    echo -e "${InvDkGray}${CWhite} up ${CClear}${CCyan}: Check for latest updates"
    echo -e "${InvDkGray}${CWhite} vl ${CClear}${CCyan}: View logs"
    echo -e "${InvDkGray}${CWhite} un ${CClear}${CCyan}: Uninstall"
    echo -e "${InvDkGray}${CWhite}  e ${CClear}${CCyan}: Exit"
    echo -e "${CGreen}----------------------------------------------------------------"
    echo ""
    printf "Selection: "
    read -r InstallSelection

    # Execute chosen selections
        case "$InstallSelection" in

          mc) # Check for existence of entware, and if so proceed and install the timeout package
            clear
            if [ -f "/opt/bin/timeout" ]; then
              sh $APPPATH -monitor
            else
              logoNM
              echo ""
              echo -e "${CYellow}Installing KILLMON Dependencies...${CClear}"
              echo ""
              echo -e "${CCyan}KILLMON will require the installation of CoreUtils-Timeout utility.${CClear}"
              echo -e "${CCyan}These utilities require you to have Entware already installed using${CClear}"
              echo -e "${CCyan}the AMTM tool. If Entware is present, the Timeout utility will be${CClear}"
              echo -e "${CCyan}downloaded and installed during this setup process, and utilized by${CClear}"
              echo -e "${CCyan}KILLMON${CClear}"
              echo ""
              echo -e "${CGreen}CoreUtils-Timeout${CCyan} is a utility that provides more stability for${CClear}"
              echo -e "${CCyan}certain routers (like the RT-AC86U) which has a tendency to randomly${CClear}"
              echo -e "${CCyan}hang scripts running on this router model.${CClear}"
              echo ""
              [ -z "$($timeoutcmd$timeoutsec nvram get odmpid)" ] && RouterModel="$($timeoutcmd$timeoutsec nvram get productid)" || RouterModel="$($timeoutcmd$timeoutsec nvram get odmpid)" # Thanks @thelonelycoder for this logic
              echo -e "${CCyan}Your router model is: ${CYellow}$RouterModel"
              echo ""
              echo -e "${CCyan}Ready to install?${CClear}"
              if promptyn "(y/n): "
                then
                  if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
                    echo ""
                    echo -e "\n${CGreen}Updating Entware Packages...${CClear}"
                    echo ""
                    opkg update
                    echo ""
                    echo -e "${CGreen}Installing Entware CoreUtils-Timeout Package...${CClear}"
                    echo ""
                    opkg install coreutils-timeout
                    echo ""
                    read -rsp $'Press any key to continue...\n' -n1 key
                    echo ""
                    echo -e "${CGreen}Executing KILLMON Configuration Utility...${CClear}"
                    sleep 2
                    sh $APPPATH -monitor
                  else
                    clear
                    echo -e "${CGreen}ERROR: Entware was not found on this router...${CClear}"
                    echo -e "${CGreen}Please install Entware using the AMTM utility before proceeding...${CClear}"
                    echo ""
                    sleep 3
                  fi
                else
                  echo ""
                  echo -e "\n${CGreen}Executing KILLMON Configuration Utility...${CClear}"
                  sleep 2
                  sh $APPPATH -monitor
              fi
            fi
          ;;


          fr) # Force re-install the CoreUtils timeout/screen package
            clear
            logoNM
            echo ""
            echo -e "${CYellow}Force Re-installing KILLMON Dependencies...${CClear}"
            echo ""
            echo -e "${CCyan}KILLMON will require the installation of CoreUtils-Timeout utility.${CClear}"
            echo -e "${CCyan}These utilities require you to have Entware already installed using${CClear}"
            echo -e "${CCyan}the AMTM tool. If Entware is present, the Timeout utility will be${CClear}"
            echo -e "${CCyan}downloaded and installed during this setup process, and utilized by${CClear}"
            echo -e "${CCyan}KILLMON${CClear}"
            echo ""
            echo -e "${CGreen}CoreUtils-Timeout${CCyan} is a utility that provides more stability for${CClear}"
            echo -e "${CCyan}certain routers (like the RT-AC86U) which has a tendency to randomly${CClear}"
            echo -e "${CCyan}hang scripts running on this router model.${CClear}"
            echo ""
            [ -z "$(nvram get odmpid)" ] && RouterModel="$(nvram get productid)" || RouterModel="$(nvram get odmpid)" # Thanks @thelonelycoder for this logic
            echo -e "${CCyan}Your router model is: ${CYellow}$RouterModel"
            echo ""
            echo -e "${CCyan}Force Re-install?${CClear}"
            if promptyn "(y/n): "
              then
                if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
                  echo ""
                  echo -e "\n${CGreen}Updating Entware Packages...${CClear}"
                  echo ""
                  opkg update
                  echo ""
                  echo -e "${CGreen}Force Re-installing Entware CoreUtils-Timeout Package...${CClear}"
                  echo ""
                  opkg install --force-reinstall coreutils-timeout
                  echo ""
                  echo -e "${CGreen}Re-install completed...${CClear}"
                  echo ""
                  read -rsp $'Press any key to continue...\n' -n1 key
                else
                  clear
                  echo -e "${CGreen}ERROR: Entware was not found on this router...${CClear}"
                  echo -e "${CGreen}Please install Entware using the AMTM utility before proceeding...${CClear}"
                  echo ""
                  sleep 3
                fi
            fi
          ;;

          up)
            echo ""
            vupdate
          ;;

          vl)
            echo ""
            vlogs
          ;;

          un)
            echo ""
            vuninstall
          ;;

          [Ee])
            echo -e "${CClear}"
            exit 0
          ;;

          *)
            echo ""
            echo -e "${CRed}Invalid choice - Please enter a valid option...${CClear}"
            echo ""
            sleep 2
          ;;

        esac
  done
}

# -------------------------------------------------------------------------------------------------------------------------

# updatecheck is a function that downloads the latest update version file, and compares it with what's currently installed
updatecheck () {

  # Download the latest version file from the source repository
  curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/KILLMON/master/version.txt" -o "/jffs/addons/killmon.d/version.txt"

  if [ -f $DLVERPATH ]
    then
      # Read in its contents for the current version file
      DLVersion=$(cat $DLVERPATH)

      # Compare the new version with the old version and log it
      if [ "$Beta" == "1" ]; then   # Check if Dev/Beta Mode is enabled and disable notification message
        UpdateNotify=0
      elif [ "$DLVersion" != "$Version" ]; then
        UpdateNotify="Update available: v$Version -> v$DLVersion"
        echo -e "$(date) - KILLMON - A new update (v$DLVersion) is available to download" >> $LOGFILE
      else
        UpdateNotify=0
      fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# vupdate is a function that provides a UI to check for script updates and allows you to install the latest version...
vupdate () {
  updatecheck # Check for the latest version from source repository
  clear
  logoNM
  echo ""
  echo -e "${CYellow}Update Utility${CClear}"
  echo ""
  echo -e "${CCyan}Current Version: ${CYellow}$Version${CClear}"
  echo -e "${CCyan}Updated Version: ${CYellow}$DLVersion${CClear}"
  echo ""
  if [ "$Version" == "$DLVersion" ]
    then
      echo -e "${CCyan}You are on the latest version! Would you like to download anyways?${CClear}"
      echo -e "${CCyan}This will overwrite your local copy with the current build.${CClear}"
      if promptyn "(y/n): "; then
        echo ""
        echo -e "${CCyan}Downloading KILLMON ${CYellow}v$DLVersion${CClear}"
        curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/KILLMON/master/killmon.sh" -o "/jffs/scripts/killmon.sh" && chmod a+rx "/jffs/scripts/killmon.sh"
        echo ""
        echo -e "${CCyan}Download successful!${CClear}"
        echo -e "$(date) - KILLMON - Successfully downloaded KILLMON v$DLVersion" >> $LOGFILE
        echo ""
        read -rsp $'Press any key to continue...\n' -n1 key
        exec sh /jffs/scripts/killmon.sh -setup
      else
        echo ""
        echo ""
        echo -e "${CGreen}Exiting Update Utility...${CClear}"
        sleep 1
        return
      fi
    else
      echo -e "${CCyan}Score! There is a new version out there! Would you like to update?${CClear}"
      if promptyn "(y/n): "; then
        echo ""
        echo -e "${CCyan}Downloading KILLMON ${CYellow}v$DLVersion${CClear}"
        curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/KILLMON/master/killmon.sh" -o "/jffs/scripts/killmon.sh" && chmod a+rx "/jffs/scripts/killmon.sh"
        echo ""
        echo -e "${CCyan}Download successful!${CClear}"
        echo -e "$(date) - KILLMON - Successfully downloaded KILLMON v$DLVersion" >> $LOGFILE
        echo ""
        read -rsp $'Press any key to continue...\n' -n1 key
        exec sh /jffs/scripts/killmon.sh -setup
      else
        echo ""
        echo ""
        echo -e "${CGreen}Exiting Update Utility...${CClear}"
        sleep 1
        return
      fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# vlogs is a function that calls the nano text editor to view the KILLMON log file
vlogs() {

export TERM=linux
nano +999999 --linenumbers $LOGFILE

}

# -------------------------------------------------------------------------------------------------------------------------

# vuninstall is a function that uninstalls and removes all traces of KILLMON from your router...
vuninstall () {
  clear
  logoNM
  echo ""
  echo -e "${CYellow}Uninstall Utility${CClear}"
  echo ""
  echo -e "${CCyan}You are about to uninstall KILLMON!  This action is irreversible."
  echo -e "${CCyan}Do you wish to proceed?${CClear}"
  if promptyn "(y/n): "; then
    echo ""
    echo -e "\n${CCyan}Are you sure? Please type 'Y' to validate you want to proceed.${CClear}"
      if promptyn "(y/n): "; then
        clear
        reverserules
        reverserules6
        if [ -f /jffs/scripts/firewall-start ]; then
          sed -i -e '/killmon.sh/d' /jffs/scripts/firewall-start
        fi
        rm -r /jffs/addons/killmon.d
        rm /jffs/scripts/killmon.sh
        echo ""
        echo -e "\n${CGreen}KILLMON has been uninstalled...${CClear}"
        echo ""
        exit 0
      else
        echo ""
        echo -e "\n${CGreen}Exiting Uninstall Utility...${CClear}"
        sleep 1
        return
      fi
  else
    echo ""
    echo -e "\n${CGreen}Exiting Uninstall Utility...${CClear}"
    sleep 1
    return
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# Save Config file

saveconfig () {

  { echo 'killswitchstatus="'"$killswitchstatus"'"' # ENABLED OR DISABLED
    echo 'killswitchautostart="'"$killswitchautostart"'"' # ENABLED OR DISABLED
    echo 'killswitchmode="'"$killswitchmode"'"' # PARANOID, IP RANGE, SINGLE IP OR INACTIVE
    echo 'killswitch6status="'"$killswitch6status"'"' # ENABLED OR DISABLED
    echo 'killswitch6mode="'"$killswitch6mode"'"' # PARANOID, IP RANGE, SINGLE IP, OR INACTIVE
    echo 'iprangenotation='$iprangenotation
    echo 'ip6rangenotation='$ip6rangenotation
    echo 'iprangecidr="'"$iprangecidr"'"' # Local IPv4 Subnet in CIDR
    echo 'ip6rangecidr="'"$ip6rangecidr"'"' # Local IPv6 Subnet in CIDR
    echo 'iprangefrom="'"$iprangefrom"'"' # Local IPv4 Subnet Start
    echo 'ip6rangefrom="'"$ip6rangefrom"'"' # Local IPv6 Subnet Start
    echo 'iprangeto="'"$iprangeto"'"' # Local IPv4 Subnet End
    echo 'ip6rangeto="'"$ip6rangeto"'"' # Local IPv6 Subnet End
    echo 'ipsingle="'"$ipsingle"'"'
    echo 'ip6single="'"$ip6single"'"'
    echo 'WANIFUSED='$WANIFUSED # 0=WAN0, 1=WAN1, OR 2=WAN0/1
    echo 'WAN0IFNAME="'"$WAN0IFNAME"'"'
    echo 'WAN1IFNAME="'"$WAN1IFNAME"'"'
  } > $CFGPATH

  echo ""
  echo -e "${CCyan}Applying config changes to KILLMON..."
  #echo -e "$(date) - KILLMON - Successfully wrote a new config file" >> $LOGFILE
  sleep 2

}

# -------------------------------------------------------------------------------------------------------------------------
# Begin Main Program
# -------------------------------------------------------------------------------------------------------------------------

#DEBUG=; set -x # uncomment/comment to enable/disable debug mode
#{              # uncomment/comment to enable/disable debug mode

# Create the necessary folder/file structure for KILLMON under /jffs/addons
if [ ! -d "/jffs/addons/killmon.d" ]; then
  mkdir -p "/jffs/addons/killmon.d"
fi

# Check for an AMTM Auto Update
if [ "$1" = "amtmupdate" ]
then
    shift
    ScriptUpdateFromAMTM "$@"
    exit "$?"
fi

# Check and see if any commandline option is being used
if [ $# -eq 0 ]
  then
    clear
    sh /jffs/scripts/killmon.sh -monitor
    exit 0
fi

# Check and see if an invalid commandline option is being used
if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "-log" ] || [ "$1" == "-setup" ] || [ "$1" == "-monitor" ] || [ "$1" == "-protect" ]
  then
    clear
  else
    clear
    echo ""
    echo "KILLMON v$Version"
    echo ""
    echo "Exiting due to invalid commandline options!"
    echo "(run 'killmon -h' for help)"
    echo ""
    echo -e "${CClear}"
    exit 0
fi

# Check to see if the help option is being called
if [ "$1" == "-h" ] || [ "$1" == "-help" ]
  then
  clear
  echo ""
  echo "KILLMON v$Version Commandline Option Usage:"
  echo ""
  echo "killmon -h | -help"
  echo "killmon -log"
  echo "killmon -setup"
  echo "killmon -monitor"
  echo "killmon -protect"
  echo ""
  echo " -h | -help (this output)"
  echo " -log (displays the event log)"
  echo " -setup (displays the setup menu)"
  echo " -monitor (displays status and operations page)"
  echo " -protect (populates iptables with kill switch rules)"
  echo ""
  echo -e "${CClear}"
  exit 0
fi

# Check to see if the log option is being called, and display through nano
if [ "$1" == "-log" ]
  then
    vlogs
    exit 0
fi

# Check to see if the populate option is being called
if [ "$1" == "-protect" ]
  then

    # Grab the config and read it in
    if [ -f $CFGPATH ]; then
      source $CFGPATH
    else
      clear
      echo -e "${CRed}ERROR: KILLMON is not configured.  Please run 'killmon.sh -setup' first."
      echo -e "$(date) - KILLMON ------> ERROR: KILLMON is not configured. Please run 'killmon.sh -setup' first." >> $LOGFILE
      echo -e "${CClear}"
      exit 0
    fi

    if [ -f "/opt/bin/timeout" ] # If the timeout utility is available then use it and assign variables
      then
        timeoutcmd="timeout "
        timeoutsec="10"
        timeoutlng="60"
      else
        timeoutcmd=""
        timeoutsec=""
        timeoutlng=""
    fi

    # Find the current WAN0/1 Interface Names
    WAN0IFNAME=$(get_wan_setting0 ifname)
    WAN1IFNAME=$(get_wan_setting1 ifname)

    # Determine if IPv6 is enabled
    if [ "$($timeoutcmd$timeoutsec nvram get ipv6_service)" = "disabled" ] ; then
      ipv6service=0
      killswitch6status="DISABLED"
    else
      ipv6service=1
    fi

    # Delete any possible previous rules
    if [ $ipv6service -eq 0 ]; then
      reverserules
    else
      reverserules
      reverserules6
    fi

    # Write the currently configured Kill Switch IP4 Rules to the iptables
    if [ "$killswitchstatus" == "ENABLED" ]; then
      if [ "$killswitchmode" == "PARANOID" ]; then
        paranoidmode
      elif [ "$killswitchmode" == "IP RANGE" ]; then
        iprangemode
      elif [ "$killswitchmode" == "SINGLEIP" ]; then
        singleipmode
      else
        clear
        echo -e "${CRed}ERROR: KILLMON is not configured.  Please run 'killmon.sh -setup' first."
        echo -e "$(date) - KILLMON ------> ERROR: KILLMON is not configured. Please run 'killmon.sh -setup'." >> $LOGFILE
        sleep 3
      fi
      echo -e "${CGreen}INFO: KILLMON applied IP4 kill switch rules on firewall-start/router restart."
      echo -e "$(date) - KILLMON - INFO: KILLMON applied IP4 kill switch rules on firewall-start/router restart." >> $LOGFILE
    else
      clear
      echo -e "${CRed}ERROR: KILLMON is not configured.  Please run 'killmon.sh -setup' first."
      echo -e "$(date) - KILLMON ------> ERROR: KILLMON is not configured. Please run 'killmon.sh -setup'." >> $LOGFILE
      sleep 3
    fi

    # Write the currently configured Kill Switch IP6 Rules to the iptables
    if [ $ipv6service -ne 0 ]; then
      if [ "$killswitch6status" == "ENABLED" ]; then
        if [ "$killswitch6mode" == "PARANOID" ]; then
          paranoidmode6
        elif [ "$killswitch6mode" == "IP RANGE" ]; then
          iprangemode6
        elif [ "$killswitch6mode" == "SINGLEIP" ]; then
          singleipmode6
        else
          clear
          echo -e "${CRed}ERROR: KILLMON is not configured.  Please run 'killmon.sh -setup' first."
          echo -e "$(date) - KILLMON ------> ERROR: KILLMON is not configured. Please run 'killmon.sh -setup'." >> $LOGFILE
          sleep 3
        fi
        echo -e "${CGreen} INFO: KILLMON applied IP6 kill switch rules on firewall-start/router restart."
        echo -e "$(date) - KILLMON - INFO: KILLMON applied IP6 kill switch rules on firewall-start/router restart." >> $LOGFILE
      else
        clear
        echo -e "${CRed} ERROR: KILLMON is not configured.  Please run 'killmon.sh -setup' first."
        echo -e "$(date) - KILLMON ------> ERROR: KILLMON is not configured. Please run 'killmon.sh -setup'." >> $LOGFILE
        sleep 3
      fi
    fi

    echo -e "${CClear}"
    exit 0
fi

# Check to see if the setup option is being called
if [ "$1" == "-setup" ]
  then
    vsetup
fi

# Check to see if the monitor option is being called
if [ "$1" == "-monitor" ]
  then
    # Check for and add an alias for KILLMON
    if ! grep -F "sh /jffs/scripts/killmon.sh" /jffs/configs/profile.add >/dev/null 2>/dev/null; then
  		echo "alias killmon=\"sh /jffs/scripts/killmon.sh\" # KILLMON" >> /jffs/configs/profile.add
    fi

    if [ -f "/opt/bin/timeout" ] # If the timeout utility is available then use it and assign variables
      then
        timeoutcmd="timeout "
        timeoutsec="10"
        timeoutlng="60"
      else
        timeoutcmd=""
        timeoutsec=""
        timeoutlng=""
    fi

    # Determine if IPv6 is enabled
    if [ "$($timeoutcmd$timeoutsec nvram get ipv6_service)" = "disabled" ]; then
      ipv6service=0
      killswitch6status="DISABLED"
    else
      ipv6service=1
    fi

    sleep 1
fi

while true; do

  if [ -f $CFGPATH ]; then
    source $CFGPATH
  fi

  # Check for Updates
  updatecheck

  WAN0IFNAME=$(get_wan_setting0 ifname)
  WAN1IFNAME=$(get_wan_setting1 ifname)

  clear
  logo
  if [ "$UpdateNotify" != "0" ]; then
    echo -e "${CRed} $UpdateNotify${CClear}"
    echo ""
  else
    echo ""
  fi
  echo -e "${InvDkGray}${CWhite}                               Status                                   ${CClear}"
  echo ""

  if [ $ipv6service -eq 0 ]; then
    if [ "$killswitchstatus" == "DISABLED" ]; then
      echo -e "${InvRed}    ${CClear}${CWhite}  IP4 Kill Switch    ${CClear}: ${InvRed}${CWhite}DISABLED ${CClear} | ${InvDkGray}    ${CClear}${CWhite} IP6 Protocol ${CClear}: ${InvDkGray}${CWhite}DISABLED ${CClear}"
    elif [ "$killswitchstatus" == "ENABLED" ]; then
      echo -e "${InvGreen}    ${CClear}${CWhite}  IP4 Kill Switch    ${CClear}: ${InvGreen}${CWhite}ENABLED  ${CClear} | ${InvDkGray}    ${CClear}${CWhite} IP6 Protocol ${CClear}: ${InvDkGray}${CWhite}DISABLED ${CClear}"
    fi
  else
    if [ "$killswitchstatus" == "DISABLED" ] && [ "$killswitch6status" == "DISABLED" ]; then
      echo -e "${InvRed}    ${CClear}${CWhite}  IP4 Kill Switch    ${CClear}: ${InvRed}${CWhite}DISABLED ${CClear} | ${InvRed}    ${CClear}${CWhite} IP6 Kill Switch ${CClear}: ${InvRed}${CWhite}DISABLED ${CClear}"
    elif [ "$killswitchstatus" == "ENABLED" ] && [ "$killswitch6status" == "DISABLED" ]; then
      echo -e "${InvGreen}    ${CClear}${CWhite}  IP4 Kill Switch    ${CClear}: ${InvGreen}${CWhite}ENABLED  ${CClear} | ${InvRed}    ${CClear}${CWhite} IP6 Kill Switch ${CClear}: ${InvRed}${CWhite}DISABLED ${CClear}"
    elif [ "$killswitchstatus" == "DISABLED" ] && [ "$killswitch6status" == "ENABLED" ]; then
      echo -e "${InvRed}    ${CClear}${CWhite}  IP4 Kill Switch    ${CClear}: ${InvRed}${CWhite}DISABLED ${CClear} | ${InvGreen}    ${CClear}${CWhite} IP6 Kill Switch ${CClear}: ${InvGreen}${CWhite}ENABLED  ${CClear}"
    elif [ "$killswitchstatus" == "ENABLED" ] && [ "$killswitch6status" == "ENABLED" ]; then
      echo -e "${InvGreen}    ${CClear}${CWhite}  IP4 Kill Switch    ${CClear}: ${InvGreen}${CWhite}ENABLED  ${CClear} | ${InvGreen}    ${CClear}${CWhite} IP6 Kill Switch ${CClear}: ${InvGreen}${CWhite}ENABLED  ${CClear}"
    fi
  fi

  if [ $ipv6service -eq 0 ]; then

    KILLMONRULESCHECK=$(iptables -L | grep -c "KILLMON")

    if [ $KILLMONRULESCHECK -eq 0 ]; then
      echo -e "${InvRed}    ${CClear}${CWhite}  iptables Rules     ${CClear}: ${InvRed}${CWhite}NOT FOUND${CClear} |"
    elif [ $KILLMONRULESCHECK -gt 0 ]; then
      echo -e "${InvGreen}    ${CClear}${CWhite}  iptables Rules     ${CClear}: ${InvGreen}${CWhite}VERIFIED ${CClear} |"
    fi

  else

    KILLMONRULESCHECK=$(iptables -L | grep -c "KILLMON")
    KILLMONRULES6CHECK=$(ip6tables -L | grep -c "KILLMON")

    if [ $KILLMONRULESCHECK -eq 0 ] && [ $KILLMONRULES6CHECK -eq 0 ]; then
      echo -e "${InvRed}    ${CClear}${CWhite}  iptables Rules     ${CClear}: ${InvRed}${CWhite}NOT FOUND${CClear} | ${InvRed}    ${CClear}${CWhite} ip6tables Rules ${CClear}: ${InvRed}${CWhite}NOT FOUND${CClear}"
    elif [ $KILLMONRULESCHECK -gt 0 ] && [ $KILLMONRULES6CHECK -eq 0 ]; then
      echo -e "${InvGreen}    ${CClear}${CWhite}  iptables Rules     ${CClear}: ${InvGreen}${CWhite}VERIFIED ${CClear} | ${InvRed}    ${CClear}${CWhite} ip6tables Rules ${CClear}: ${InvRed}${CWhite}NOT FOUND${CClear}"
    elif [ $KILLMONRULESCHECK -eq 0 ] && [ $KILLMONRULES6CHECK -gt 0 ]; then
      echo -e "${InvRed}    ${CClear}${CWhite}  iptables Rules     ${CClear}: ${InvRed}${CWhite}NOT FOUND${CClear} | ${InvGreen}    ${CClear}${CWhite} ip6tables Rules ${CClear}: ${InvGreen}${CWhite}VERIFIED ${CClear}"
    elif [ $KILLMONRULESCHECK -gt 0 ] && [ $KILLMONRULES6CHECK -gt 0 ]; then
      echo -e "${InvGreen}    ${CClear}${CWhite}  iptables Rules     ${CClear}: ${InvGreen}${CWhite}VERIFIED ${CClear} | ${InvGreen}    ${CClear}${CWhite} ip6tables Rules ${CClear}: ${InvGreen}${CWhite}VERIFIED ${CClear}"
    fi
  fi

    if [ "$killswitchautostart" == "DISABLED" ]; then
      echo -en "${InvRed}    ${CClear}${CWhite}  Reboot Protection  ${CClear}: "
      printf "${InvRed}${CWhite}DISABLED ${CClear} |"; printf "%s\n"
    else
      echo -en "${InvGreen}    ${CClear}${CWhite}  Reboot Protection  ${CClear}: "
      printf "${InvGreen}${CWhite}ENABLED  ${CClear} |"; printf "%s\n"
    fi

  echo -e "${CWhite}                     ${CClear}${CCyan}"

  if [ $ipv6service -eq 0 ]; then
    echo -e "${InvDkGray}${CWhite}    ${CClear}${CWhite}  IP4 Kill Mode      ${CClear}: ${CGreen}$killswitchmode${CClear}"
  else
    echo -e "${InvDkGray}${CWhite}    ${CClear}${CWhite}  IP4 Kill Mode      ${CClear}: ${CGreen}$killswitchmode${CClear}  | ${InvDkGray}${CWhite}    ${CClear}${CWhite} IP6 Kill Mode   ${CClear}: ${CGreen}$killswitch6mode${CClear}"
  fi

    echo ""
    echo -en "${InvDkGray}${CWhite}    ${CClear}${CWhite}  IP4(s) affected    ${CClear}: ${CGreen}"

    if [ $iprangenotation -eq 0 ] && [ "$killswitchmode" == "IP RANGE" ]; then
      printf $iprangecidr; printf "%s\n"
    elif [ $iprangenotation -eq 1 ] && [ "$killswitchmode" == "IP RANGE" ]; then
      printf $iprangefrom"-"$iprangeto; printf "%s\n"
    elif [ ! -z "$ipsingle" ] && [ "$killswitchmode" == "SINGLEIP" ]; then
      printf $ipsingle; printf "%s\n"
    elif [ "$killswitchmode" == "PARANOID" ]; then
      printf "ALL"; printf "%s\n"
    else
      printf "UNDEFINED"; printf "%s\n"
    fi

  if [ $ipv6service -ne 0 ]; then

    echo -en "${InvDkGray}${CWhite}    ${CClear}${CWhite}  IP6(s) affected    ${CClear}: ${CGreen}"

    if [ $ip6rangenotation -eq 0 ] && [ "$killswitch6mode" == "IP RANGE" ]; then
      printf "%.44s>\n" $iprangecidr
    elif [ $ip6rangenotation -eq 1 ] && [ "$killswitch6mode" == "IP RANGE" ]; then
      printf "%.44s>\n" $ip6rangefrom"-"$ip6rangeto
    elif [ ! -z "$ipsingle" ] && [ "$killswitch6mode" == "SINGLEIP" ]; then
      printf "%.44s>\n" $ip6single
    elif [ "$killswitch6mode" == "PARANOID" ]; then
      printf "ALL"; printf "%s\n"
    else
      printf "UNDEFINED"; printf "%s\n"
    fi

  fi

  echo -en "${InvDkGray}${CWhite}    ${CClear}${CWhite}  WAN IF(s) affected ${CClear}: ${CGreen}"

    if [ $WANIFUSED -eq 0 ]; then
      printf "WAN0 ($WAN0IFNAME)"; printf "%s\n"
    elif [ $WANIFUSED -eq 1 ]; then
      printf "WAN1 ($WAN1IFNAME)"; printf "%s\n"
    elif [ $WANIFUSED -eq 2 ]; then
      printf "WAN0/1 ($WAN0IFNAME/$WAN1IFNAME)"; printf "%s\n"
    fi

  echo -e "${CClear}"
  echo -e "${CGreen}------------------------------------------------------------------------"
  echo -e "${CGreen}Kill Switch Options ${CYellow}(sh)${CGreen}ow/${CYellow}(hi)${CGreen}de"
  echo -e "${CGreen}------------------------------------------------------------------------"

  if [ $hideoptions -eq 0 ]; then

    if [ $ipv6service -eq 0 ]; then
      echo -e "${InvDkGray}${CWhite} pm ${CClear}${CCyan}: Enable IP4 ${CGreen}Paranoid Mode${CClear}"
      echo -e "${InvDkGray}${CWhite} rm ${CClear}${CCyan}: Enable IP4 ${CGreen}Range Mode${CClear}"
      echo -e "${InvDkGray}${CWhite} sm ${CClear}${CCyan}: Enable IP4 ${CGreen}Single IP Mode${CClear}"
    else
      echo -e "${InvDkGray}${CWhite} pm ${CClear}${CCyan}: Enable IP4 ${CGreen}Paranoid Mode${CClear}       | ${InvDkGray}${CWhite} p6 ${CClear}${CCyan}: Enable IP6 ${CGreen}Paranoid Mode"
      echo -e "${InvDkGray}${CWhite} rm ${CClear}${CCyan}: Enable IP4 ${CGreen}Range Mode${CClear}          | ${InvDkGray}${CWhite} r6 ${CClear}${CCyan}: Enable IP6 ${CGreen}Range Mode"
      echo -e "${InvDkGray}${CWhite} sm ${CClear}${CCyan}: Enable IP4 ${CGreen}Single IP Mode${CClear}      | ${InvDkGray}${CWhite} s6 ${CClear}${CCyan}: Enable IP6 ${CGreen}Single IP Mode"
    fi

    echo -e "${InvDkGray}${CWhite}  | ${CClear}${CCyan}"
    echo -e "${InvDkGray}${CWhite} rr ${CClear}${CCyan}: Disable and Reverse ALL Kill Switch Rules from iptables"
    echo -e "${InvDkGray}${CWhite}  | ${CClear}${CCyan}"
    echo -en "${InvDkGray}${CWhite} r1 ${CClear}${CCyan}: Define IP4 Range ${CGreen}- "

      if [ $iprangenotation -eq 0 ]; then
        printf $iprangecidr; printf "%s\n"
      elif [ $iprangenotation -eq 1 ]; then
        printf $iprangefrom"-"$iprangeto; printf "%s\n"
      fi

    if [ $ipv6service -ne 0 ]; then
      echo -en "${InvDkGray}${CWhite} r2 ${CClear}${CCyan}: Define IP6 Range ${CGreen}- "

        if [ $ip6rangenotation -eq 0 ]; then
          printf "%.44s>\n" $ip6rangecidr
        elif [ $ip6rangenotation -eq 1 ]; then
          printf "%.44s>\n" $ip6rangefrom"-"$ip6rangeto
        fi
    fi

    echo -en "${InvDkGray}${CWhite} s1 ${CClear}${CCyan}: Define Single IP4 ${CGreen}- "

      if [ ! -z "$ipsingle" ]; then
        printf $ipsingle; printf "%s\n"
      fi

    if [ $ipv6service -ne 0 ]; then
      echo -en "${InvDkGray}${CWhite} s2 ${CClear}${CCyan}: Define Single IP6 ${CGreen}- "

        if [ ! -z "$ip6single" ]; then
          printf $ip6single; printf "%s\n"
        fi
    fi

    echo -en "${InvDkGray}${CWhite} w1 ${CClear}${CCyan}: Define affected WAN Interface(s) ${CGreen}- "

      if [ $WANIFUSED -eq 0 ]; then
        printf "WAN0 ($WAN0IFNAME)"; printf "%s\n"
      elif [ $WANIFUSED -eq 1 ]; then
        printf "WAN1 ($WAN1IFNAME)"; printf "%s\n"
      elif [ $WANIFUSED -eq 2 ]; then
        printf "WAN0/1 ($WAN0IFNAME/$WAN1IFNAME)"; printf "%s\n"
      fi

    echo -e "${InvDkGray}${CWhite}  | ${CClear}${CCyan}"
    echo -e "${InvDkGray}${CWhite} re ${CClear}${CCyan}: Enable/Disable Kill Switch Rules on Router/Firewall Restart"
    echo -e "${CGreen}------------------------------------------------------------------------"
  fi

  echo ""
  printf "Selection: "
  read -r Selection

  # Execute chosen selections
      case "$Selection" in

        sh) #Show Options
          hideoptions=0
        ;;

        hi) #Hide Options
          hideoptions=1
        ;;

        pm) # Paranoid Mode - all LAN traffic is forbidden to make it out to WAN
          reverserules
          paranoidmode
          killswitchstatus="ENABLED"
          killswitchmode="PARANOID"
          saveconfig
        ;;

        rm) # IP Range Mode - all LAN traffic in IP Range (CIDR) is forbidden to make it out to WAN
          reverserules
          iprangemode
          killswitchstatus="ENABLED"
          killswitchmode="IP RANGE"
          saveconfig
        ;;

        sm) # Single IP Mode - all LAN traffic from single IP is forbidden to make it out to WAN
          reverserules
          singleipmode
          killswitchstatus="ENABLED"
          killswitchmode="SINGLEIP"
          saveconfig
        ;;

        p6) # IP6 Paranoid Mode - all LAN traffic is forbidden to make it out to WAN
          reverserules6
          paranoidmode6
          killswitch6status="ENABLED"
          killswitch6mode="PARANOID"
          saveconfig
        ;;

        r6) # IP6 Range Mode - all LAN traffic in IP Range (CIDR) is forbidden to make it out to WAN
          reverserules6
          iprangemode6
          killswitch6status="ENABLED"
          killswitch6mode="IP RANGE"
          saveconfig
        ;;

        s6) # IP6 Single IP Mode - all LAN traffic from single IP is forbidden to make it out to WAN
          reverserules6
          singleipmode6
          killswitch6status="ENABLED"
          killswitch6mode="SINGLEIP"
          saveconfig
        ;;

        r1)
          echo ""
          echo -e "${CCyan}Would you like to use a CIDR notation to define your IP4 range"
          echo -e "${CCyan}(ex: 192.168.1.0/24), or would you like to specify a beginning"
          echo -e "${CCyan}and ending IP address that is in numerical sequence? (ex:"
          echo -e "${CCyan}192.168.1.50 - 192.168.1.60) Please note: This range of IP4"
          echo -e "${CCyan}addresses will be blocked from accessing the WAN connection."
          echo -e "${CYellow}(CIDR=0, IP Range=1 ... Default=1)${CClear}"
          read -p 'IP4 Range Notation: ' iprangenotation1
          iprangenotation2=$(echo $iprangenotation1 | tr '[0-1]')
          if [ -z "$iprangenotation1" ]; then iprangenotation=1; else iprangenotation=$iprangenotation2; fi

          echo ""
          if [ $iprangenotation -eq 0 ]; then
            echo -e "${CCyan}Please enter your IP4 Range that will be blocked from the"
            echo -e "${CCyan}WAN in CIDR notation. ${CYellow}(Current = $iprangecidr)${CClear}"
            echo -e "${CYellow}(Default = 192.168.1.0/24)${CClear}"
            read -p 'IP4 Range (CIDR): ' iprangecidr1
            if [ -z "$iprangecidr1" ]; then iprangecidr="192.168.1.0/24"; else iprangecidr=$iprangecidr1; fi
          elif [ $iprangenotation -eq 1 ]; then
            echo -e "${CCyan}Please enter your IP4 Range that will be blocked from the"
            echo -e "${CCyan}WAN using a starting and ending value that is in numerical"
            echo -e "${CCyan}sequence. ${CYellow}(Current = $iprangefrom - $iprangeto)${CClear}"
            echo -e "${CYellow}(Default start = 192.168.1.50, end = 192.168.1.60)${CClear}"
            read -p 'IP4 Range starting value: ' iprangefrom1
            if [ -z "$iprangefrom1" ]; then iprangefrom="192.168.1.50"; else iprangefrom=$iprangefrom1; fi
            read -p 'IP4 Range ending value: ' iprangeto1
            if [ -z "$iprangeto1" ]; then iprangeto="192.168.1.60"; else iprangeto=$iprangeto1; fi
          fi
          saveconfig
        ;;

        r2)
          echo ""
          echo -e "${CCyan}Would you like to use a CIDR notation to define your IP6 range"
          echo -e "${CCyan}(ex: 2601:04c1:417f:e91c:0000:0000:0000:0000/64), or would you"
          echo -e "${CCyan}like to specify a beginning and ending IP6 address that is in"
          echo -e "${CCyan}numerical sequence? (ex: 2601:04c1:417f:e91c:0000:0000:0000:0000-"
          echo -e "${CCyan}2601:04c1:417f:e91c:0000:0000:0000:000f) Please note: This range"
          echo -e "${CCyan}of IP6 addresses will be blocked from accessing the WAN connection."
          echo -e "${CYellow}(CIDR=0, IP Range=1 ... Default=1)${CClear}"
          read -p 'IP6 Range Notation: ' ip6rangenotation1
          ip6rangenotation2=$(echo $ip6rangenotation1 | tr '[0-1]')
          if [ -z "$ip6rangenotation1" ]; then ip6rangenotation=1; else ip6rangenotation=$ip6rangenotation2; fi

          echo ""
          if [ $ip6rangenotation -eq 0 ]; then
            echo -e "${CCyan}Please enter your IP6 Range that will be blocked from the"
            echo -e "${CCyan}WAN in CIDR notation."
            echo -e "${CYellow}(Current = $ip6rangecidr)${CClear}"
            echo -e "${CYellow}(Default = 2601:04c1:417f:e91c:0000:0000:0000:0000/64)${CClear}"
            read -p 'IP6 Range (CIDR): ' ip6rangecidr1
            if [ -z "$ip6rangecidr1" ]; then ip6rangecidr="2601:04c1:417f:e91c:0000:0000:0000:0000/64"; else ip6rangecidr=$ip6rangecidr1; fi
          elif [ $ip6rangenotation -eq 1 ]; then
            echo -e "${CCyan}Please enter your IP6 Range that will be blocked from the"
            echo -e "${CCyan}WAN using a starting and ending value that is in numerical"
            echo -e "${CCyan}sequence."
            echo -e "${CYellow}(Current start = $ip6rangefrom)${CClear}"
            echo -e "${CYellow}(Current end = $ip6rangeto)${CClear}"
            echo -e "${CYellow}(Default start = 2601:04c1:417f:e91c:0000:0000:0000:0000${CClear}"
            echo -e "${CYellow}(Default end = 2601:04c1:417f:e91c:0000:0000:0000:000f)${CClear}"
            read -p 'IP6 Range starting value: ' ip6rangefrom1
            if [ -z "$ip6rangefrom1" ]; then ip6rangefrom="2601:04c1:417f:e91c:0000:0000:0000:0000"; else ip6rangefrom=$ip6rangefrom1; fi
            read -p 'IP6 Range ending value: ' ip6rangeto1
            if [ -z "$ip6rangeto1" ]; then ip6rangeto="2601:04c1:417f:e91c:0000:0000:0000:000f"; else ip6rangeto=$ip6rangeto1; fi
          fi
          saveconfig
        ;;

        s1)
          echo ""
          echo -e "${CCyan}Please enter your Single IP4 Address that will be blocked from"
          echo -e "${CCyan}the WAN."
          echo -e "${CYellow}(Current = $ipsingle)${CClear}"
          echo -e "${CYellow}(Default = 192.168.1.150)${CClear}"
          read -p 'Single IP4: ' ipsingle1
          if [ -z "$ipsingle1" ]; then ipsingle="192.168.1.150"; else ipsingle=$ipsingle1; fi
          saveconfig
        ;;

        s2)
          echo ""
          echo -e "${CCyan}Please enter your Single IP6 Address that will be blocked from"
          echo -e "${CCyan}the WAN."
          echo -e "${CYellow}(Current = $ip6single)${CClear}"
          echo -e "${CYellow}(Default = fe80::92ca:faff:fe22:97bf)${CClear}"
          read -p 'Single IP6: ' ip6single1
          if [ -z "$ip6single1" ]; then ip6single="fe80::92ca:faff:fe22:97bf"; else ip6single=$ip6single1; fi
          saveconfig
        ;;

        w1)
          echo ""
          echo -e "${CCyan}Please enter your which WAN interfaces will be directly affected"
          echo -e "${CCyan}by the Kill Switch?"
          echo -e "${CYellow}(WAN0 = 0, WAN1 = 1, Both WAN0/1 = 2, Default = 0)${CClear}"
          read -p 'Select WAN Interface(s): ' WANIFUSED1
          WANIFUSED2=$(echo $WANIFUSED1 | tr '[0-2]')
          if [ -z "$WANIFUSED1" ]; then WANIFUSED=0; else WANIFUSED=$WANIFUSED2; fi
          saveconfig
        ;;

        rr)
          reverserules
          reverserules6
          killswitchstatus="DISABLED"
          killswitch6status="DISABLED"
          killswitchmode="INACTIVE"
          killswitch6mode="INACTIVE"
          saveconfig
        ;;

        re)
          if [ "$killswitchautostart" == "ENABLED" ]; then

            if [ -f /jffs/scripts/firewall-start ]; then
              sed -i -e '/killmon.sh/d' /jffs/scripts/firewall-start
              killswitchautostart="DISABLED"
            fi

          else

            if [ -f /jffs/scripts/firewall-start ]; then

              if ! grep -q -F "sh /jffs/scripts/killmon.sh -protect & # KillSwitch Monitor" /jffs/scripts/firewall-start; then
                echo "sh /jffs/scripts/killmon.sh -protect & # KillSwitch Monitor" >> /jffs/scripts/firewall-start
                killswitchautostart="ENABLED"
              else
                sed -i -e '/killmon.sh/d' /jffs/scripts/firewall-start
                killswitchautostart="DISABLED"
              fi

            else
              echo "#!/bin/sh" > /jffs/scripts/firewall-start
              echo "" >> /jffs/scripts/firewall-start
              echo "sh /jffs/scripts/killmon.sh -protect & # KillSwitch Monitor" >> /jffs/scripts/firewall-start
              chmod 0755 /jffs/scripts/firewall-start
              killswitchautostart="ENABLED"
            fi
          fi
          saveconfig
        ;;

        [Ss])
          (vsetup)
        ;;

        [Ii])
          clear
          logoNM
          echo ""
          echo -e "${CYellow}Instructions${CClear}" # Provide main setup menu
          echo ""
          echo -e "${CGreen}-------------------------------------------------------------------"
          echo -e "${CDkGray}KILLMON v$Version will write rules to your IP4 and IP6 iptables based"
          echo -e "on your specific preferences. In short, all traffic from your LAN"
          echo -e "(br0) to your WAN (eth*) is blocked in order to prevent leaks if"
          echo -e "your VPN connection happens to go down. There are 3 different"
          echo -e "modes that allow you to specify exactly which devices are blocked"
          echo -e "from your WAN connection, and would only be able to reach the"
          echo -e "internet through a valid VPN connection:"
          echo ""
          echo -e "${CCyan}Mode 1 - Paranoid:${CDkGray} This mode is the most restrictive, and will"
          echo -e "prevent ANY traffic going from your LAN to your WAN connections."
          echo -e "There are 0 exceptions."
          echo -e "${CCyan}Mode 2 - IP Range:${CDkGray} This mode allows you to specify an IP Range"
          echo -e "that is sequential, which would prevent any IP that falls on this"
          echo -e "range from reaching the WAN connection."
          echo -e "${CCyan}Mode 3 - Single IP:${CDkGray} This mode allows you to specify a single IP"
          echo -e "address that would be prevented from reaching the WAN connection"
          echo -e "when the VPN connection goes down."
          echo ""
          echo -e "Green ${InvGreen}  ${CClear}${CDkGray} or Red ${InvRed}  ${CClear}${CDkGray} boxes and indicators will present the current"
          echo -e "status of your KILLMON settings. It will further indicate if"
          echo -e "KILLMON rules were found in the IP4 and IP6 iptables. If these"
          echo -e "rules aren't present, then the killswitch will be ineffective."
          echo -e "It is important to keep an eye on this status on a regular basis."
          echo -e "KILLMON will also display the IPs and WAN interfaces affected by"
          echo -e "the rules."
          echo -e "${CGreen}-------------------------------------------------------------------${CDkGray}"
          echo ""
          read -rsp $'Press any key to continue...\n' -n1 key

        ;;

        [Ee])
          echo -e "${CClear}"
          exit 0
        ;;

        *)
          echo ""
          echo -e "Invalid choice - Please enter a valid option...${CClear}"
          echo ""
          sleep 2
        ;;

      esac
done

echo -e "${CClear}"
exit 0

#} #2>&1 | tee $LOG | logger -t $(basename $0)[$$]  # uncomment/comment to enable/disable debug mode
