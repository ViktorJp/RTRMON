#!/bin/sh

# RTRMON v0.1b3 - Asus-Merlin Router Monitor
# RTRMON is a shell script that provides near-realtime stats about your Asus-Merlin firmware router. Instead of having to
# find this information on various different screens or apps, this tool was built to bring all this info together in one
# stat dashboard.  Having a 'system' dashboard showing current CPU, Memory, Disk and Network stats would compiment other
# dashboard-like scripts greatly (like VPNMON-R2), sitting side-by-side in their own SSH windows to give you everything
# you need to know with a glance at your screen.
#
# This application is still under heavy development, so things may change, get added, deleted at anytime... please be
# aware this is BETA territory.

# -------------------------------------------------------------------------------------------------------------------------
# User-Defined Variables (Do not change beyond this point or this may change the programs ability to function correctly)
# -------------------------------------------------------------------------------------------------------------------------
Interval=10                         #How often would you like to refresh your screen?
MaxSpeedInet=1000                   #Max speed of your internet connection in Mbps
MaxSpeedLAN=1000                    #Max speed of your LAN switch (typically 1G or 2.5G)
MaxSpeed24Ghz=350                   #Max realistic speed of your 2.4Ghz wifi network in Mbps
MaxSpeed5Ghz=780                    #Max realistic speed of your 5Ghz wifi network in Mbps
# -------------------------------------------------------------------------------------------------------------------------
# System Variables (Do not change beyond this point or this may change the programs ability to function correctly)
# -------------------------------------------------------------------------------------------------------------------------
Version="0.1b3"
Beta=1
NextPage=1
memused1=0
memfree1=0
memshrd1=0
membuff1=0
memcach1=0
memused2=0
memfree2=0
memshrd2=0
membuff2=0
memcach2=0
cpuusr1=0
cpusys1=0
cpunice1=0
cpuidle1=0
displaycpuusr1=0
displaycpusys1=0
displaycpunice1=0
displaycpuidle1=0

# Color variables
CBlack="\e[1;30m"
InvBlack="\e[1;40m"
CRed="\e[1;31m"
InvRed="\e[1;41m"
CGreen="\e[1;32m"
InvGreen="\e[1;42m"
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

# Logo is a function that displays the VPNMON-R2 script name in a cool ASCII font
logo () {
  echo -e "${CYellow}      ____  __________  __  _______  _   __"
  echo -e "     / __ \/_  __/ __ \/  |/  / __ \/ | / /  ${CGreen}v$Version${CYellow}"
  echo -e "    / /_/ / / / / /_/ / /|_/ / / / /  |/ /"
  echo -e "   / _, _/ / / / _, _/ /  / / /_/ / /|  /   ${CRed}(N)${CGreen}ext Page ($NextPage/2)"
  echo -e "  /_/ |_| /_/ /_/ |_/_/  /_/\____/_/ |_/    ${CRed}(E)${CGreen}xit${CClear}"
}

# -------------------------------------------------------------------------------------------------------------------------

# Preparebar and Progressbar is a script that provides a nice progressbar to show script activity
preparebar() {
  # $1 - bar length
  # $2 - bar char
  #printf "\n"
  barlen=$1
  barspaces=$(printf "%*s" "$1")
  barchars=$(printf "%*s" "$1" | tr ' ' "$2")
}

