#!/bin/sh

# RTRMON v0.1b - Asus-Merlin Router Monitor
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
Interval=30                         #How often would you like to refresh your screen?
MaxSpeedInet=1000                   #Max speed of your internet connection in Mbps
# -------------------------------------------------------------------------------------------------------------------------
# System Variables (Do not change beyond this point or this may change the programs ability to function correctly)
# -------------------------------------------------------------------------------------------------------------------------
Version="0.1b"
Beta=1
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
  echo -e "   / _, _/ / / / _, _/ /  / / /_/ / /|  /"
  echo -e "  /_/ |_| /_/ /_/ |_/_/  /_/\____/_/ |_/    ${CRed}(E)${CGreen}xit${CClear}"
}

# -------------------------------------------------------------------------------------------------------------------------

# Preparebar and Progressbar is a script that provides a nice progressbar to show script activity
preparebar() {
  # $1 - bar length
  # $2 - bar char
  printf "\n"
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

  if [ $1 -eq -1 ]; then
    printf "\r  $barspaces\r"
  else
    barch=$(($1*barlen/$2))
    barsp=$((barlen-barch))
    progr=$((100*$1/$2))

    if [ $5 == "Standard" ]; then
      if [ $progr -lt 60 ]; then
        printf "${CGreen}${3} [%.${barch}s%.${barsp}s]${CClear} ${CYellow}${InvBlue}${1}${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      elif [ $progr -gt 59 ] && [ $progr -lt 85 ]; then
        printf "${CYellow}${3} [%.${barch}s%.${barsp}s]${CClear} ${CYellow}${InvBlue}${1}${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      else
        printf "${CRed}${3} [%.${barch}s%.${barsp}s]${CClear} ${CYellow}${InvBlue}${1}${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      fi
    elif [ $5 == "Reverse" ]; then
      if [ $progr -lt 35 ]; then
        printf "${Red}${3} [%.${barch}s%.${barsp}s]${CClear} ${CYellow}${InvBlue}${1}${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      elif [ $progr -gt 35 ] && [ $progr -lt 85 ]; then
        printf "${CYellow}${3} [%.${barch}s%.${barsp}s]${CClear} ${CYellow}${InvBlue}${1}${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      else
        printf "${CGreen}${3} [%.${barch}s%.${barsp}s]${CClear} ${CYellow}${InvBlue}${1}${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
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
# $1 = i
TotalMem=$(top -n 1 | awk 'NR==1 {print $2, $4, $6, $8, $10} NR==2 {print $2, $4, $6, $8}' 2>/dev/null)

memused="$(echo $TotalMem | awk '{print $1}' | sed 's/K$//')"
memfree="$(echo $TotalMem | awk '{print $2}' | sed 's/K$//')"
memshrd="$(echo $TotalMem | awk '{print $3}' | sed 's/K$//')"
membuff="$(echo $TotalMem | awk '{print $4}' | sed 's/K$//')"
memcach="$(echo $TotalMem | awk '{print $5}' | sed 's/K$//')"
cpuusr="$(echo $TotalMem | awk '{print $6}' | sed 's/%$//' | cut -d . -f 1)"
cpusys="$(echo $TotalMem | awk '{print $7}' | sed 's/%$//' | cut -d . -f 1)"
cpunice="$(echo $TotalMem | awk '{print $8}' | sed 's/%$//' | cut -d . -f 1)"
cpuidle="$(echo $TotalMem | awk '{print $9}' | sed 's/%$//' | cut -d . -f 1)"

memused1=$(($memused1 + $memused))
memfree1=$(($memfree1 + $memfree))
memshrd1=$(($memshrd1 + $memshrd))
membuff1=$(($membuff1 + $membuff))
memcach1=$(($memcach1 + $memcach))
cpuusr1=$(($cpuusr1 + $cpuusr))
cpusys1=$(($cpusys1 + $cpusys))
cpunice1=$(($cpunice1 + $cpunice))
cpuidle1=$(($cpuidle1 + $cpuidle))

# Borrowed this wonderful keypress capturing mechanism from @Eibgrad... thank you! :)
key_press=''; read -rsn1 -t 1 key_press < "$(tty 0>&2)"

if [ $key_press ]; then
    case $key_press in
        [Ee]) echo -e "${CClear}"; exit 0;;
    esac
fi

}

# -------------------------------------------------------------------------------------------------------------------------
# Main RTRMON program starts here
# -------------------------------------------------------------------------------------------------------------------------

# Display the logo and indicator that stats are being gathered.
  clear
  logo
  echo ""
  echo -e " ${CGreen}[Initiating Boot Sequence - Gathering Initial Stats...]"

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

# Capture Traffic and store current WAN bytes stats
  WANIFNAME=$(get_wan_setting ifname)
  oldwanrxbytes="$(cat /sys/class/net/$WANIFNAME/statistics/rx_bytes)"
  oldwantxbytes="$(cat /sys/class/net/$WANIFNAME/statistics/tx_bytes)"

# Get initial TOP stats to average across the interval period
  preparebar 49 "|"
  i=0
  while [ $i -ne $Interval ]
    do
      i=$(($i+1))
      gettopstats $i
      progressbar $i $Interval "" "s" "Standard"
  done

clear

# -------------------------------------------------------------------------------------------------------------------------
# Main loop that performs all necessary calculations across the interval period
# -------------------------------------------------------------------------------------------------------------------------