# Had to make some mods to the variables being passed, and created an inverse colored progress bar
progressbar() {
  # $1 - number (-1 for clearing the bar)
  # $2 - max number
  # $3 - system name
  # $4 - measurement
  # $5 - standard/reverse progressbar
  insertspc=" "

  if [ $1 -eq -1 ]; then
    printf "\r  $barspaces\r"
  else
    barch=$(($1*barlen/$2))
    barsp=$((barlen-barch))
    progr=$((100*$1/$2))

    if [ ! -z $6 ]; then AltNum=$6; else AltNum=$1; fi

    if [ "$5" == "Standard" ]; then
      if [ $progr -lt 60 ]; then
        printf "${InvGreen}${CWhite}$insertspc${CClear}${CGreen}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      elif [ $progr -gt 59 ] && [ $progr -lt 85 ]; then
        printf "${InvYellow}${CBlack}$insertspc${CClear}${CYellow}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      else
        printf "${InvRed}${CWhite}$insertspc${CClear}${CRed}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      fi
    elif [ "$5" == "Reverse" ]; then
      if [ $progr -lt 35 ]; then
        printf "${InvRed}${CWhite}$insertspc${CClear}${CRed}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      elif [ $progr -gt 35 ] && [ $progr -lt 85 ]; then
        printf "${InvYellow}${CBlack}$insertspc${CClear}${CYellow}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      else
        printf "${InvGreen}${CWhite}$insertspc${CClear}${CGreen}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      fi
    fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# This function was "borrowed" graciously from @dave14305 from his FlexQoS script to determine the active WAN connection.
# Thanks much for your troubleshooting help as we tackled how to best derive the active WAN interface, Dave!
get_wan_setting() {
  local varname varval
  varname="${1}"
  prefixes="wan0_ wan1_"

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
# This function gathers the majority of cpu and memory related stats directly from the TOP utility
gettopstats () {

TotalMem=$(top -n 1 | awk 'NR==1 {print $2, $4, $6, $8, $10} NR==2 {print $2, $4, $6, $8} NR==3 {print $3, $4, $5}' 2>/dev/null)

memused="$(echo $TotalMem | awk '{print $1}' | sed 's/K$//')"
memfree="$(echo $TotalMem | awk '{print $2}' | sed 's/K$//')"
memshrd="$(echo $TotalMem | awk '{print $3}' | sed 's/K$//')"
membuff="$(echo $TotalMem | awk '{print $4}' | sed 's/K$//')"
memcach="$(echo $TotalMem | awk '{print $5}' | sed 's/K$//')"
cpuusr="$(echo $TotalMem | awk '{print $6}' | sed 's/%$//' | cut -d . -f 1)"
cpusys="$(echo $TotalMem | awk '{print $7}' | sed 's/%$//' | cut -d . -f 1)"
cpunice="$(echo $TotalMem | awk '{print $8}' | sed 's/%$//' | cut -d . -f 1)"
cpuidle="$(echo $TotalMem | awk '{print $9}' | sed 's/%$//' | cut -d . -f 1)"
displaycpuusr="$(echo $TotalMem | awk '{print $6}' | sed 's/%$//')"
displaycpusys="$(echo $TotalMem | awk '{print $7}' | sed 's/%$//')"
displaycpunice="$(echo $TotalMem | awk '{print $8}' | sed 's/%$//')"
displaycpuidle="$(echo $TotalMem | awk '{print $9}' | sed 's/%$//')"
cpuload1m="$(echo $TotalMem | awk '{print $10}')"
cpuload5m="$(echo $TotalMem | awk '{print $11}')"
cpuload15m="$(echo $TotalMem | awk '{print $12}')"

memused1=$(($memused1 + $memused))
memfree1=$(($memfree1 + $memfree))
memshrd1=$(($memshrd1 + $memshrd))
membuff1=$(($membuff1 + $membuff))
memcach1=$(($memcach1 + $memcach))
cpuusr1=$(($cpuusr1 + $cpuusr))
cpusys1=$(($cpusys1 + $cpusys))
cpunice1=$(($cpunice1 + $cpunice))
cpuidle1=$(($cpuidle1 + $cpuidle))
displaycpuusr1=$(awk -v v1=$displaycpuusr1 -v v2=$displaycpuusr 'BEGIN{printf "%0.2f\n", v1+v2}')
displaycpusys1=$(awk -v v1=$displaycpusys1 -v v2=$displaycpusys 'BEGIN{printf "%0.2f\n", v1+v2}')
displaycpunice1=$(awk -v v1=$displaycpunice1 -v v2=$displaycpunice 'BEGIN{printf "%0.2f\n", v1+v2}')
displaycpuidle1=$(awk -v v1=$displaycpuidle1 -v v2=$displaycpuidle 'BEGIN{printf "%0.2f\n", v1+v2}')

# Borrowed this wonderful keypress capturing mechanism from @Eibgrad... thank you! :)
key_press=''; read -rsn1 -t 1 key_press < "$(tty 0>&2)"

if [ $key_press ]; then
    case $key_press in
        [Nn]) if [ "$NextPage" == "1" ]; then NextPage=2; clear; DisplayPage2; echo -e "\n"; elif [ "$NextPage" == "2" ]; then NextPage=1; clear; DisplayPage1; echo -e "\n"; fi;;
        [Ee]) echo -e "${CClear}"; exit 0;;
    esac
fi

}