while true; do
  logo

  # CPU - Usage
   if [ ! -z $cpuusr1 ]; then cpuusr1=$(($cpuusr1 / $Interval)); else cpuusr1=0; fi
   if [ ! -z $cpusys1 ]; then cpusys1=$(($cpusys1 / $Interval)); else cpusys1=0; fi
   if [ ! -z $cpunice1 ]; then cpunice1=$(($cpunice1 / $Interval)); else cpunice1=0; fi
   if [ ! -z $cpuidle1 ]; then cpuidle1=$(($cpuidle1 / $Interval)); else cpuidle1=0; fi

  # CPU - Temp - borrowed from @Maverickcdn - thank you!
    F_cputemp() { cut -c -2 < /sys/class/thermal/thermal_zone0/temp ;}   # function to check current CPU temp

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

  # Memory - NVRAM --  Many thanks to @RMerlin, @SomewhereOverTheRainbow and @Ranger802004 for your help on this
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
    w0temp=$(wl -i $ifname24 phy_tempsense | awk '{print $1 / 2 + 20}' | cut -d . -f 1)
    w1temp=$(wl -i $ifname5 phy_tempsense | awk '{print $1 / 2 + 20}' | cut -d . -f 1)

  # Network - WAN - Traffic
    WANIFNAME=$(get_wan_setting ifname)
    newwanrxbytes="$(cat /sys/class/net/$WANIFNAME/statistics/rx_bytes)"
    newwantxbytes="$(cat /sys/class/net//$WANIFNAME/statistics/tx_bytes)"

  # Network - Traffic - Calculations to find the difference between old and new total bytes send/received and divided to give Megabits
    diffwanrxbytes=$(awk -v new=$newwanrxbytes -v old=$oldwanrxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    diffwantxbytes=$(awk -v new=$newwantxbytes -v old=$oldwantxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')

  # Network - Traffic - Results are further divided by the timer/interval to give Megabits/sec
    wanrxmbrate=$(awk -v rb=$diffwanrxbytes -v intv=$Interval 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
    wantxmbrate=$(awk -v tb=$diffwantxbytes -v intv=$Interval 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)

  # ----------------------------------------------------------------------------------------------------------------------------------
  # Begin User Interface
  # ----------------------------------------------------------------------------------------------------------------------------------

  echo -e "${CGreen} ___${CClear}"
  echo -e "${CGreen}/${CRed}CPU${CClear}${CGreen}\_____________________________________________________________${CClear}"
  preparebar 38 "|"
  progressbar $cpuusr1 100 " CPU User  " "%%" "Standard"
  preparebar 38 "|"
  progressbar $cpusys1 100 " CPU System" "%%" "Standard"
  preparebar 38 "|"
  progressbar $cpunice1 100 " CPU Nice  " "%%" "Standard"
  preparebar 38 "|"
  progressbar $cpuidle1 100 " CPU Idle  " "%%" "Reverse"
  preparebar 38 "|"
  progressbar $(F_cputemp) 130 " CPU Temp  " "C" "Standard"
  echo ""
  echo -e "${CGreen} ______"
  echo -e "${CGreen}/${CRed}Memory${CClear}${CGreen}\__________________________________________________________${CClear}"
  preparebar 38 "|"
  progressbar $memused2 $totalmemory " Mem Used  " "MB" "Standard"
  preparebar 38 "|"
  progressbar $memfree2 $totalmemory " Mem Free  " "MB" "Standard"
  preparebar 38 "|"
  progressbar $memshrd2 $totalmemory " Mem Shared" "MB" "Standard"
  preparebar 38 "|"
  progressbar $membuff2 $totalmemory " Mem Buffer" "MB" "Standard"
  preparebar 38 "|"
  progressbar $memcach2 $totalmemory " Mem Cache " "MB" "Standard"
  preparebar 38 "|"
  progressbar $nvramused $totalnvram " NVRAM Used" "B" "Standard"
  echo ""
  echo -e "${CGreen} ____"
  echo -e "${CGreen}/${CRed}Disk${CClear}${CGreen}\____________________________________________________________${CClear}"
  preparebar 38 "|"
  progressbar $jffsused $jffstotal " JFFS Used " "MB" "Standard"
  preparebar 38 "|"
  progressbar $swapused $swaptotal " Swap Used " "MB" "Standard"
  echo ""
  echo -e "${CGreen} _______"
  echo -e "${CGreen}/${CRed}Network${CClear}${CGreen}\_________________________________________________________${CClear}"
  preparebar 38 "|"
  progressbar $wanrxmbrate $MaxSpeedInet " Avg WAN RX" "Mbps" "Standard"
  preparebar 38 "|"
  progressbar $wantxmbrate $MaxSpeedInet " Avg WAN TX" "Mbps" "Standard"
  #preparebar 38 "|"
  #progressbar $w0temp 130 " 2.4 Temp  " "C" "Standard"
  #preparebar 38 "|"
  #progressbar $w1temp 130 " 5.0 Temp  " "C" "Standard"

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

  # Get fresh WAN stats
  oldwanrxbytes="$(cat /sys/class/net/$WANIFNAME/statistics/rx_bytes)"
  oldwantxbytes="$(cat /sys/class/net/$WANIFNAME/statistics/tx_bytes)"

  # Run through the stats gathering loop based on the current interval
  echo ""
  preparebar 49 "|"
  i=0
  while [ $i -ne $Interval ]
    do
      i=$(($i+1))
      gettopstats $i
      progressbar $i $Interval "" "s" "Standard"
  done

  clear

done

exit 0