# -------------------------------------------------------------------------------------------------------------------------
# This function holds the old (current) stats that are being used to display stats on-screen
oldstats () {

  oldcpuusr1=$cpuusr1
  oldcpusys1=$cpusys1
  oldcpunice1=$cpunice1
  oldcpuidle1=$cpuidle1
  olddisplaycpuusr1=$displaycpuusr1
  olddisplaycpusys1=$displaycpusys1
  olddisplaycpunice1=$displaycpunice1
  olddisplaycpuidle1=$displaycpuidle1
  oldF_cputemp=$F_cputemp
  oldmemused2=$memused2
  oldmemfree2=$memfree2
  oldmemshrd2=$memshrd2
  oldmembuff2=$membuff2
  oldmemcach2=$memcach2
  oldtotalmemory=$totalmemory
  oldnvramfree=$nvramfree
  oldnvramused=$nvramused
  oldtotalnvram=$totalnvram
  oldjffstotal=$jffstotal
  oldjffsused=$jffsused
  oldswaptotal=$swaptotal
  oldswapused=$swapused
  oldwanrxmbrate=$wanrxmbrate
  oldwantxmbrate=$wantxmbrate
  oldw24rxmbrate=$w24rxmbrate
  oldw24txmbrate=$w24txmbrate
  oldw5rxmbrate=$w5rxmbrate
  oldw5txmbrate=$w5txmbrate
  oldw0temp=$w0temp
  oldw1temp=$w1temp
  oldlanrxmbrate=$lanrxmbrate
  oldlantxmbrate=$lantxmbrate

}

# -------------------------------------------------------------------------------------------------------------------------
# This function calculates all current stats
calculatestats () {

  RM_END_TIME=$(date +%s)
  RM_ELAPSED_TIME=$(( RM_END_TIME - RM_START_TIME ))

  # CPU - Usage
   if [ ! -z $cpuusr1 ]; then cpuusr1=$(($cpuusr1 / $Interval)); else cpuusr1=0; fi
   if [ ! -z $cpusys1 ]; then cpusys1=$(($cpusys1 / $Interval)); else cpusys1=0; fi
   if [ ! -z $cpunice1 ]; then cpunice1=$(($cpunice1 / $Interval)); else cpunice1=0; fi
   if [ ! -z $cpuidle1 ]; then cpuidle1=$(($cpuidle1 / $Interval)); else cpuidle1=0; fi
   if [ ! -z $displaycpuusr1 ]; then displaycpuusr1=$(awk -v rb=$displaycpuusr1 -v intv=$Interval 'BEGIN{printf "%0.2f\n", rb/intv}'); else displaycpuusr1=0; fi
   if [ ! -z $displaycpusys1 ]; then displaycpusys1=$(awk -v rb=$displaycpusys1 -v intv=$Interval 'BEGIN{printf "%0.2f\n", rb/intv}'); else displaycpusys1=0; fi
   if [ ! -z $displaycpunice1 ]; then displaycpunice1=$(awk -v rb=$displaycpunice1 -v intv=$Interval 'BEGIN{printf "%0.2f\n", rb/intv}'); else displaycpunice1=0; fi
   if [ ! -z $displaycpuidle1 ]; then displaycpuidle1=$(awk -v rb=$displaycpuidle1 -v intv=$Interval 'BEGIN{printf "%0.2f\n", rb/intv}'); else displaycpuidle1=0; fi

  # CPU - Temp - borrowed from @Maverickcdn - thank you!
    F_cputemp=$(cat /sys/class/thermal/thermal_zone0/temp | cut -c -2)

  # Memory - Usage
    if [ ! -z $memused1 ]; then memused1=$(($memused1 / $Interval)); else memused1=0; fi
    if [ ! -z $memfree1 ]; then memfree1=$(($memfree1 / $Interval)); else memfree1=0; fi
    if [ ! -z $memshrd1 ]; then memshrd1=$(($memshrd1 / $Interval)); else memshrd1=0; fi
    if [ ! -z $membuff1 ]; then membuff1=$(($membuff1 / $Interval)); else membuff1=0; fi
    if [ ! -z $memcach1 ]; then memcach1=$(($memcach1 / $Interval)); else memcach1=0; fi

    memused2=$(($memused1 / 1024 ))
    memfree2=$(($memfree1 / 1024 ))
    memshrd2=$(($memshrd1 / 1024 ))
    membuff2=$(($membuff1 / 1024 ))
    memcach2=$(($memcach1 / 1024 ))
    totalmemory=$((($memused1 + $memfree1) / 1024 ))

  # Memory - NVRAM --  Many thanks to @RMerlin, @SomewhereOverTheRainbow and @Ranger802004 for your help finding NVRAM stats
    nvram show >/tmp/output.txt 2> /tmp/size.txt
    chmod 755 /tmp/size.txt
    nvramtotals=$(awk '{print $2, $4}' /tmp/size.txt 2>/dev/null)
    nvramused="$(echo $nvramtotals | awk '{print $1}')"
    nvramfree="$(echo $nvramtotals | awk '{print $2}' | sed 's/[)(]//g')"
    totalnvram=$(($nvramused + $nvramfree))

  # Disk - JFFS
    disk_use=$(df -P | grep /dev | grep -v -E '(tmp|boot)' | awk '{print $2, $3}')
    jffstotal="$(echo $disk_use | awk '{print $1}')"
    jffsused="$(echo $disk_use | awk '{print $2}')"
    jffstotal="$(($jffstotal / 1024))"
    jffsused="$(($jffsused / 1024))"

  # Disk - Swap file
    swap_use=$(free | awk 'NR==4 {print $2, $3}' 2>/dev/null)
    swaptotal="$(echo $swap_use | awk '{print $1}')"
    swapused="$(echo $swap_use | awk '{print $2}')"
    swaptotal="$(($swaptotal / 1024))"
    swapused="$(($swapused / 1024))"

  # Network - Wifi - Temp
    ifname24=$($timeoutcmd$timeoutsec nvram get wl0_ifname)
    ifname5=$($timeoutcmd$timeoutsec nvram get wl1_ifname)
    w0tempraw=$(wl -i $ifname24 phy_tempsense | awk '{print $1}' )
    w1tempraw=$(wl -i $ifname5 phy_tempsense | awk '{print $1}' )
    if [ -z $w0tempraw ] || [ $w0tempraw -eq 0 ]; then w0tempraw=4; fi  #in case it does not return a valid number
    if [ -z $w1tempraw ] || [ $w1tempraw -eq 0 ]; then w1tempraw=4; fi
    w0temp=$(awk -v v1=$w0tempraw 'BEGIN{printf "\n" (v1/2)+20}' | cut -d . -f 1)
    w1temp=$(awk -v v1=$w1tempraw 'BEGIN{printf "\n" (v1/2)+20}' | cut -d . -f 1)

  # Network - Wifi - Traffic
    ifname24=$($timeoutcmd$timeoutsec nvram get wl0_ifname)
    ifname5=$($timeoutcmd$timeoutsec nvram get wl1_ifname)
    new24rxbytes="$(cat /sys/class/net/$ifname24/statistics/rx_bytes)"
    new24txbytes="$(cat /sys/class/net/$ifname24/statistics/tx_bytes)"
    new5rxbytes="$(cat /sys/class/net/$ifname5/statistics/rx_bytes)"
    new5txbytes="$(cat /sys/class/net/$ifname5/statistics/tx_bytes)"

  # Network - LAN - Traffic
    newlanrxbytes="$(cat /sys/class/net/br0/statistics/rx_bytes)"
    newlantxbytes="$(cat /sys/class/net/br0/statistics/tx_bytes)"

  # Network - WAN - Traffic
    WANIFNAME=$(get_wan_setting ifname)
    newwanrxbytes="$(cat /sys/class/net/$WANIFNAME/statistics/rx_bytes)"
    newwantxbytes="$(cat /sys/class/net/$WANIFNAME/statistics/tx_bytes)"

  # Network - Traffic - Calculations to find the difference between old and new total bytes send/received and divided to give Megabits
    diffwanrxbytes=$(awk -v new=$newwanrxbytes -v old=$oldwanrxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    diffwantxbytes=$(awk -v new=$newwantxbytes -v old=$oldwantxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    diff24rxbytes=$(awk -v new=$new24rxbytes -v old=$old24rxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    diff24txbytes=$(awk -v new=$new24txbytes -v old=$old24txbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    diff5rxbytes=$(awk -v new=$new5rxbytes -v old=$old5rxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    diff5txbytes=$(awk -v new=$new5txbytes -v old=$old5txbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    difflanrxbytes=$(awk -v new=$newlanrxbytes -v old=$oldlanrxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    difflantxbytes=$(awk -v new=$newlantxbytes -v old=$oldlantxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')

  # Network - Traffic - Results are further divided by the timer/interval to give Megabits/sec
    wanrxmbrate=$(awk -v rb=$diffwanrxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
    wantxmbrate=$(awk -v tb=$diffwantxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    w24rxmbrate=$(awk -v rb=$diff24rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
    w24txmbrate=$(awk -v tb=$diff24txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    w5rxmbrate=$(awk -v rb=$diff5rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
    w5txmbrate=$(awk -v tb=$diff5txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    lanrxmbrate=$(awk -v rb=$difflanrxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
    lantxmbrate=$(awk -v tb=$difflantxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)

}

# -------------------------------------------------------------------------------------------------------------------------
# This function displays the stats on page 1
DisplayPage1 () {
  logo
  echo -e "${CGreen} ___${CClear}"
  echo -e "${CGreen}/${CRed}CPU${CClear}${CGreen}\_____________________________________________________________${CClear}"
  echo ""
  echo -e "  ${CCyan}CPU Load   ${CGreen}[   1m: ${CCyan}$cpuload1m  ${CGreen}5m: ${CCyan}$cpuload5m  ${CGreen}15m: ${CCyan}$cpuload15m${CGreen}   ]"
  preparebar 35 "|"
  progressbar $oldcpuusr1 100 " CPU User  " "%%" "Standard" $olddisplaycpuusr1
  echo ""
  preparebar 35 "|"
  progressbar $oldcpusys1 100 " CPU System" "%%" "Standard" $olddisplaycpusys1
  echo ""
  preparebar 35 "|"
  progressbar $oldcpunice1 100 " CPU Nice  " "%%" "Standard" $olddisplaycpunice1
  echo ""
  preparebar 35 "|"
  progressbar $oldcpuidle1 100 " CPU Idle  " "%%" "Reverse" $olddisplaycpuidle1
  echo ""
  preparebar 35 "|"
  progressbar $oldF_cputemp 130 " CPU Temp  " "C" "Standard"
  echo ""
  echo -e "${CGreen} ______"
  echo -e "${CGreen}/${CRed}Memory${CClear}${CGreen}\__________________________________________________________${CClear}"
  echo ""
  preparebar 35 "|"
  progressbar $oldmemused2 $oldtotalmemory " Mem Used  " "MB" "Standard"
  echo ""
  preparebar 35 "|"
  progressbar $oldmemfree2 $oldtotalmemory " Mem Free  " "MB" "Standard"
  echo ""
  preparebar 35 "|"
  progressbar $oldmemshrd2 $oldtotalmemory " Mem Shared" "MB" "Standard"
  echo ""
  preparebar 35 "|"
  progressbar $oldmembuff2 $oldtotalmemory " Mem Buffer" "MB" "Standard"
  echo ""
  preparebar 35 "|"
  progressbar $oldmemcach2 $oldtotalmemory " Mem Cache " "MB" "Standard"
  echo ""
  preparebar 35 "|"
  progressbar $oldnvramused $oldtotalnvram " NVRAM Used" "B" "Standard"
  echo ""
  echo -e "${CGreen} ____"
  echo -e "${CGreen}/${CRed}Disk${CClear}${CGreen}\____________________________________________________________${CClear}"
  echo ""
  preparebar 35 "|"
  progressbar $oldjffsused $oldjffstotal " JFFS Used " "MB" "Standard"
  echo ""
  preparebar 35 "|"
  progressbar $oldswapused $oldswaptotal " Swap Used " "MB" "Standard"
}

# -------------------------------------------------------------------------------------------------------------------------
# This function displays the stats on page 2
DisplayPage2 () {
  logo
  echo -e "${CGreen} ___"
  echo -e "${CGreen}/${CRed}WAN${CClear}${CGreen}\_____________________________________________________________${CClear}"
  echo ""
  preparebar 35 "|"
  progressbar $oldwanrxmbrate $MaxSpeedInet " Avg WAN RX" "Mbps" "Standard"
  echo ""
  preparebar 35 "|"
  progressbar $oldwantxmbrate $MaxSpeedInet " Avg WAN TX" "Mbps" "Standard"
  echo ""
  echo -e "${CGreen} ___"
  echo -e "${CGreen}/${CRed}LAN${CClear}${CGreen}\_____________________________________________________________${CClear}"
  echo ""
  preparebar 35 "|"
  progressbar $oldlanrxmbrate $MaxSpeedLAN " Avg LAN RX" "Mbps" "Standard"
  echo ""
  preparebar 35 "|"
  progressbar $oldlantxmbrate $MaxSpeedLAN " Avg LAN TX" "Mbps" "Standard"
  echo ""
  echo -e "${CGreen} ____"
  echo -e "${CGreen}/${CRed}WiFi${CClear}${CGreen}\____________________________________________________________${CClear}"
  echo ""
  preparebar 35 "|"
  progressbar $oldw24rxmbrate $MaxSpeed24Ghz " Avg 24G RX" "Mbps" "Standard"
  echo ""
  preparebar 35 "|"
  progressbar $oldw24txmbrate $MaxSpeed24Ghz " Avg 24G TX" "Mbps" "Standard"
  echo ""
  preparebar 35 "|"
  progressbar $oldw0temp 130 " 2.4G Temp " "C" "Standard"
  echo ""
  preparebar 35 "|"
  progressbar $oldw5rxmbrate $MaxSpeed24Ghz " Avg 50G RX" "Mbps" "Standard"
  echo ""
  preparebar 35 "|"
  progressbar $oldw5txmbrate $MaxSpeed24Ghz " Avg 50G TX" "Mbps" "Standard"
  echo ""
  preparebar 35 "|"
  progressbar $oldw1temp 130 " 5.0G Temp " "C" "Standard"
}

# -------------------------------------------------------------------------------------------------------------------------
# Main RTRMON program starts here
# -------------------------------------------------------------------------------------------------------------------------

#DEBUG=; set -x # uncomment/comment to enable/disable debug mode
#{

# Display the logo and indicator that stats are being gathered.
  clear
  logo
  echo ""
  echo -e "  ${CGreen}[Initiating Boot Sequence - Gathering Initial Stats...]"
  echo ""

# If the timeout command is available, use it, because there's tons of NVRAM calls here that can hang your script! :(
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

# Capture Traffic and store current WAN/WiFi bytes stats
  WANIFNAME=$(get_wan_setting ifname)
  oldwanrxbytes="$(cat /sys/class/net/$WANIFNAME/statistics/rx_bytes)"
  oldwantxbytes="$(cat /sys/class/net/$WANIFNAME/statistics/tx_bytes)"

  ifname24=$($timeoutcmd$timeoutsec nvram get wl0_ifname)
  ifname5=$($timeoutcmd$timeoutsec nvram get wl1_ifname)
  old24rxbytes="$(cat /sys/class/net/$ifname24/statistics/rx_bytes)"
  old24txbytes="$(cat /sys/class/net/$ifname24/statistics/tx_bytes)"
  old5rxbytes="$(cat /sys/class/net/$ifname5/statistics/rx_bytes)"
  old5txbytes="$(cat /sys/class/net/$ifname5/statistics/tx_bytes)"

  oldlanrxbytes="$(cat /sys/class/net/br0/statistics/rx_bytes)"
  oldlantxbytes="$(cat /sys/class/net/br0/statistics/tx_bytes)"

# Get initial TOP stats to average across the interval period

  RM_ELAPSED_TIME=0
  RM_START_TIME=$(date +%s)
  i=0
  while [ $i -ne $Interval ]
    do
      i=$(($i+1))
      gettopstats $i
      preparebar 53 "|"
      progressbar $i $Interval "" "s" "Standard"
  done

calculatestats
oldstats
clear

# -------------------------------------------------------------------------------------------------------------------------
# Main loop that calls functions to perform all necessary calculations across the interval period
# -------------------------------------------------------------------------------------------------------------------------

while true; do

  # ----------------------------------------------------------------------------------------------------------------------------------
  # Begin User Interface
  # ----------------------------------------------------------------------------------------------------------------------------------

  if [ "$NextPage" == "1" ]; then
    clear
    DisplayPage1
    echo ""
  elif [ "$NextPage" == "2" ]; then
    clear
    DisplayPage2
    echo ""
  fi

  # Reset stats after the UI has finished drawing
  memused1=0
  memfree1=0
  memshrd1=0
  membuff1=0
  memcach1=0
  memused2=0
  memfree2=0
  memshrd2=0
  membuff2=0
  memcach2=0
  cpuusr1=0
  cpusys1=0
  cpunice1=0
  cpuidle1=0
  displaycpuusr1=0
  displaycpusys1=0
  displaycpunice1=0
  displaycpuidle1=0

  # Get fresh WAN stats
  oldwanrxbytes="$(cat /sys/class/net/$WANIFNAME/statistics/rx_bytes)"
  oldwantxbytes="$(cat /sys/class/net/$WANIFNAME/statistics/tx_bytes)"
  old24rxbytes="$(cat /sys/class/net/$ifname24/statistics/rx_bytes)"
  old24txbytes="$(cat /sys/class/net/$ifname24/statistics/tx_bytes)"
  old5rxbytes="$(cat /sys/class/net/$ifname5/statistics/rx_bytes)"
  old5txbytes="$(cat /sys/class/net/$ifname5/statistics/tx_bytes)"
  oldlanrxbytes="$(cat /sys/class/net/br0/statistics/rx_bytes)"
  oldlantxbytes="$(cat /sys/class/net/br0/statistics/tx_bytes)"

  # Run through the stats gathering loop based on the current interval
  echo ""
  RM_ELAPSED_TIME=0
  RM_START_TIME=$(date +%s)
  i=0
  while [ $i -ne $Interval ]
    do
      i=$(($i+1))
      gettopstats $i
      preparebar 46 "|"
      progressbar $i $Interval "" "s" "Standard"
  done

  # Do a fresh round of stats and save them to the old stats for display purposes
  calculatestats
  oldstats
  clear

done

exit 0

#} #2>&1 | tee $LOG | logger -t $(basename $0)[$$]  # uncomment/comment to enable/disable debug mode
