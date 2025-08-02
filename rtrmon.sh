#!/bin/sh

# RTRMON - Asus-Merlin Router Monitor by Viktor Jaep, 2022-2025
#
# RTRMON is a shell script that provides near-realtime stats about your Asus-Merlin firmware router. Instead of having to
# find this information on various different screens or apps, this tool was built to bring all this info together in one
# stat dashboard.  Having a 'system' dashboard showing current CPU, Memory, Disk and Network stats would compiment other
# dashboard-like scripts greatly (like RTRMON), sitting side-by-side in their own SSH windows to give you everything
# you need to know that's happening on your network with a glance at your screen.
#
# Capabilities have been added to give a full view of your router's CPU, Memory, Disk, NVRAM, Swap file, WAN, LAN, Wi-FI,
# IP4/6 addresses, CPU/Antenna Temps, in addition to having incorporated the Ookla Speedtest Binaries for you to run an on
# -demand Speedtest with the press of a button. New supported models are continually being added as @RMerlin adds support
# for them with his own firmware.
#
# Please use the 'sh rtrmon.sh -setup' command to configure the necessary parameters that match your environment the best!
#
# Last Modified: 2025-Aug-2
###########################################################################################################################

#Preferred standard router binaries path
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:$PATH"

# -------------------------------------------------------------------------------------------------------------------------
# System Variables (Do not change beyond this point or this may change the programs ability to function correctly)
# -------------------------------------------------------------------------------------------------------------------------
Version="2.2.03b"
Beta=1
ScreenshotMode=0
LOGFILE="/jffs/addons/rtrmon.d/rtrmon.log"            # Logfile path/name that captures important date/time events - change
APPPATH="/jffs/scripts/rtrmon.sh"                     # Path to the location of rtrmon.sh
CFGPATH="/jffs/addons/rtrmon.d/rtrmon.cfg"            # Path to the location of rtrmon.cfg
DLVERPATH="/jffs/addons/rtrmon.d/version.txt"         # Path to downloaded version from the source repository
OOKLAPATH="/jffs/addons/rtrmon.d/speedtest"           # Path to Ookla speedtest binary
SPDRESPATH="/jffs/addons/rtrmon.d/results.txt"        # Path to latest speedtest results
IFLIST="/jffs/addons/rtrmon.d/interfaces.txt"         # Path to the Interface List
DIAGRESPATH="/jffs/addons/rtrmon.d/diagres.txt"       # Path to the network diagnostics results
NMAPWANRESPATH="/jffs/addons/rtrmon.d/nwanres.txt"    # Path to the nmap WAN open TCP port results
NMAPLANRESPATH="/jffs/addons/rtrmon.d/nlanres.txt"    # Path to the nmap LAN open TCP port results
NMAPUWANRESPATH="/jffs/addons/rtrmon.d/nuwanres.txt"  # Path to the nmap WAN open UDP port results
NMAPULANRESPATH="/jffs/addons/rtrmon.d/nulanres.txt"  # Path to the nmap LAN open UDP port results
INITIALBOOT=0
CHANGES=0
LOGSIZE=2000
Interval=10
MaxSpeedInet=1000
MaxSpeedInetUL=50
MaxSpeedLAN=1000
MaxSpeed24Ghz=450
MaxSpeed5Ghz=780
MaxSpeed6Ghz=920
TempUnits="C"
Speedtst=0
WANOverride="Auto"
WAN0AltModes=0
VPNSite2Site=0
PSView="TCP"
NCView="WAN"
spdtestsvrID=0
autorotate=0
autorotateindicator="OFF"
QueueSpdTest=0
QueueNetworkDiag=0
QueueNetworkConn=0
QueueVPNSlot1=0
QueueVPNSlot2=0
QueueVPNSlot3=0
QueueVPNSlot4=0
QueueVPNSlot5=0
QueueWGlot1=0
QueueWGSlot2=0
QueueWGSlot3=0
QueueWGSlot4=0
QueueWGSlot5=0
vpn1slot=0
vpn2slot=0
vpn3slot=0
vpn4slot=0
vpn5slot=0
VPNState=0
VPN2State=0
VPN3State=0
VPN4State=0
VPN5State=0
vpncity="Unknown"
vpn2city="Unknown"
vpn3city="Unknown"
vpn4city="Unknown"
vpn5city="Unknown"
vpnip="0.0.0.0"
vpn2ip="0.0.0.0"
vpn3ip="0.0.0.0"
vpn4ip="0.0.0.0"
vpn5ip="0.0.0.0"
vpn1on="False"
vpn2on="False"
vpn3on="False"
vpn4on="False"
vpn5on="False"
wg1on="False"
wg2on="False"
wg3on="False"
wg4on="False"
wg5on="False"
FromUI=0
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
cpuirq1=0
displaycpuusr1=0
displaycpusys1=0
displaycpunice1=0
displaycpuidle1=0
displaycpuirq1=0
w24udsched="Scheduler Inactive"
w5udsched="Scheduler Inactive"
w52udsched="Scheduler Inactive"
w6udsched="Scheduler Inactive"
w62udsched="Scheduler Inactive"
w24updown="UP"
w5updown="UP"
w52updown="UP"
w6updown="UP"
w62updown="UP"
SortbyOpt="Name"

##-------------------------------------##
## Added by Martinski W. [2024-Nov-04] ##
##-------------------------------------##
timerReset=0
timeoutcmd=""       # For "timeout" cmd for "nvram" calls #
timeoutsec=""       # For "timeout" cmd for "nvram" calls #
timeoutlng=""       # For "timeout" cmd for "nvram" calls #
hideoptions=1       # Hide/Show menu options flag #
prevHideOpts=X      # Avoid redisplaying the options menu unnecessarily too often #
prevSortByOpt=X     # Avoid resetting the timer loop unnecessarily too often #
bootInterval=10     # For "Boot Sequence" loop #
LAN_HostName=""
readonly gSavedSTTY="$(stty -g)"

##-------------------------------------##
## Added by Martinski W. [2024-Nov-05] ##
##-------------------------------------##
pausedTimerEnabled=false  # To pause/resume main loop timer cycle #
pausedTimerDispStr=""
readonly pausedTimerMsgStr=" [** PAUSED **] "
readonly pausedTimerMsgLen="${#pausedTimerMsgStr}"

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

#Shows the version bar formatted for build and date/time with TZ spacing#
##----------------------------------------##
## Modified by Martinski W. [2024-Nov-04] ##
##----------------------------------------##
showheader()
{
  if [ "$hideoptions" = "0" ] && [ "$hideoptions" != "$prevHideOpts" ]
  then displayopsmenu ; fi

  timerReset=0
  prevHideOpts="$hideoptions"
  prevSortByOpt="$SortbyOpt"

  tzone="$(date +%Z)"
  tzonechars="${#tzone}"

  if   [ "$tzonechars" = "1" ]; then tzspaces="        ";
  elif [ "$tzonechars" = "2" ]; then tzspaces="       ";
  elif [ "$tzonechars" = "3" ]; then tzspaces="      ";
  elif [ "$tzonechars" = "4" ]; then tzspaces="     ";
  elif [ "$tzonechars" = "5" ]; then tzspaces="    "; fi

  #Display RTRMON client header
  echo -en "${InvGreen} ${InvDkGray}${CWhite} RTRMON - v"
  printf "%-8s" $Version
  echo -e "                  ${CGreen}(S)${CWhite}how/${CGreen}(H)${CWhite}ide Operations Menu ${InvDkGray}        $tzspaces$(date) ${CClear}"
}

# -------------------------------------------------------------------------------------------------------------------------
# Displays the "Operations Menu" on top of screen.

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-02] ##
##----------------------------------------##
displayopsmenu()
{
    amtmdisp="${CDkGray}[n/a]        "

    echo -e "${InvGreen} ${InvDkGray}${CWhite} Operations Menu                                                                                              ${CClear}"
    if [ "$vpn1on" == "True" ] || [ "$vpn2on" == "True" ] || [ "$vpn3on" == "True" ] || [ "$vpn4on" == "True" ] || [ "$vpn5on" == "True" ]
    then
       echo -e "${InvGreen} ${CClear} Speedtest ${CGreen}(I)${CClear} WAN / VPN 1:${CGreen}(1)${CClear} 2:${CGreen}(2)${CClear} 3:${CGreen}(3)${CClear} 4:${CGreen}(4)${CClear} 5:${CGreen}(5)${CClear} ${InvGreen} ${CClear} ${CGreen}(M)${CClear}ain Setup Menu / Configuration Menu${CClear}"
       echo -e "${InvGreen} ${CClear} Speedtest Wireguard 1:${CGreen}(6)${CClear} 2:${CGreen}(7)${CClear} 3:${CGreen}(8)${CClear} 4:${CGreen}(9)${CClear} 5:${CGreen}(0)${CClear}     ${InvGreen} ${CClear} L${CGreen}(O)${CClear}g Viewer / Trim Log Size (rows): ${CGreen}$LOGSIZE${CClear}"
    else
       echo -e "${InvGreen} ${CClear} Speedtest ${CGreen}(I)${CClear} WAN ${CDkGray}/ VPN 1:(1) 2:(2) 3:(3) 4:(4) 5:(5)${CClear} ${InvGreen} ${CClear} ${CGreen}(M)${CClear}ain Setup Menu / Configuration Menu${CClear}"
       echo -e "${InvGreen} ${CClear} ${CDkGray}Speedtest Wireguard 1:(6) 2:(7) 3:(8) 4:(9) 5:(0)${CClear}     ${InvGreen} ${CClear} L${CGreen}(O)${CClear}g Viewer / Trim Log Size (rows): ${CGreen}$LOGSIZE${CClear}"
    fi
    echo -e "${InvGreen} ${CClear} Run Router Network ${CGreen}(D)${CClear}iagnostics                      ${InvGreen} ${CClear} ${CGreen}(N)${CClear}ext Page / ${CGreen}(P)${CClear}revious Page: ${CGreen}($NextPage/7)${CClear}"
    echo -e "${InvGreen} ${CClear} Refresh ${CGreen}(C)${CClear}urrent Network Statistics                  ${InvGreen} ${CClear} Auto ${CGreen}(R)${CClear}otate Pages Option: ${CGreen}$autorotateindicator${CClear}"
    echo -e "${InvGreen} ${CClear} View ${CGreen}(W)${CClear}AN / ${CGreen}(L)${CClear}AN / ${CGreen}(V)${CClear}PN / W${CGreen}(G)${CClear} Stats               ${InvGreen} ${CClear} Router Model/FW: ${CGreen}${RouterModel} | ${FWBUILD}${CClear}"
    echo -e "${InvGreen} ${CClear}${CDkGray}--------------------------------------------------------------------------------------------------------------${CClear}"
    echo ""
}

##-------------------------------------##
## Added by Martinski W. [2024-Nov-02] ##
##-------------------------------------##
_ConsumeKeypressBuffer_()
{
   local savedSettings
   local keyPress=''  prevTimeSec
   savedSettings="$(stty -g)"
   prevTimeSec="$(date +%s)"
   read -rs -n1000 -t 1 keyPress < "$(tty 0>&2)"
   while [ "$(date +%s)" -lt "$((prevTimeSec + 1))" ]
   do
      stty -echo -icanon min 0 time 1
      cat - > /dev/null
   done
   stty "$savedSettings"
}

##-------------------------------------##
## Added by Martinski W. [2024-Nov-02] ##
##-------------------------------------##
_IgnoreKeypresses_()
{
   if [ $# -eq 0 ] || [ -z "$1" ]
   then return 1 ; fi
   case "$1" in
        ON) stty -echo ;;
       OFF) stty "$gSavedSTTY" ; stty echo ;;
   esac
}

# -------------------------------------------------------------------------------------------------------------------------
# LogoNM displays the RTRMON script name in a cool ASCII font that fades in
##----------------------------------------##
## Modified by Martinski W. [2024-Nov-02] ##
##----------------------------------------##
logoNM ()
{
  clear
  echo ""
  echo ""
  echo ""
  echo -e "${CDkGray}                        ____  __________  __  _______  _   __"
  echo -e "                       / __ \/_  __/ __ \/  |/  / __ \/ | / /"
  echo -e "                      / /_/ / / / / /_/ / /|_/ / / / /  |/ /"
  echo -e "                     / _, _/ / / / _, _/ /  / / /_/ / /|  /"
  echo -e "                    /_/ |_| /_/ /_/ |_/_/  /_/\____/_/ |_/ v$Version"
  echo ""
  echo ""
  printf "\r                            ${CGreen}    [ INITIALIZING ]     ${CClear}"
  _ConsumeKeypressBuffer_
  clear
  echo ""
  echo ""
  echo ""
  echo -e "${CYellow}                        ____  __________  __  _______  _   __"
  echo -e "                       / __ \/_  __/ __ \/  |/  / __ \/ | / /"
  echo -e "                      / /_/ / / / / /_/ / /|_/ / / / /  |/ /"
  echo -e "                     / _, _/ / / / _, _/ /  / / /_/ / /|  /"
  echo -e "                    /_/ |_| /_/ /_/ |_/_/  /_/\____/_/ |_/ v$Version"
  echo ""
  echo ""
}

# -------------------------------------------------------------------------------------------------------------------------
# logoNMexit displays the RTRMON script name in a cool ASCII font that fades out

logoNMexit () {
  clear
  echo ""
  echo ""
  echo ""
  echo -e "${CYellow}                        ____  __________  __  _______  _   __"
  echo -e "                       / __ \/_  __/ __ \/  |/  / __ \/ | / /"
  echo -e "                      / /_/ / / / / /_/ / /|_/ / / / /  |/ /"
  echo -e "                     / _, _/ / / / _, _/ /  / / /_/ / /|  /"
  echo -e "                    /_/ |_| /_/ /_/ |_/_/  /_/\____/_/ |_/ v$Version"
  echo ""
  echo ""
  printf "\r                            ${CGreen}    [ SHUTTING DOWN ]     ${CClear}"
  sleep 1
  clear
  echo ""
  echo ""
  echo ""
  echo -e "${CDkGray}                        ____  __________  __  _______  _   __"
  echo -e "                       / __ \/_  __/ __ \/  |/  / __ \/ | / /"
  echo -e "                      / /_/ / / / / /_/ / /|_/ / / / /  |/ /"
  echo -e "                     / _, _/ / / / _, _/ /  / / /_/ / /|  /"
  echo -e "                    /_/ |_| /_/ /_/ |_/_/  /_/\____/_/ |_/ v$Version"
  echo ""
  echo ""
  printf "\r                            ${CGreen}    [ SHUTTING DOWN ]     ${CClear}"
  sleep 1
  printf "\r                            ${CDkGray}      [ GOODBYE... ]     ${CClear}\n\n"
  sleep 1
}

##-------------------------------------##
## Added by Martinski W. [2024-Nov-02] ##
##-------------------------------------##
_PressAnyKeyToContinue_()
{ printf "\nPress any key to continue..." ; read -rsn1 anykey ; echo ; }

# -------------------------------------------------------------------------------------------------------------------------
# promptyn takes input for Y/N questions

promptyn () {   # No defaults, just y or n
  while true; do
    read -p '[y/n]? ' YESNO
      case "$YESNO" in
        [Yy]* ) return 0 ;;
        [Nn]* ) return 1 ;;
        * ) echo -e "\nPlease answer y or n.";;
      esac
  done
}

# -------------------------------------------------------------------------------------------------------------------------
# Spinner provides a small spinning indicator on the screen to show script activity

spinner()
{
  spins="$1"

  spin=0
  totalspins="$((spins / 4))"
  while [ "$spin" -le "$totalspins" ]
  do
     for spinchar in / - \\ \|
     do
        printf "\r$spinchar"
        sleep 1
     done
     spin="$((spin+1))"
  done

  printf "\r"
}

# -------------------------------------------------------------------------------------------------------------------------
# Preparebar and Progressbar is a script that provides a nice progressbar to show script activity and bar charts
##----------------------------------------##
## Modified by Martinski W. [2024-Nov-02] ##
##----------------------------------------##
preparebar()
{
  # $1 - bar length
  # $2 - bar char
  barlen="$1"
  barspaces="$(printf "%*s" "$1" ' ')"
  barchars="$(printf "%*s" "$1" ' ' | tr ' ' "$2")"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-02] ##
##----------------------------------------##
# Had to make some mods to the variables being passed, and created an inverse colored progress bar
progressbar()
{
  # $1 - number (-1 for clearing the bar)
  # $2 - max number
  # $3 - system name
  # $4 - measurement
  # $5 - standard/reverse progressbar
  # $6 - alternate display values
  # $7 - alternate value for progressbar exceeding 100%

  insertspc=" "

  if [ "$1" -eq -1 ]
  then
     printf "\r  $barspaces\r"
  else
    if [ $# -gt 6 ] && [ -n "$7" ] && [ "$1" -ge "$7" ]
    then
       barch="$(($7*barlen/$2))"
       barsp="$((barlen-barch))"
       progr="$((100*$1/$2))"
    else
       barch="$(($1*barlen/$2))"
       barsp="$((barlen-barch))"
       progr="$((100*$1/$2))"
    fi

    if [ $# -gt 5 ] && [ -n "$6" ]; then AltNum="$6" ; else AltNum="$1" ; fi

    if [ "$5" = "Standard" ]
    then
      if [ "$progr" -le 60 ]; then
        printf "${InvGreen}${CWhite}$insertspc${CClear}${CWhite}${3} ${CDkGray}[${CGreen}%.${barch}s%.${barsp}s${CDkGray}]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      elif [ "$progr" -gt 60 ] && [ "$progr" -le 85 ]; then
        printf "${InvYellow}${CBlack}$insertspc${CClear}${CYellow}${3} ${CDkGray}[${CYellow}%.${barch}s%.${barsp}s${CDkGray}]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      else
        printf "${InvRed}${CWhite}$insertspc${CClear}${CRed}${3} ${CDkGray}[${CRed}%.${barch}s%.${barsp}s${CDkGray}]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      fi
    elif [ "$5" = "Reverse" ]
    then
      if [ "$progr" -le 15 ]; then
        printf "${InvRed}${CWhite}$insertspc${CClear}${CRed}${3} ${CDkGray}[${CRed}%.${barch}s%.${barsp}s${CDkGray}]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      elif [ "$progr" -gt 15 ] && [ "$progr" -le 40 ]; then
        printf "${InvYellow}${CBlack}$insertspc${CClear}${CYellow}${3} ${CDkGray}[${CYellow}%.${barch}s%.${barsp}s${CDkGray}]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      else
        printf "${InvGreen}${CWhite}$insertspc${CClear}${CWhite}${3}${CGreen} ${CDkGray}[${CGreen}%.${barch}s%.${barsp}s${CDkGray}]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      fi
    elif [ "$5" = "CPU" ]
    then
      if [ "$progr" -le 80 ]; then
        printf "${InvGreen}${CWhite}$insertspc${CClear}${CWhite}${3}${CGreen} ${CDkGray}[${CGreen}%.${barch}s%.${barsp}s${CDkGray}]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      elif [ "$progr" -gt 80 ] && [ "$progr" -le 90 ]; then
        printf "${InvYellow}${CBlack}$insertspc${CClear}${CYellow}${3} ${CDkGray}[${CYellow}%.${barch}s%.${barsp}s${CDkGray}]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      else
        printf "${InvRed}${CWhite}$insertspc${CClear}${CRed}${3} ${CDkGray}[${CRed}%.${barch}s%.${barsp}s${CDkGray}]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      fi
    fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# Shows a more minimalistic progress bar that indicates seconds/%
##----------------------------------------##
## Modified by Martinski W. [2024-Nov-06] ##
##----------------------------------------##
progressbaroverride()
{
  # $1 - number (-1 for clearing the bar)
  # $2 - max number
  # $3 - system name
  # $4 - measurement
  # $5 - standard/reverse progressbar
  # $6 - alternate display values
  # $7 - alternate value for progressbar exceeding 100%

  local barch  barsp  percnt  altNum  readTimeSec
  insertspc=" "

  _GetPercent_() { printf "%.1f" "$(echo "$1" | awk "{print $1}")" ; }

  _UpdateProgressBar_()
  {
     if [ "$2" = "Standard" ] && [ "$INITIALBOOT" -eq 0 ]
     then
        printf "  ${CWhite}${InvDkGray}%3d${1} /%5.1f%%${CClear} [${CGreen}e${CClear}=Exit] [Selection? ${InvGreen} ${CClear}${CGreen}]  ${pausedTimerDispStr} \r${CClear}" "$altNum" "$percnt"
     elif [ "$2" = "Standard" ] && [ "$INITIALBOOT" -eq 1 ]
     then
        printf "${CDkGray}              [${CGreen}%.${barch}s%.${barsp}s${CDkGray}]  \r${CClear}" "$barchars" "$barspaces"
     fi
  }

  _PausedTimerHandler_()
  {
     local keyPress  readTimeSec
     while "$pausedTimerEnabled"
     do
        keyPress=''
        readTimeSec="$(date +%s)"
        read -rsn1 -t 1 keyPress < "$(tty 0>&2)"
        if [ "$keyPress" = "X" ]
        then
            pausedTimerEnabled=false
            pausedTimerDispStr="$(printf "%*s" "$pausedTimerMsgLen" ' ')"
            break
        fi
        if [ "$(date +%s)" -lt "$((readTimeSec + 1))" ]
        then
            stty -icanon min 0 time 5
            cat - > /dev/null
        fi
     done
  }

  if [ "$1" -eq -1 ]
  then
     printf "\r  $barspaces\r"
  else
     if [ $# -gt 6 ] && [ -n "$7" ] && [ "$1" -ge "$7" ]
     then
        barch="$(($7*barlen/$2))"
        barsp="$((barlen-barch))"
        percnt="$(_GetPercent_ "(100*$1/$2)")"
     else
        barch="$(($1*barlen/$2))"
        barsp="$((barlen-barch))"
        percnt="$(_GetPercent_ "(100*$1/$2)")"
     fi

     if [ $# -gt 5 ] && [ -n "$6" ]; then altNum="$6" ; else altNum="$1" ; fi

     _UpdateProgressBar_ "$4" "$5"

     if [ "$INITIALBOOT" = "0" ]
     then
        # Borrowed this wonderful keypress capturing mechanism from @Eibgrad... thank you! :)
        readTimeSec="$(date +%s)"
        key_press=''; read -rsn1 -t 1 key_press < "$(tty 0>&2)"

        if [ "$key_press" ]
        then
           case "$key_press" in
               [Cc]) QueueNetworkConn=1
                     echo -e "${CClear}[Queuing Network Connection Stats]                                       ";
                     sleep 1; NextPage=6; timerReset=1
                     ;;
               [Dd]) QueueNetworkDiag=1
                     echo -e "${CClear}[Queuing Network Diagnostics]                                            ";
                     sleep 1; NextPage=5; timerReset=1
                     ;;
               [Ee]) clear; logoNMexit; echo -e "${CClear}"; exit 0
                     ;;
               [Gg]) NCView="WG"; NextPage=6; timerReset=1
                     ;;
               [Hh]) hideoptions=1 ; [ "$hideoptions" != "$prevHideOpts" ] && timerReset=1
                     ;;
               [Ii]) QueueSpdTest=1
                     echo -e "${CClear}[Queuing WAN Speedtest]                                                  ";
                     sleep 1; NextPage=4; timerReset=1
                     ;;
               [Ll]) NCView="LAN"; NextPage=6; timerReset=1
                     ;;
               [Mm]) _IgnoreKeypresses_ OFF
                     FromUI=1; vsetup; source "$CFGPATH"
                     echo -e "\n${CClear}[Returning to the Main UI momentarily]                                   ";
                     sleep 1; FromUI=0; timerReset=1
                     ;;
               [Nn]) timerReset=1
                     if   [ "$NextPage" = "1" ]; then NextPage=2
                     elif [ "$NextPage" = "2" ]; then NextPage=3
                     elif [ "$NextPage" = "3" ]; then NextPage=4
                     elif [ "$NextPage" = "4" ]; then NextPage=5
                     elif [ "$NextPage" = "5" ]; then NextPage=6
                     elif [ "$NextPage" = "6" ]; then NextPage=7
                     elif [ "$NextPage" = "7" ]; then NextPage=1
                     fi
                     ;;
               [Oo]) _IgnoreKeypresses_ OFF ; vlogs ;;
               [Pp]) timerReset=1
                     if   [ "$NextPage" = "1" ]; then NextPage=7
                     elif [ "$NextPage" = "2" ]; then NextPage=1
                     elif [ "$NextPage" = "3" ]; then NextPage=2
                     elif [ "$NextPage" = "4" ]; then NextPage=3
                     elif [ "$NextPage" = "5" ]; then NextPage=4
                     elif [ "$NextPage" = "6" ]; then NextPage=5
                     elif [ "$NextPage" = "7" ]; then NextPage=6
                     fi
                     ;;
               [Rr]) if   [ "$autorotate" = 0 ]
                     then autorotate=1; autorotateindicator="ON"
                     elif [ "$autorotate" = "1" ]
                     then autorotate=0; autorotateindicator="OFF"
                     fi
                     timerReset=1
                     ;;
               [Ss]) hideoptions=0 ; [ "$hideoptions" != "$prevHideOpts" ] && timerReset=1
                     ;;
               [Tt]) PSView="TCP"; NextPage=5; timerReset=1
                     ;;
               [Uu]) PSView="UDP"; NextPage=5; timerReset=1
                     ;;
               [Vv]) NCView="VPN"; NextPage=6; timerReset=1
                     ;;
               [Ww]) NCView="WAN"; NextPage=6; timerReset=1
                     ;;
                  X) if "$pausedTimerEnabled"
                     then
                         pausedTimerEnabled=false
                         pausedTimerDispStr="$(printf "%*s" "$pausedTimerMsgLen" ' ')"
                     else
                         pausedTimerEnabled=true
                         pausedTimerDispStr="${CWhite}${InvRed}${pausedTimerMsgStr}${CClear}"
                         _UpdateProgressBar_ "$4" "$5"
                         _PausedTimerHandler_
                     fi
                     ;;
                  1) QueueVPNSlot1=1
                     echo -e "${CClear}[Queuing VPN1 Speedtest]                                                  ";
                     sleep 1; NextPage=4; timerReset=1
                     ;;
                  2) QueueVPNSlot2=1
                     echo -e "${CClear}[Queuing VPN2 Speedtest]                                                  ";
                     sleep 1; NextPage=4; timerReset=1
                     ;;
                  3) QueueVPNSlot3=1
                     echo -e "${CClear}[Queuing VPN3 Speedtest]                                                  ";
                     sleep 1; NextPage=4; timerReset=1
                     ;;
                  4) QueueVPNSlot4=1
                     echo -e "${CClear}[Queuing VPN4 Speedtest]                                                  ";
                     sleep 1; NextPage=4; timerReset=1
                     ;;
                  5) QueueVPNSlot5=1
                     echo -e "${CClear}[Queuing VPN5 Speedtest]                                                  ";
                     sleep 1; NextPage=4; timerReset=1
                     ;;
                  6) QueueWGSlot1=1
                     echo -e "${CClear}[Queuing WG1 Speedtest]                                                  ";
                     sleep 1; NextPage=4; timerReset=1
                     ;;
                  7) QueueWGSlot2=1
                     echo -e "${CClear}[Queuing WG2 Speedtest]                                                  ";
                     sleep 1; NextPage=4; timerReset=1
                     ;;
                  8) QueueWGSlot3=1
                     echo -e "${CClear}[Queuing WG3 Speedtest]                                                  ";
                     sleep 1; NextPage=4; timerReset=1
                     ;;
                  9) QueueWGSlot4=1
                     echo -e "${CClear}[Queuing WG4 Speedtest]                                                  ";
                     sleep 1; NextPage=4; timerReset=1
                     ;;
                  0) QueueWGSlot5=1
                     echo -e "${CClear}[Queuing WG5 Speedtest]                                                  ";
                     sleep 1; NextPage=4; timerReset=1
                     ;;

               [\!]) SortbyOpt="Name"; [ "$SortbyOpt" != "$prevSortByOpt" ] && [ "$NextPage" = "7" ] && timerReset=1 ;;
               [\@]) SortbyOpt="IP";   [ "$SortbyOpt" != "$prevSortByOpt" ] && [ "$NextPage" = "7" ] && timerReset=1 ;;
               [\#]) SortbyOpt="MAC";  [ "$SortbyOpt" != "$prevSortByOpt" ] && [ "$NextPage" = "7" ] && timerReset=1 ;;
                  *) ;; ##IGNORE INVALID key presses ##
           esac
           _IgnoreKeypresses_ ON
           if [ "$(date +%s)" -lt "$((readTimeSec + 1))" ]
           then
               stty -icanon min 0 time 1
               cat - > /dev/null
           fi
        fi
     else
        ## Initial Boot Sequence Loop ##
        _ConsumeKeypressBuffer_
     fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# converttemps converts temp readouts from C to F or K

converttemps () {
# $1 is the incoming C Temp

  if [ "$TempUnits" == "F" ]; then
    currenttemp=$(awk -v v1=$1 'BEGIN{printf "%0.2f\n", (v1*9)/5+32}' | cut -d . -f 1)
    currentrange=212
  elif [ "$TempUnits" == "K" ]; then
    currenttemp=$(awk -v v1=$1 'BEGIN{printf "%0.2f\n", v1+273}' | cut -d . -f 1)
    currentrange=373
  elif [ "$TempUnits" == "C" ]; then
    currenttemp=$1
    currentrange=100
  else
    # Default to C if someone entered something other than C, F or K
    TempUnits="C"
    currenttemp=$1
    currentrange=100
  fi

}

# -------------------------------------------------------------------------------------------------------------------------
# updatecheck downloads the latest update version file from github, and compares it with what's currently installed

updatecheck () {

  # Download the latest version file from the source repository
  curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/RTRMON/master/version.txt" -o "/jffs/addons/rtrmon.d/version.txt"

  if [ -f $DLVERPATH ]
    then
      # Read in its contents for the current version file
      DLVersion=$(cat $DLVERPATH)

      # Compare the new version with the old version and log it
      if [ "$Beta" == "1" ]; then   # Check if Dev/Beta Mode is enabled and disable notification message
        UpdateNotify=0
      elif [ "$DLVersion" != "$Version" ]; then
        DLVersionPF=$(printf "%-8s" $DLVersion)
        VersionPF=$(printf "%-8s" $Version)
        UpdateNotify="${InvYellow} ${InvDkGray}${CWhite} Update available: v$VersionPF -> v$DLVersionPF                                                                     ${CClear}"
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: A new update (v$DLVersion) is available to download" >> $LOGFILE
      else
        UpdateNotify=0
      fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# calls the nano text editor to view the RTRMON log file

vlogs() {

export TERM=linux
nano +999999 --linenumbers $LOGFILE
timerReset=1

}

# -------------------------------------------------------------------------------------------------------------------------
# trimlogs will cut down log size (in rows) based on custom value

trimlogs()
{

  if [ "$LOGSIZE" -gt 0 ]
  then
      currlogsize=$(wc -l $LOGFILE | awk '{ print $1 }' ) # Determine the number of rows in the log

      if [ "$currlogsize" -gt "$LOGSIZE" ] # If it's bigger than the max allowed, tail/trim it!
        then
          echo "$(tail -$LOGSIZE $LOGFILE)" > $LOGFILE
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: Trimmed the log file down to $LOGSIZE lines" >> $LOGFILE
      fi

  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# vconfig guides you through the various configuration options for RTRMON
##----------------------------------------##
## Modified by Martinski W. [2024-Nov-02] ##
##----------------------------------------##
vconfig()
{
  _SetUpTimeoutCmdVars_

  if [ -f "$CFGPATH" ] #Making sure file exists before proceeding
  then
    source "$CFGPATH"

    CHANGES=0  #track notification to save your changes#

    while true
    do
      clear
      echo -e "${InvGreen} ${InvDkGray}${CWhite} RTRMON Configuration Options                                                          ${CClear}"
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear} Please choose from the various options below, which allow you to modify certain${CClear}"
      echo -e "${InvGreen} ${CClear} customizable parameters that affect the operation of this script.${CClear}"
      echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( 1)${CClear} : Timer Interval (seconds)                     : ${CGreen}$Interval"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( 2)${CClear} : Max Internet Download Speed (Mbps)           : ${CGreen}$MaxSpeedInet"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( 3)${CClear} : Max Internet Upload Speed (Mbps)             : ${CGreen}$MaxSpeedInetUL"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( 4)${CClear} : Max LAN Speed (Mbps)                         : ${CGreen}$MaxSpeedLAN"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( 5)${CClear} : Max 2.4GHz Speed (Mbps)                      : ${CGreen}$MaxSpeed24Ghz"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( 6)${CClear} : Max 5GHz Speed (Mbps)                        : ${CGreen}$MaxSpeed5Ghz"

      if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2456" == "True" ] || [ "$FourBandCustom56624" == "True" ]; then
        echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( 7)${CClear} : Max 6GHz Speed (Mbps)                        : ${CGreen}$MaxSpeed6Ghz"
      else
        echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( 7)${CClear} : ${CDkGray}Max 6GHz Speed (Mbps)                        : N/A"
      fi

      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( 8)${CClear} : Temperature Units (C/F/K)                    : ${CGreen}$TempUnits"

      echo -en "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( 9)${CClear} : Enable Ookla Speedtest? (Y/N)                : ${CGreen}"
      if [ "$Speedtst" = "0" ]
      then printf "No\n"
      else printf "Yes\n"
      fi

      if [ "$spdtestsvrID" == "0" ] && [ "$Speedtst" == "1" ]; then
        echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(10)${CClear} : Custom Speedtest Server ID?                  : ${CGreen}Use Closest"
      elif [ "$spdtestsvrID" != "0" ] && [ "$Speedtst" == "1" ]; then
        echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(10)${CClear} : Custom Speedtest Server ID?                  : ${CGreen}$spdtestsvrID"
      else
        echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(10)${CClear} : Custom Speedtest Server ID?                  : ${CDkGray}N/A"
      fi

      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(11)${CClear} : WAN0 Interface Override?                     : ${CGreen}$WANOverride"

      if [ "$WAN0AltModes" == "0" ]; then WAN0AltModesdisp="No"; else WAN0AltModesdisp="Yes"; fi
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(12)${CClear} : Mark Router As iMesh Node/Repeater/Bridge?   : ${CGreen}$WAN0AltModesdisp"
      if [ "$VPNSite2Site" == "0" ]; then VPNSite2Sitedisp="No"; else VPNSite2Sitedisp="Yes"; fi
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(13)${CClear} : Mark Router As VPN Site-To-Site Only?        : ${CGreen}$VPNSite2Sitedisp"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(14)${CClear} : Custom Event Log Size?                       : ${CGreen}$LOGSIZE"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}  | ${CClear}"

      if [ $CHANGES -eq 0 ]; then
        echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( s)${CClear} : Save Config & Exit"
      else
        echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( s)${CClear} : Save Config & Exit                ${CWhite}${InvRed}<-- Save your changes! ${CClear}"
      fi

      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}( e)${CClear} : Exit & Discard Changes"
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
      echo ""
      read -p "Please select? (1-13, s=Save, e=Exit): " ConfigSelection
      CHANGES=1
      # Execute chosen selections
          case "$ConfigSelection" in

            1) # -----------------------------------------------------------------------------------------
              while true
              do
                 clear
                 echo -e "${InvGreen} ${InvDkGray}${CWhite} Refresh Interval                                                                      ${CClear}"
                 echo -e "${InvGreen} ${CClear}"
                 echo -e "${InvGreen} ${CClear} Please indicate after how many seconds you would like RTRMON to refresh your stats?${CClear}"
                 echo -e "${InvGreen} ${CClear}"
                 echo -e "${InvGreen} ${CClear} (Default = 10 seconds)${CClear}"
                 echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
                 echo
                 echo -e "${CClear}Current Refresh Interval: ${CGreen}${Interval}${CClear} seconds"
                 echo
                 read -p "Please enter value in seconds [5-999] (e=Exit): " newInterval
                 if [ -z "$newInterval" ] || echo "$newInterval" | grep -qE "^(e|E)$"
                 then
                     if echo "$Interval" | grep -qE "^([1-9][0-9]{0,2})$" && \
                        [ "$Interval" -ge 5 ] && [ "$Interval" -le 999 ]
                     then
                         timer="$Interval"
                         printf "\n${CClear}[Exiting]\n"
                         sleep 1 ; break
                     else
                         printf "\n${CRed}*ERROR*: Please enter a valid number between 5 and 999.${CClear}\n"
                         _PressAnyKeyToContinue_
                     fi
                 elif echo "$newInterval" | grep -qE "^([1-9][0-9]{0,2})$" && \
                      [ "$newInterval" -ge 5 ] && [ "$newInterval" -le 999 ]
                 then
                     Interval="$newInterval"
                     echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: A new refresh interval ($Interval) has been selected." >> $LOGFILE
                     CHANGES=1
                     timer="$Interval"
                     printf "\n${CClear}[OK]\n"
                     sleep 1 ; break
                 else
                     printf "\n${CRed}*ERROR*: Please enter a valid number between 5 and 999.${CClear}\n"
                     _PressAnyKeyToContinue_
                 fi
              done
            ;;

            2) # -----------------------------------------------------------------------------------------
              clear
              echo -e "${InvGreen} ${InvDkGray}${CWhite} Maximum Internet Download Bandwidth                                                   ${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} Please indicate what your maximum internet download bandwidth/speed is in Mbps?${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} (Default = 50 Mbps)${CClear}"
              echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
              echo ""
              echo -e "${CClear}Current: ${CGreen}$MaxSpeedInet${CClear} Mbps"
              echo ""
              read -p 'Please enter value in Mbps (ex: 1000): ' MaxSpeedInet1
              MaxSpeedInet2=$(echo $MaxSpeedInet1 | tr -d -c 0-9)
              if [ -z "$MaxSpeedInet1" ]; then MaxSpeedInet=50; else MaxSpeedInet=$MaxSpeedInet2; fi
              echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: A new Internet Download Bandwidth soeed ($MaxSpeedInet Mbps) has been selected." >> $LOGFILE
            ;;

            3) # -----------------------------------------------------------------------------------------
              clear
              echo -e "${InvGreen} ${InvDkGray}${CWhite} Maximum Internet Upload Bandwidth                                                     ${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} Please indicate what your maximum internet upload bandwidth/speed is in Mbps?${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} (Default = 50 Mbps)${CClear}"
              echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
              echo ""
              echo -e "${CClear}Current: ${CGreen}$MaxSpeedInetUL${CClear} Mbps"
              echo ""
              read -p 'Please enter value in Mbps (ex: 1000): ' MaxSpeedInetUL1
              MaxSpeedInetUL2=$(echo $MaxSpeedInetUL1 | tr -d -c 0-9)
              if [ -z "$MaxSpeedInetUL1" ]; then MaxSpeedInetUL=50; else MaxSpeedInetUL=$MaxSpeedInetUL2; fi
              echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: A new Internet Upload Bandwidth speed ($MaxSpeedInetUL Mbps) has been selected." >> $LOGFILE
            ;;

            4) # -----------------------------------------------------------------------------------------
              clear
              echo -e "${InvGreen} ${InvDkGray}${CWhite} Maximum Local Area Network (LAN) Bandwidth                                            ${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} Please indicate what your maximum LAN bandwidth/speed is in Mbps?${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} (Default = 1000 Mbps)${CClear}"
              echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
              echo ""
              echo -e "${CClear}Current: ${CGreen}$MaxSpeedLAN${CClear} Mbps"
              echo ""
              read -p 'Please enter value in Mbps (ex: 1000): ' MaxSpeedLAN1
              MaxSpeedLAN2=$(echo $MaxSpeedLAN1 | tr -d -c 0-9)
              if [ -z "$MaxSpeedLAN1" ]; then MaxSpeedLAN=1000; else MaxSpeedLAN=$MaxSpeedLAN2; fi
              echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: A new LAN Bandwidth speed ($MaxSpeedLAN Mbps) has been selected." >> $LOGFILE
            ;;

            5) # -----------------------------------------------------------------------------------------
              clear
              echo -e "${InvGreen} ${InvDkGray}${CWhite} Maximum 2.4GHz Bandwidth Speed                                                        ${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} Please indicate what your maximum realistic 2.4GHz speed is in Mbps?${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} (Default = 450 Mbps)${CClear}"
              echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
              echo ""
              echo -e "${CClear}Current: ${CGreen}$MaxSpeed24Ghz${CClear} Mbps"
              echo ""
              read -p 'Please enter value in Mbps (ex: 1000): ' MaxSpeed24Ghz1
              MaxSpeed24Ghz2=$(echo $MaxSpeed24Ghz1 | tr -d -c 0-9)
              if [ -z "$MaxSpeed24Ghz1" ]; then MaxSpeed24Ghz=450; else MaxSpeed24Ghz=$MaxSpeed24Ghz2; fi
              echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: A new 2.4GHz Bandwidth speed ($MaxSpeed24Ghz Mbps) has been selected." >> $LOGFILE
            ;;

            6) # -----------------------------------------------------------------------------------------
              clear
              echo -e "${InvGreen} ${InvDkGray}${CWhite} Maximum 5GHz Bandwidth Speed                                                          ${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} Please indicate what your maximum realistic 5GHz speed is in Mbps?${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} (Default = 780 Mbps)${CClear}"
              echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
              echo ""
              echo -e "${CClear}Current: ${CGreen}$MaxSpeed5Ghz${CClear} Mbps"
              echo ""
              read -p 'Please enter value in Mbps (ex: 1000): ' MaxSpeed5Ghz1
              MaxSpeed5Ghz2=$(echo $MaxSpeed5Ghz1 | tr -d -c 0-9)
              if [ -z "$MaxSpeed5Ghz1" ]; then MaxSpeed5Ghz=780; else MaxSpeed5Ghz=$MaxSpeed5Ghz2; fi
              echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: A new 5GHz Bandwidth speed ($MaxSpeed5Ghz Mbps) has been selected." >> $LOGFILE
            ;;

            7) # -----------------------------------------------------------------------------------------
              clear
              if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2456" == "True" ] || [ "$FourBandCustom56624" == "True" ]; then
                echo -e "${InvGreen} ${InvDkGray}${CWhite} Maximum 6GHz Bandwidth Speed                                                          ${CClear}"
                echo -e "${InvGreen} ${CClear}"
                echo -e "${InvGreen} ${CClear} Please indicate what your maximum realistic 6GHz speed is in Mbps?${CClear}"
                echo -e "${InvGreen} ${CClear}"
                echo -e "${InvGreen} ${CClear} (Default = 920 Mbps)${CClear}"
                echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
                echo ""
                echo -e "${CClear}Current: ${CGreen}$MaxSpeed6Ghz${CClear} Mbps"
                echo ""
                read -p 'Please enter value in Mbps (ex: 1000): ' MaxSpeed6Ghz1
                MaxSpeed6Ghz2=$(echo $MaxSpeed6Ghz1 | tr -d -c 0-9)
                if [ -z "$MaxSpeed6Ghz1" ]; then MaxSpeed6Ghz=920; else MaxSpeed6Ghz=$MaxSpeed6Ghz2; fi
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: A new 6GHz Bandwidth speed ($MaxSpeed6Ghz Mbps) has been selected." >> $LOGFILE
              else
                echo -e "${CRed}This item is currently only available for router models:"
                echo -e "GT-AXE11000, GT-AXE16000, RT-BE96U and GT-BE98_Pro"
                echo ""
                sleep 3
              fi
            ;;

            8) # -----------------------------------------------------------------------------------------
              while true
              do
                clear
                echo -e "${InvGreen} ${InvDkGray}${CWhite} Temperature Unit Preferences                                                          ${CClear}"
                echo -e "${InvGreen} ${CClear}"
                echo -e "${InvGreen} ${CClear} Please indicate what Temperature Units you would prefer to use?${CClear}"
                echo -e "${InvGreen} ${CClear} (C)elcius, (F)ahrenheit or (K)elvin"
                echo -e "${InvGreen} ${CClear}"
                echo -e "${InvGreen} ${CClear} (Default = C)${CClear}"
                echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
                echo ""
                echo -e "${CClear}Current: ${CGreen}$TempUnits${CClear}"
                echo ""
                read -p 'Temp Units (C/F/K): ' TempUnits1
                case "$TempUnits1" in
                    [Cc]) TempUnits="C" ; break ;;
                    [Ff]) TempUnits="F" ; break ;;
                    [Kk]) TempUnits="K" ; break ;;
                       *)
                          printf "\n*ERROR*: Please enter a valid option.${CClear}\n"
                          sleep 2
                          ;;
                esac
            done
            if [ -z "$TempUnits1" ]; then TempUnits="C"; fi
            echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: A new Temperature Unit ($TempUnits) has been selected." >> $LOGFILE
            ;;

            9) # -----------------------------------------------------------------------------------------
              echo ""
              if [ -f $OOKLAPATH ]; then
                clear
                echo -e "${InvGreen} ${InvDkGray}${CWhite} Remove Ookla Speedtest Binaries                                                       ${CClear}"
                echo -e "${InvGreen} ${CClear}"
                echo -e "${InvGreen} ${CClear} Would you like to disable and uninstall the Ookla Speedtest binaries from RTRMON?${CClear}"
                echo -e "${InvGreen} ${CClear}"
                echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
                echo ""
                echo -e "${CClear}Current: ${CGreen}Ookla Speedtest Installed${CClear}"
                echo ""
                echo -e "Remove Speedtest binaries from RTRMON?${CClear}"
                if promptyn "[y/n]: "
                then
                  echo ""
                  echo ""
                  echo -e "${CClear}Removing Ookla Speedtest binaries..."
                  rm "/jffs/addons/rtrmon.d/speedtest"
                  rm "/jffs/addons/rtrmon.d/speedtest.5"
                  rm "/jffs/addons/rtrmon.d/speedtest.md"
                  sleep 1
                  if [ ! -f $OOKLAPATH ]; then
                    echo ""
                    echo -e "${CClear}Completed removing Ookla Speedtest binaries..."
                    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: Ookla Speedtest binaries have been successfully removed." >> $LOGFILE
                    Speedtst=0
                    spdtestsvrID=0
                    echo ""
                    read -rsp $'Press any key to continue...\n' -n1 key
                  else
                    echo ""
                    echo -e "${CRed}ERROR: Ookla Speedtest binaries were unable to be removed...${CClear}"
                    echo -e "Please manually resolve issue under /jffs/addons/rtrmon.d folder"
                    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - ERROR: Ookla Speedtest binaries were unable to be successfully removed." >> $LOGFILE
                    Speedtst=1
                    echo ""
                    read -rsp $'Press any key to continue...\n' -n1 key
                  fi
                else
                  echo ""
                  echo ""
                  echo -e "${CClear}Canceling removing Ookla Speedtest binaries..."
                  sleep 2
                fi

              else
                clear
                echo -e "${InvGreen} ${InvDkGray}${CWhite} Install Ookla Speedtest Binaries                                                      ${CClear}"
                echo -e "${InvGreen} ${CClear}"
                echo -e "${InvGreen} ${CClear} Would you like to install and enable the Ookla Speedtest binaries for use with${CClear}"
                echo -e "${InvGreen} ${CClear} RTRMON? Please read the following before accepting agreement:${CClear}"
                echo -e "${InvGreen} ${CClear}"
                echo -e "${InvGreen} ${CClear} You may only use this Speedtest software and information generated from it for${CClear}"
                echo -e "${InvGreen} ${CClear} personal, non-commercial use, through a command line interface on a personal${CClear}"
                echo -e "${InvGreen} ${CClear} computer. Your use of this software is subject to the End User License${CClear}"
                echo -e "${InvGreen} ${CClear} Agreement, Terms of Use and Privacy Policy at these URLs:${CClear}"
                echo -e "${InvGreen} ${CClear}"
                echo -e "${InvGreen} ${CClear}   https://www.speedtest.net/about/eula${CClear}"
                echo -e "${InvGreen} ${CClear}   https://www.speedtest.net/about/terms${CClear}"
                echo -e "${InvGreen} ${CClear}   https://www.speedtest.net/about/privacy${CClear}"
                echo -e "${InvGreen} ${CClear}"
                echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
                echo ""
                echo -e "${CClear}Current: ${CGreen}Ookla Speedtest Not Installed${CClear}"
                echo ""
                echo -e "By typing 'y' below, you agree to these terms.${CClear}"
                if promptyn "[y/n]: "; then
                  echo ""
                  echo ""
                  echo -e "Installing Ookla Speedtest binaries..."
                  echo ""
                  if [ "$(uname -m)" = "aarch64" ]; then
                    curl --silent --retry 3 "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-aarch64.tgz" -o "/jffs/addons/rtrmon.d/spdtst64.tgz"
                    tar -zxf /jffs/addons/rtrmon.d/spdtst64.tgz -C /jffs/addons/rtrmon.d 2>/dev/null
                    chmod 0755 "/jffs/addons/rtrmon.d/speedtest"
                    rm /jffs/addons/rtrmon.d/spdtst64.tgz
                  else
                    curl --silent --retry 3 "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-armel.tgz" -o "/jffs/addons/rtrmon.d/spdtstel.tgz"
                    tar -zxf /jffs/addons/rtrmon.d/spdtstel.tgz -C /jffs/addons/rtrmon.d 2>/dev/null
                    chmod 0755 "/jffs/addons/rtrmon.d/speedtest"
                    rm /jffs/addons/rtrmon.d/spdtstel.tgz
                  fi
                  if [ -f /jffs/addons/rtrmon.d/speedtest ]; then
                    echo -e "${CClear}Ookla Speedtest binaries installed successfully..."
                    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: Ookla Speedtest binaries were successfully installed." >> $LOGFILE
                    Speedtst=1
                    echo ""
                    read -rsp $'Press any key to initialize Speedtest and accept license...\n' -n1 key
                    /jffs/addons/rtrmon.d/speedtest
                    cp /root/.config/ookla/speedtest-cli.json /jffs/addons/rtrmon.d/speedtest-cli.json 2>/dev/null
                    echo ""
                    read -rsp $'Press any key to continue...\n' -n1 key
                  else
                    echo -e "${CRed}ERROR: Ookla Speedtest binaries install failed...${CClear}"
                    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - ERROR: Ookla Speedtest binaries were unable to be successfully installed." >> $LOGFILE
                    Speedtst=0
                    spdtestsvrID=0
                    echo ""
                    read -rsp $'Press any key to continue...\n' -n1 key
                  fi
                else
                  echo ""
                  echo ""
                  echo -e "${CClear}Canceling install of Ookla Speedtest binaries..."
                  Speedtst=0
                  spdtestsvrID=0
                  sleep 2
                fi
              fi
            ;;

            10) # -----------------------------------------------------------------------------------------
              if [ "$Speedtst" == "0" ]; then return; fi
              clear
              echo -e "${InvGreen} ${InvDkGray}${CWhite} Custom Speedtest Server ID                                                            ${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} Please indicate if you would like to use a custom Speedtest Server ID? These IDs${CClear}"
              echo -e "${InvGreen} ${CClear} can be found by running a Speedtest on your browser and noting the ID of the server${CClear}"
              echo -e "${InvGreen} ${CClear} in its URL when hovering your mouse over it. Enter an ID number, or use 0 to choose${CClear}"
              echo -e "${InvGreen} ${CClear} the closest server to you.${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} (Default = 0)${CClear}"
              echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
              echo ""
              echo -e "${CClear}Current: ${CGreen}$spdtestsvrID${CClear}"
              echo ""
              read -p 'Speedtest Server ID: ' spdtestsvrID1
              spdtestsvrID2=$(echo $spdtestsvrID1 | tr -d -c 0-9)
              if [ -z "$spdtestsvrID1" ]; then spdtestsvrID=0; else spdtestsvrID=$spdtestsvrID2; fi
              echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: Ookla Speedtest custom server ID ($spdtestsvrID) was configured." >> $LOGFILE
            ;;

            11) # -----------------------------------------------------------------------------------------
              clear
              echo -e "${InvGreen} ${InvDkGray}${CWhite} Override WAN0 Interface                                                               ${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} Please indicate if you would like to override the default interface assigned to${CClear}"
              echo -e "${InvGreen} ${CClear} your local WAN0? Typically, 'eth0' is assigned to WAN0, but based on how you've${CClear}"
              echo -e "${InvGreen} ${CClear} rigged your router, it might be something else. By default, RTRMON will${CClear}"
              echo -e "${InvGreen} ${CClear} automatically try to determine the correct interface, however this will give${CClear}"
              echo -e "${InvGreen} ${CClear} you the option to override it should you be using something else.${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} (Default = 0)${CClear}"
              echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
              echo ""
              echo -e "${CClear}Current: ${CGreen}$WANOverride${CClear}"
              echo ""
              echo -e "${CGreen}Valid interface choices:"

              ip -br link | LC_ALL=C awk '$2 == "UP" {print $1}' > $IFLIST # Extract all valid interfaces to a text file

              LINES=$(cat $IFLIST | wc -l) #Check to see how many lines are in this file

              echo -e "${CClear}0) Auto"

              i=0 # Populate all other numbered choices
              while [ $i -ne $LINES ]
              do
                  i=$(($i+1))
                  InterfaceName=$(sed -n "${i}p" $IFLIST)
                  echo -e "$i) $InterfaceName"
              done

              echo -e "${CClear}"
              echo -e "(Default = 0 (Auto), or choose one of the above)${CClear}"

              while true
              do
                  read -p 'Choose Interface #: ' ChooseInterface

                  case ${ChooseInterface#[-+]} in # Make sure we're only picking an item from the list
                    *[!0-9]* | '') echo ""; echo -e "\n${CRed}ERROR: Please make a valid selection${CClear}"; echo "" ;;
                    * ) if [ $ChooseInterface -lt 0 ] || [ $ChooseInterface -gt $LINES ]; then echo ""; echo -e "\n${CRed}Please make a valid selection${CClear}"; echo ""; else break; fi ;;
                  esac

              done

              if [ -z "$ChooseInterface" ] # Assign the interface name to a variable and save it
                then
                  WANOverride="Auto"
              elif [ $ChooseInterface -eq 0 ]
                then
                  WANOverride="Auto"
              else
                WANOverride=$(sed -n "${ChooseInterface}p" $IFLIST)
              fi
              echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: WAN0 Override ($WANOverride) was configured." >> $LOGFILE
            ;;

            12) # -----------------------------------------------------------------------------------------
              clear
              echo -e "${InvGreen} ${InvDkGray}${CWhite} Mark Router As iMesh Node/Repeater/Bridge                                             ${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} Please indicate if you would like to mark that this router is being used as an${CClear}"
              echo -e "${InvGreen} ${CClear} iMesh Node, Repeater or Bridge operating mode. In cases like this, the WAN0${CClear}"
              echo -e "${InvGreen} ${CClear} interface will be non-functional, and will be omitted from being captured by${CClear}"
              echo -e "${InvGreen} ${CClear} RTRMON's stats.${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} (Default = No)${CClear}"
              echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
              echo ""
              if [ "$WAN0AltModes" == "0" ]; then WAN0AltModesdisp="No"; else WAN0AltModesdisp="Yes"; fi
              echo -e "${CClear}Current: ${CGreen}$WAN0AltModesdisp${CClear}"
              echo ""
              echo -e "Is this router an iMesh Node/Repeater/Bridge?${CClear}"
              if promptyn "[y/n]: "; then
                WAN0AltModes=1
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: This device's operating mode was marked as an iMesh Node/AP/Repeater/Bridge." >> $LOGFILE
              else
                WAN0AltModes=0
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: This device's operating mode was marked as a Router." >> $LOGFILE
              fi
            ;;

            13) # -----------------------------------------------------------------------------------------
              clear
              echo -e "${InvGreen} ${InvDkGray}${CWhite} Mark VPN As Site-To-Site Only                                                         ${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} Please indicate if you would like to mark that this router is purely being used${CClear}"
              echo -e "${InvGreen} ${CClear} in a VPN Site-To-Site only configuration. In cases like this, the public-facing${CClear}"
              echo -e "${InvGreen} ${CClear} IP is a private IP, which could hinder certain network connection and bandwidth$CClear}"
              echo -e "${InvGreen} ${CClear} tests, and potentially cause delays and/or a lack of data.${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} By default, it is assumed that this router's VPN configuration will be marked${CClear}"
              echo -e "${InvGreen} ${CClear} as being in a normal VPN provider configuration.${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} (Default = No)${CClear}"
              echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
              echo ""
              if [ "$VPNSite2Site" == "0" ]; then VPNSite2Sitedisp="No"; else VPNSite2Sitedisp="Yes"; fi
              echo -e "${CClear}Current: ${CGreen}$VPNSite2Sitedisp${CClear}"
              echo ""
              echo -e "Is this router purely used in a VPN Site-to-Site Configuration?${CClear}"
              if promptyn "[y/n]: "; then
                VPNSite2Site=1
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: This device's VPN operating mode was marked as being in a VPN Site-to-Site only configuration." >> $LOGFILE
              else
                VPNSite2Site=0
                echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: This device's VPN operating mode was marked as being in a Normal VPN Provider configuration." >> $LOGFILE
              fi
            ;;

            14)
              clear
              echo -e "${InvGreen} ${InvDkGray}${CWhite} Custom Event Log Size                                                                 ${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} Please indicate below how large you would like your Event Log to grow. I'm a poet${CClear}"
              echo -e "${InvGreen} ${CClear} and didn't even know it. By default, with 2000 rows, you will have many months of${CClear}"
              echo -e "${InvGreen} ${CClear} Event Log data."
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} Use 0 to Disable, max number of rows is 9999. (Default = 2000)"
              echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
              echo ""
              echo -e "${CClear}Current: ${CGreen}$LOGSIZE${CClear}"
              echo ""
              read -p "Please enter Log Size (in rows)? (0-9999, e=Exit): " NEWLOGSIZE
              if [ -z "$NEWLOGSIZE" ] || [ "$NEWLOGSIZE" = "e" ]
              then
                  printf "\n[Exiting]\n"; sleep 2
              elif [ $NEWLOGSIZE -ge 0 ] && [ $NEWLOGSIZE -le 9999 ]
              then
                  LOGSIZE="$NEWLOGSIZE"
                  echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: New custom Event Log Size entered (in rows): $LOGSIZE" >> $LOGFILE
              else
                  LOGSIZE=2000
                  echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: New custom Event Log Size entered (in rows): $LOGSIZE" >> $LOGFILE
              fi
              ;;

            [Ss]) # -----------------------------------------------------------------------------------------
              echo ""
              { echo 'Interval='$Interval
                echo 'MaxSpeedInet='$MaxSpeedInet
                echo 'MaxSpeedInetUL='$MaxSpeedInetUL
                echo 'MaxSpeedLAN='$MaxSpeedLAN
                echo 'MaxSpeed24Ghz='$MaxSpeed24Ghz
                echo 'MaxSpeed5Ghz='$MaxSpeed5Ghz
                echo 'MaxSpeed6Ghz='$MaxSpeed6Ghz
                echo 'TempUnits="'"$TempUnits"'"'
                echo 'Speedtst='$Speedtst
                echo 'spdtestsvrID='$spdtestsvrID
                echo 'WANOverride="'"$WANOverride"'"'
                echo 'WAN0AltModes='$WAN0AltModes
                echo 'VPNSite2Site='$VPNSite2Site
                echo 'LOGSIZE='$LOGSIZE
              } > $CFGPATH
              echo -e "\n${CClear}Applying config changes to RTRMON..."
              echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: New Config file was successfully written." >> $LOGFILE
              sleep 3
              return
            ;;

            [Ee]) # -----------------------------------------------------------------------------------------
              return
            ;;

          esac
    done

  else
      #Create a new config file with default values to get it to a basic running state
      { echo 'Interval=10'
        echo 'MaxSpeedInet=1000'
        echo 'MaxSpeedInetUL=50'
        echo 'MaxSpeedLAN=1000'
        echo 'MaxSpeed24Ghz=450'
        echo 'MaxSpeed5Ghz=780'
        echo 'MaxSpeed6Ghz=920'
        echo 'TempUnits="C"'
        echo 'Speedtst=0'
        echo 'spdtestsvrID=0'
        echo 'WANOverride="Auto"'
        echo 'WAN0AltModes=0'
        echo 'VPNSite2Site=0'
        echo 'LOGSIZE=2000'
      } > $CFGPATH

      #Re-run rtrmon -config to restart setup process
      vconfig

  fi

}

# -------------------------------------------------------------------------------------------------------------------------

# vuninstall is a function that uninstalls and removes all traces of RTRMON from your router...
vuninstall () {
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} Uninstall Utility                                                                     ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} You are about to uninstall RTRMON!  This action is irreversible."
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo ""
  echo -e "Do you wish to proceed?${CClear}"
  if promptyn "[y/n]: "; then
    echo ""
    echo -e "\nAre you sure? Please type 'Y' to validate you want to proceed.${CClear}"
      if promptyn "[y/n]: "; then
        clear
        rm -r /jffs/addons/rtrmon.d
        rm /jffs/scripts/rtrmon.sh
        echo ""
        echo -e "\nRTRMON has been uninstalled...${CClear}"
        echo ""
        exit 0
      else
        echo ""
        echo -e "\nExiting Uninstall Utility...${CClear}"
        sleep 1
        return
      fi
  else
    echo ""
    echo -e "\nExiting Uninstall Utility...${CClear}"
    sleep 1
    return
  fi
}


# -------------------------------------------------------------------------------------------------------------------------

# vupdate is a function that provides a UI to check for script updates and allows you to install the latest version...
vupdate () {
  updatecheck # Check for the latest version from source repository
  clear
  echo -e "${InvGreen} ${InvDkGray}${CWhite} Update Utility                                                                        ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} This utility allows you to check, download and install updates"
  echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
  echo ""
  echo -e "Current Version: ${CGreen}$Version${CClear}"
  echo -e "Updated Version: ${CGreen}$DLVersion${CClear}"
  echo ""
  if [ "$Version" == "$DLVersion" ]
    then
      echo -e "You are on the latest version! Would you like to download anyways?${CClear}"
      echo -e "This will overwrite your local copy with the current build.${CClear}"
      if promptyn "[y/n]: "; then
        echo ""
        echo ""
        echo -e "Downloading RTRMON ${CGreen}v$DLVersion${CClear}"
        curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/RTRMON/master/rtrmon.sh" -o "/jffs/scripts/rtrmon.sh" && chmod 755 "/jffs/scripts/rtrmon.sh"
        echo ""
        echo -e "Download successful!${CClear}"
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: Successfully downloaded RTRMON v$DLVersion." >> $LOGFILE
        echo ""
        read -rsp $'Press any key to continue...\n' -n1 key
        exec sh /jffs/scripts/rtrmon.sh -monitor
      else
        echo ""
        echo ""
        echo -e "Exiting Update Utility...${CClear}"
        sleep 1
        return
      fi
    else
      echo -e "Score! There is a new version out there! Would you like to update?${CClear}"
      if promptyn "[y/n]: "; then
        echo ""
        echo ""
        echo -e "Downloading RTRMON ${CYellow}v$DLVersion${CClear}"
        curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/RTRMON/master/rtrmon.sh" -o "/jffs/scripts/rtrmon.sh" && chmod 755 "/jffs/scripts/rtrmon.sh"
        echo ""
        echo -e "Download successful!${CClear}"
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: Successfully downloaded RTRMON v$DLVersion." >> $LOGFILE
        echo ""
        read -rsp $'Press any key to continue...\n' -n1 key
        exec sh /jffs/scripts/rtrmon.sh -monitor
      else
        echo ""
        echo ""
        echo -e "Exiting Update Utility...${CClear}"
        sleep 1
        return
      fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
##----------------------------------------##
## Modified by Martinski W. [2024-Nov-02] ##
##----------------------------------------##
# Function that sets up, configures and allows you to launch RTRMON on your router...
vsetup()
{
  _SetUpTimeoutCmdVars_

  # Check for and add an alias for RTRMON #
  if ! grep -F "sh /jffs/scripts/rtrmon.sh" /jffs/configs/profile.add >/dev/null 2>/dev/null; then
     echo "alias rtrmon=\"sh /jffs/scripts/rtrmon.sh\" # RTRMON" >> /jffs/configs/profile.add
  fi

  while true
  do
    clear
    echo -e "${InvGreen} ${InvDkGray}${CWhite} RTRMON Main Setup and Configuration Menu                                              ${CClear}"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} Please choose from the various options below, which allow you to perform high level${CClear}"
    echo -e "${InvGreen} ${CClear} actions in the management of the RTRMON script.${CClear}"
    echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(1)${CClear} : Setup and Configure RTRMON"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(2)${CClear} : Force Re-install Entware Dependencies"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(3)${CClear} : Check for latest updates"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(4)${CClear} : View logs"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(5)${CClear} : Uninstall"
    if [ "$FromUI" == "0" ]; then
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} | ${CClear}"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(6)${CClear} : Launch RTRMON into Normal Monitoring Mode"
      echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(7)${CClear} : Launch RTRMON into Normal Monitoring Mode w/ SCREEN"
    fi
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite} | ${CClear}"
    echo -e "${InvGreen} ${CClear} ${InvDkGray}${CWhite}(e)${CClear} : Exit"
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
    echo ""
    if [ "$FromUI" == "0" ]; then
      read -p "Please select? (1-7, e=Exit): " InstallSelection
    else
      read -p "Please select? (1-5, e=Exit): " InstallSelection
    fi

    # Execute chosen selections
        case "$InstallSelection" in

          1) # Check for existence of entware, and if so proceed and install the timeout package, then run RTRMON -config
            clear
            if [ -f "/opt/bin/column" ] && [ -f "/opt/bin/timeout" ] && [ -f "/opt/sbin/screen" ] && [ -f "/opt/bin/nmap" ] && [ -f "/opt/bin/jq" ] && [ -f "/opt/bin/iftop" ]
            then
              vconfig
            else
              echo -e "${InvGreen} ${InvDkGray}${CWhite} Install Dependencies                                                                  ${CClear}"
              echo -e "${InvGreen} ${CClear}"
              echo -e "${InvGreen} ${CClear} Missing dependencies required by RTRMON will be installed during this process."
              echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
              echo ""
              echo -e "RTRMON will require the installation of CoreUtils-Timeout, Screen and Nmap utilities."
              echo -e "These utilities require you to have Entware already installed using the AMTM tool. If"
              echo -e "Entware is present, the Timeout, Screen and Nmap utilities will be downloaded and"
              echo -e "installed during this setup process, and utilized by RTRMON."
              echo ""
              echo -e "${CGreen}CoreUtils-Timeout${CClear} is a utility that provides more stability for certain routers (like"
              echo -e "the RT-AC86U) which has a tendency to randomly hang scripts running on this router model."
              echo ""
              echo -e "${CGreen}Screen${CClear} is a utility that allows you to run SSH scripts in a standalone"
              echo -e "environment directly on the router itself, instead of running your commands or a script"
              echo -e "from a network-attached SSH client. This can provide greater stability due to it running"
              echo -e "from the router itself."
              echo ""
              echo -e "${CGreen}Nmap${CClear} is a network discovery and security auditing tool that is used to scan your LAN,"
              echo -e "WAN and VPN connections for open ports."
              echo ""
              echo -e "${CGreen}JQuery${CClear} is a utility for querying data across the internet for the purposes of"
              echo -e "interacting with the various VPN providers to get a list of APIs available VPN hosts in"
              echo -e "the selected country."
              echo ""
              echo -e "${CGreen}iftop${CClear} is a utility for querying connection and bandwidth data."
              echo ""
              echo -e "${CGreen}Column${CClear} is a utility used to neatly arrange data on screen."
              echo ""
              echo -e "Your router model is: ${CGreen}${RouterModel}${CClear}"
              echo ""
              echo -e "Ready to install?"
              if promptyn "[y/n]: "
              then
                  if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
                    echo ""
                    echo -e "\n${CClear}Updating Entware Packages..."
                    echo ""
                    opkg update
                    echo ""
                    echo -e "Installing Entware ${CGreen}CoreUtils-Timeout${CClear} Package..."
                    echo ""
                    opkg install coreutils-timeout
                    echo ""
                    echo -e "Installing Entware ${CGreen}Screen Package${CClear}..."
                    echo ""
                    opkg install screen
                    echo ""
                    echo -e "Installing Entware ${CGreen}Nmap${CClear} Package..."
                    echo ""
                    opkg install nmap
                    echo ""
                    echo -e "Installing Entware ${CGreen}JQuery${CClear} Package..."
                    echo ""
                    opkg install jq
                    echo ""
                    echo -e "Installing Entware ${CGreen}iftop${CClear} Package..."
                    echo ""
                    opkg install iftop
                    echo ""
                    echo -e "Installing Entware ${CGreen}Column${CClear} Package..."
                    echo ""
                    opkg install column
                    echo ""
                    echo -e "Install completed..."
                    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: Entware dependencies were successfully installed." >> $LOGFILE
                    echo ""
                    read -rsp $'Press any key to continue...\n' -n1 key
                    echo ""
                    echo -e "Executing RTRMON Configuration Utility..."
                    sleep 2
                    vconfig
                  else
                    clear
                    echo -e "${CRed}ERROR: Entware was not found on this router...${CClear}"
                    echo -e "Please install Entware using the AMTM utility before proceeding..."
                    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - ERROR: Entware was not found on this router. Please install using AMTM utility." >> $LOGFILE
                    echo ""
                    sleep 3
                  fi
                else
                  echo ""
                  echo -e "\nExecuting RTRMON Configuration Utility..."
                  sleep 2
                  vconfig
              fi
            fi
          ;;


          2) # Force re-install the CoreUtils timeout/screen package
            clear
            echo -e "${InvGreen} ${InvDkGray}${CWhite} Re-install Dependencies                                                               ${CClear}"
            echo -e "${InvGreen} ${CClear}"
            echo -e "${InvGreen} ${CClear} Missing dependencies required by RTRMON will be re-installed during this process."
            echo -e "${InvGreen} ${CClear}${CDkGray}---------------------------------------------------------------------------------------${CClear}"
            echo ""
            echo -e "VPNMON-R3 has some dependencies in order to function correctly, namely, CoreUtils-Timeout"
            echo -e "RTRMON will require the installation of CoreUtils-Timeout, Screen, Nmap, JQ and iftop"
            echo -e "utilities. These utilities require you to have Entware already installed using AMTM. If"
            echo -e "Entware is present, the Timeout, Screen, Nmap, JQ and iftop utilities will be downloaded"
            echo -e "and re-installed during this setup process, and utilized by RTRMON."
            echo ""
            echo -e "${CGreen}CoreUtils-Timeout${CClear} is a utility that provides more stability for certain routers (like"
            echo -e "the RT-AC86U) which has a tendency to randomly hang scripts running on this router model."
            echo ""
            echo -e "${CGreen}Screen${CClear} is a utility that allows you to run SSH scripts in a standalone"
            echo -e "environment directly on the router itself, instead of running your commands or a script"
            echo -e "from a network-attached SSH client. This can provide greater stability due to it running"
            echo -e "from the router itself."
            echo ""
            echo -e "${CGreen}Nmap${CClear} is a network discovery and security auditing tool that is used to scan your LAN,"
            echo -e "WAN and VPN connections for open ports."
            echo ""
            echo -e "${CGreen}JQuery${CClear} is a utility for querying data across the internet for the purposes of"
            echo -e "interacting with the various VPN providers to get a list of APIs available VPN hosts in"
            echo -e "the selected country."
            echo ""
            echo -e "${CGreen}iftop${CClear} is a utility for querying connection and bandwidth data."
            echo ""
            echo -e "${CGreen}Column${CClear} is a utility used to neatly arrange data on screen."
            echo ""
            echo -e "Your router model is: ${CGreen}${RouterModel}${CClear}"
            echo ""
            echo -e "Force Re-install?"
            if promptyn "[y/n]: "
            then
                if [ -d "/opt" ]; then # Does entware exist? If yes proceed, if no error out.
                  echo ""
                  echo -e "\n${CClear}Updating Entware Packages..."
                  echo ""
                  opkg update
                  echo ""
                  echo -e "Force Re-installing Entware ${CGreen}CoreUtils-Timeout${CClear} Package..."
                  echo ""
                  opkg install --force-reinstall coreutils-timeout
                  echo ""
                  echo -e "Force Re-installing Entware ${CGreen}Screen${CClear} Package..."
                  echo ""
                  opkg install --force-reinstall screen
                  echo ""
                  echo -e "Force Re-installing Entware ${CGreen}Nmap${CClear} Package..."
                  echo ""
                  opkg install --force-reinstall nmap
                  echo ""
                  echo -e "Force Re-installing Entware ${CGreen}JQuery${CClear} Package..."
                  echo ""
                  opkg install --force-reinstall jq
                  echo ""
                  echo -e "Force Re-installing Entware ${CGreen}iftop${CClear} Package..."
                  echo ""
                  opkg install --force-reinstall iftop
                  echo ""
                  echo -e "Force Re-installing Entware ${CGreen}Column${CClear} Package..."
                  echo ""
                  opkg install --force-reinstall column
                  echo ""
                  echo -e "Re-install completed..."
                  echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: Entware dependencies were successfully re-installed." >> $LOGFILE
                  echo ""
                  read -rsp $'Press any key to continue...\n' -n1 key
                else
                  clear
                  echo -e "${CRed}ERROR: Entware was not found on this router...${CClear}"
                  echo -e "Please install Entware using the AMTM utility before proceeding..."
                  echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - ERROR: Entware was not found on this router. Please install using AMTM utility." >> $LOGFILE
                  echo ""
                  sleep 3
                fi
            fi
          ;;

          3)
            echo ""
            vupdate
          ;;

          6)
            echo ""
            echo -e "\n${CGreen}Launching RTRMON into Monitor Mode...${CClear}"
            sleep 2
            exec sh $APPPATH -monitor
          ;;

          7)
            echo ""
            echo -e "\n${CGreen}Launching RTRMON into Monitor Mode with Screen Utility...${CClear}"
            sleep 2
            exec sh $APPPATH -screen
          ;;

          4)
            echo ""
            vlogs
          ;;

          5)
            echo ""
            vuninstall
          ;;

          [Ee])
            echo -e "${CClear}"
            timer="$Interval"
            break
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

# get_wan_setting was "borrowed" graciously from @dave14305 from his FlexQoS script to determine the active WAN connection.
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

# gettopstats gathers the majority of cpu and memory related stats directly from the TOP utility
##----------------------------------------##
## Modified by Martinski W. [2024-Nov-02] ##
##----------------------------------------##
gettopstats ()
{
   local numFields

   TotalMem="$(top -bn1 | head -n3 | grep -E '^Mem:|^CPU:|^Load' | awk 'NR==1 {print $2, $4, $6, $8, $10} NR==2 {print $2, $4, $6, $8, $14} NR==3 {print $3, $4, $5}' 2>/dev/null)"

   numFields="$(echo $TotalMem | awk -F ' '  '{print NF}')"
   [ "$numFields" -lt 13 ] && return 1

   memused="$(echo $TotalMem | awk '{print $1}' | sed 's/K$//')"
   memfree="$(echo $TotalMem | awk '{print $2}' | sed 's/K$//')"
   memshrd="$(echo $TotalMem | awk '{print $3}' | sed 's/K$//')"
   membuff="$(echo $TotalMem | awk '{print $4}' | sed 's/K$//')"
   memcach="$(echo $TotalMem | awk '{print $5}' | sed 's/K$//')"
   cpuusr="$(echo $TotalMem | awk '{print $6}' | sed 's/%$//' | cut -d . -f 1)"
   cpusys="$(echo $TotalMem | awk '{print $7}' | sed 's/%$//' | cut -d . -f 1)"
   cpunice="$(echo $TotalMem | awk '{print $8}' | sed 's/%$//' | cut -d . -f 1)"
   cpuidle="$(echo $TotalMem | awk '{print $9}' | sed 's/%$//' | cut -d . -f 1)"
   cpuirq="$(echo $TotalMem | awk '{print $10}' | sed 's/%$//' | cut -d . -f 1)"
   displaycpuusr="$(echo $TotalMem | awk '{print $6}' | sed 's/%$//')"
   displaycpusys="$(echo $TotalMem | awk '{print $7}' | sed 's/%$//')"
   displaycpunice="$(echo $TotalMem | awk '{print $8}' | sed 's/%$//')"
   displaycpuidle="$(echo $TotalMem | awk '{print $9}' | sed 's/%$//')"
   displaycpuirq="$(echo $TotalMem | awk '{print $10}' | sed 's/%$//')"
   cpuload1m="$(echo $TotalMem | awk '{print $11}')"
   cpuload5m="$(echo $TotalMem | awk '{print $12}')"
   cpuload15m="$(echo $TotalMem | awk '{print $13}')"

   memused1="$((memused1 + memused))"
   memfree1="$((memfree1 + memfree))"
   memshrd1="$((memshrd1 + memshrd))"
   membuff1="$((membuff1 + membuff))"
   memcach1="$((memcach1 + memcach))"
   cpuusr1="$((cpuusr1 + cpuusr))"
   cpusys1="$((cpusys1 + cpusys))"
   cpunice1="$((cpunice1 + cpunice))"
   cpuidle1="$((cpuidle1 + cpuidle))"
   cpuirq1="$((cpuirq1 + cpuirq))"

   displaycpuusr1="$(awk -v v1=$displaycpuusr1 -v v2=$displaycpuusr 'BEGIN{printf "%0.2f\n", v1+v2}')"
   displaycpusys1="$(awk -v v1=$displaycpusys1 -v v2=$displaycpusys 'BEGIN{printf "%0.2f\n", v1+v2}')"
   displaycpunice1="$(awk -v v1=$displaycpunice1 -v v2=$displaycpunice 'BEGIN{printf "%0.2f\n", v1+v2}')"
   displaycpuidle1="$(awk -v v1=$displaycpuidle1 -v v2=$displaycpuidle 'BEGIN{printf "%0.2f\n", v1+v2}')"
   displaycpuirq1="$(awk -v v1=$displaycpuirq1 -v v2=$displaycpuirq 'BEGIN{printf "%0.2f\n", v1+v2}')"

   return 0
}

# -------------------------------------------------------------------------------------------------------------------------

# oldstats holds the old (current) stats that are being used to display stats on-screen
oldstats()
{
  oldcpuusr1=$cpuusr1
  oldcpusys1=$cpusys1
  oldcpunice1=$cpunice1
  oldcpuidle1=$cpuidle1
  oldcpuirq1=$cpuirq1
  olddisplaycpuusr1=$displaycpuusr1
  olddisplaycpusys1=$displaycpusys1
  olddisplaycpunice1=$displaycpunice1
  olddisplaycpuidle1=$displaycpuidle1
  olddisplaycpuirq1=$displaycpuirq1
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
  if [ "$WAN0AltModes" == "0" ] || [ "$OpsMode" == "1" ]; then
     oldwan0ip=$wan0ip
     oldwan1ip=$wan1ip
  fi
  olddns1ip=$dns1ip
  olddns2ip=$dns2ip
  oldwanip6=$wanip6
  oldlanip6=$lanip6
  if [ "$WAN0AltModes" == "0" ] || [ "$OpsMode" == "1" ]; then
     oldwanrxmbrate=$wanrxmbrate
     oldwantxmbrate=$wantxmbrate
  fi
  oldw24rxmbrate=$w24rxmbrate
  oldw24txmbrate=$w24txmbrate
  oldw5rxmbrate=$w5rxmbrate
  oldw5txmbrate=$w5txmbrate
  oldw24temp=$w24temp
  oldw5temp=$w5temp
  if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2455" == "True" ]; then
     oldw52rxmbrate=$w52rxmbrate
     oldw52txmbrate=$w52txmbrate
     oldw52temp=$w52temp
  fi
  if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2456" == "True" ] || [ "$FourBandCustom56624" == "True" ]; then
     oldw6rxmbrate=$w6rxmbrate
     oldw6txmbrate=$w6txmbrate
     oldw6temp=$w6temp
  fi
  if [ "$FourBandCustom56624" == "True" ]; then
     oldw62rxmbrate=$w62rxmbrate
     oldw62txmbrate=$w62txmbrate
     oldw62temp=$w62temp
  fi

  oldlanip=$lanip
  oldlanrxmbrate=$lanrxmbrate
  oldlantxmbrate=$lantxmbrate

  oldvpnrxmbrate=$vpnrxmbrate
  oldvpntxmbrate=$vpntxmbrate
  oldvpn2rxmbrate=$vpn2rxmbrate
  oldvpn2txmbrate=$vpn2txmbrate
  oldvpn3rxmbrate=$vpn3rxmbrate
  oldvpn3txmbrate=$vpn3txmbrate
  oldvpn4rxmbrate=$vpn4rxmbrate
  oldvpn4txmbrate=$vpn4txmbrate
  oldvpn5rxmbrate=$vpn5rxmbrate
  oldvpn5txmbrate=$vpn5txmbrate
  oldvpnip=$vpnip
  oldvpncity=$vpncity
  oldvpn2ip=$vpn2ip
  oldvpn2city=$vpn2city
  oldvpn3ip=$vpn3ip
  oldvpn3city=$vpn3city
  oldvpn4ip=$vpn4ip
  oldvpn4city=$vpn4city
  oldvpn5ip=$vpn5ip
  oldvpn5city=$vpn5city

  oldwg1rxmbrate=$wg1rxmbrate
  oldwg1txmbrate=$wg1txmbrate
  oldwg2rxmbrate=$wg2rxmbrate
  oldwg2txmbrate=$wg2txmbrate
  oldwg3rxmbrate=$wg3rxmbrate
  oldwg3txmbrate=$wg3txmbrate
  oldwg4rxmbrate=$wg4rxmbrate
  oldwg4txmbrate=$wg4txmbrate
  oldwg5rxmbrate=$wg5rxmbrate
  oldwg5txmbrate=$wg5txmbrate
  oldwg1ip=$wg1ip
  oldwg1city=$wg1city
  oldwg2ip=$wg2ip
  oldwg2city=$wg2city
  oldwg3ip=$wg3ip
  oldwg3city=$wg3city
  oldwg4ip=$wg4ip
  oldwg4city=$wg4city
  oldwg5ip=$wg5ip
  oldwg5city=$wg5city

  if [ "$WAN0AltModes" == "0" ] || [ "$OpsMode" == "1" ]; then
     oldwanrxmbratedisplay=$wanrxmbratedisplay
     oldwantxmbratedisplay=$wantxmbratedisplay
  fi
  oldw24rxmbratedisplay=$w24rxmbratedisplay
  oldw24txmbratedisplay=$w24txmbratedisplay
  oldw5rxmbratedisplay=$w5rxmbratedisplay
  oldw5txmbratedisplay=$w5txmbratedisplay
  if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2455" == "True" ]; then
     oldw52rxmbratedisplay=$w52rxmbratedisplay
     oldw52txmbratedisplay=$w52txmbratedisplay
  fi
  if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2456" == "True" ] || [ "$FourBandCustom56624" == "True" ]; then
     oldw6rxmbratedisplay=$w6rxmbratedisplay
     oldw6txmbratedisplay=$w6txmbratedisplay
  fi
  if [ "$FourBandCustom56624" == "True" ]; then
     oldw62rxmbratedisplay=$w62rxmbratedisplay
     oldw62txmbratedisplay=$w62txmbratedisplay
  fi
  oldlanrxmbratedisplay=$lanrxmbratedisplay
  oldlantxmbratedisplay=$lantxmbratedisplay

  oldvpnrxmbratedisplay=$vpnrxmbratedisplay
  oldvpntxmbratedisplay=$vpntxmbratedisplay
  oldvpn2rxmbratedisplay=$vpn2rxmbratedisplay
  oldvpn2txmbratedisplay=$vpn2txmbratedisplay
  oldvpn3rxmbratedisplay=$vpn3rxmbratedisplay
  oldvpn3txmbratedisplay=$vpn3txmbratedisplay
  oldvpn4rxmbratedisplay=$vpn4rxmbratedisplay
  oldvpn4txmbratedisplay=$vpn4txmbratedisplay
  oldvpn5rxmbratedisplay=$vpn5rxmbratedisplay
  oldvpn5txmbratedisplay=$vpn5txmbratedisplay

  oldwg1rxmbratedisplay=$wg1rxmbratedisplay
  oldwg1txmbratedisplay=$wg1txmbratedisplay
  oldwg2rxmbratedisplay=$wg2rxmbratedisplay
  oldwg2txmbratedisplay=$wg2txmbratedisplay
  oldwg3rxmbratedisplay=$wg3rxmbratedisplay
  oldwg3txmbratedisplay=$wg3txmbratedisplay
  oldwg4rxmbratedisplay=$wg4rxmbratedisplay
  oldwg4txmbratedisplay=$wg4txmbratedisplay
  oldwg5rxmbratedisplay=$wg5rxmbratedisplay
  oldwg5txmbratedisplay=$wg5txmbratedisplay
}

# -------------------------------------------------------------------------------------------------------------------------
##----------------------------------------##
## Modified by Martinski W. [2024-Nov-04] ##
##----------------------------------------##
# Calculates and captures, well, all the current stats from their sources  ;)
calculatestats()
{
   RM_END_TIME="$(date +%s)"
   RM_ELAPSED_TIME=$((RM_END_TIME - RM_START_TIME))
   [ "$RM_ELAPSED_TIME" -eq 0 ] && return 1

   # CPU - Usage
   if [ -n "$cpuusr1" ]; then cpuusr1=$((cpuusr1 / Interval)); else cpuusr1=0; fi
   if [ -n "$cpusys1" ]; then cpusys1=$((cpusys1 / Interval)); else cpusys1=0; fi
   if [ -n "$cpunice1" ]; then cpunice1=$((cpunice1 / Interval)); else cpunice1=0; fi
   if [ -n "$cpuidle1" ]; then cpuidle1=$((cpuidle1 / Interval)); else cpuidle1=0; fi
   if [ -n "$cpuirq1" ]; then cpuirq1=$((cpuirq1 / Interval)); else cpuirq1=0; fi
   if [ -n "$displaycpuusr1" ]; then displaycpuusr1=$(awk -v rb=$displaycpuusr1 -v intv=$Interval 'BEGIN{printf "%0.2f\n", rb/intv}'); else displaycpuusr1=0; fi
   if [ -n "$displaycpusys1" ]; then displaycpusys1=$(awk -v rb=$displaycpusys1 -v intv=$Interval 'BEGIN{printf "%0.2f\n", rb/intv}'); else displaycpusys1=0; fi
   if [ -n "$displaycpunice1" ]; then displaycpunice1=$(awk -v rb=$displaycpunice1 -v intv=$Interval 'BEGIN{printf "%0.2f\n", rb/intv}'); else displaycpunice1=0; fi
   if [ -n "$displaycpuidle1" ]; then displaycpuidle1=$(awk -v rb=$displaycpuidle1 -v intv=$Interval 'BEGIN{printf "%0.2f\n", rb/intv}'); else displaycpuidle1=0; fi
   if [ -n "$displaycpuirq1" ]; then displaycpuirq1=$(awk -v rb=$displaycpuirq1 -v intv=$Interval 'BEGIN{printf "%0.2f\n", rb/intv}'); else displaycpuirq1=0; fi

   # CPU - Temp - borrowed from @Maverickcdn - thank you!
   if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
      F_cputemp=$($timeoutcmd$timeoutsec cat /sys/class/thermal/thermal_zone0/temp | cut -c -2)
   elif [ -f /proc/dmu/temperature ]; then # Thanks to PeterR for the bug report on AC68U's - hopefully this will fix that
      F_cputemp=$($timeoutcmd$timeoutsec cat /proc/dmu/temperature | cut -c19-20)
   fi

    # Memory - Usage
    if [ -n "$memused1" ]; then memused1=$((memused1 / Interval)); else memused1=0; fi
    if [ -n "$memfree1" ]; then memfree1=$((memfree1 / Interval)); else memfree1=0; fi
    if [ -n "$memshrd1" ]; then memshrd1=$((memshrd1 / Interval)); else memshrd1=0; fi
    if [ -n "$membuff1" ]; then membuff1=$((membuff1 / Interval)); else membuff1=0; fi
    if [ -n "$memcach1" ]; then memcach1=$((memcach1 / Interval)); else memcach1=0; fi

    memused2="$((memused1 / 1000))"
    memfree2="$((memfree1 / 1000))"
    memshrd2="$((memshrd1 / 1000))"
    membuff2="$((membuff1 / 1000))"
    memcach2="$((memcach1 / 1000))"
    totalmemory="$(((memused1 + memfree1) / 1000))"

    totalphysmem=$(/usr/bin/free | awk 'NR==2 {print $2}' 2>/dev/null)
    totalphysmem="$((totalphysmem / 1000))"

    # Memory - NVRAM --  Many thanks to @RMerlin, @SomewhereOverTheRainbow and @Ranger802004 for your help finding NVRAM stats
    eval "$($timeoutcmd$timeoutsec nvram show >/tmp/output.txt 2> /tmp/size.txt)"
    chmod 755 /tmp/size.txt
    nvramtotals=$(cat /tmp/size.txt | grep size: | awk '{print $2, $4}' 2>/dev/null)
    nvramused="$(echo $nvramtotals | awk '{print $1}')"
    nvramfree="$(echo $nvramtotals | awk '{print $2}' | sed 's/[)(]//g')"
    if [ -z $nvramused ] || [ -z $nvramfree ]; then
       nvramused=10000 # incase the values coming back from this file are blank, use temporary fillers
       totalnvram=20000
    else
       totalnvram="$((nvramused + nvramfree))"
    fi

    # Disk - JFFS
    disk_use=$($timeoutcmd$timeoutsec df -P | grep -E '/jffs' | awk '{print $2, $3}')
    jffstotal="$(echo $disk_use | awk '{print $1}')"
    jffsused="$(echo $disk_use | awk '{print $2}')"
    jffstotal="$(($jffstotal / 1000))"
    jffsused="$(($jffsused / 1000))"

    # Disk - Swap file
    swap_use=$($timeoutcmd$timeoutsec /usr/bin/free | awk 'NR==4 {print $2, $3}' 2>/dev/null)
    swaptotal="$(echo $swap_use | awk '{print $1}')"
    swapused="$(echo $swap_use | awk '{print $2}')"
    swaptotal="$(($swaptotal / 1000))"
    swapused="$(($swapused / 1000))"
    if [ $swaptotal == "0" ]; then swaptotal=100; fi

    # Disk - SD devices
    df | grep /dev/sd > /jffs/addons/rtrmon.d/sdresult.txt 2>/dev/null

    # Network - WAN/LAN/DNS IP Addresses
    if [ "$WAN0AltModes" == "0" ] || [ "$OpsMode" == "1" ]
    then
       wan0ip=$($timeoutcmd$timeoutsec nvram get wan0_ipaddr)
       wan1ip=$($timeoutcmd$timeoutsec nvram get wan1_ipaddr)
    fi
    lanip=$($timeoutcmd$timeoutsec nvram get lan_ipaddr)
    dns1ip="$($timeoutcmd$timeoutsec nvram get wan0_dns | awk '{print $1}')"
    dns2ip="$($timeoutcmd$timeoutsec nvram get wan0_dns | awk '{print $2}')"
    dns3ip="$($timeoutcmd$timeoutsec nvram get wan1_dns | awk '{print $1}')"
    dns4ip="$($timeoutcmd$timeoutsec nvram get wan1_dns | awk '{print $2}')"

    # Network - VPN Client Ports and IP Addresses
    vpn1slot=1
    VPNState="$(_VPN_GetClientState_ ${vpn1slot})"
    if [ -z "$VPNState" ]; then VPNState=0; fi # to catch possible wireguard interference
    if [ "$VPNState" -eq 2 ]; then
      TUN="tun1"$vpn1slot
      NVRAMVPNADDR="$($timeoutcmd$timeoutsec nvram get vpn_client"$vpn1slot"_addr)"
      NVRAMVPNIP="$(ping -c 1 -w 1 $NVRAMVPNADDR | awk -F '[()]' '/PING/ { print $2}')"

      if [ "$(echo "$NVRAMVPNIP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        vpnip="$NVRAMVPNIP"
        vpncity="Private Network"
      else
        lastvpnip="$oldvpnip"
        if [ "$VPNSite2Site" == "1" ]; then
          vpnip="$NVRAMVPNIP"
        else
          vpnip="$(curl --silent --fail --interface $TUN --request GET --url https://ipv4.icanhazip.com)" # Grab the public IP of the VPN Connection
        fi
        if [ -z "$vpnip" ]; then vpnip="$NVRAMVPNIP" ; fi
        if [ "$lastvpnip" != "$vpnip" ]; then
          vpncity="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$vpnip | jq --raw-output .city"
          vpncity="$(eval $vpncity)"; if echo $vpncity | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then vpncity="Undetermined"; fi
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - API call made to determine geolocation of VPN$vpn1slot: $vpnip ($vpncity)" >> $LOGFILE
        fi
      fi
      vpn1on="True"
    else
      vpn1on="False"
    fi

    #Check to see if there's a 2nd VPN connection
    vpn2slot=2
    VPN2State="$(_VPN_GetClientState_ ${vpn2slot})"
    if [ -z "$VPN2State" ]; then VPN2State=0; fi # to catch possible wireguard interference
    if [ "$VPN2State" -eq 2 ]; then
      TUN2="tun1"$vpn2slot
      NVRAMVPN2ADDR="$($timeoutcmd$timeoutsec nvram get vpn_client"$vpn2slot"_addr)"
      NVRAMVPN2IP="$(ping -c 1 -w 1 $NVRAMVPN2ADDR | awk -F '[()]' '/PING/ { print $2}')"

      if [ "$(echo "$NVRAMVPN2IP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        vpn2ip="$NVRAMVPN2IP"
        vpn2city="Private Network"
      else
        lastvpn2ip="$oldvpn2ip"
        vpn2ip=$(curl --silent --fail --interface $TUN2 --request GET --url https://ipv4.icanhazip.com) # Grab the public IP of the VPN Connection
        if [ -z "$vpn2ip" ]; then vpn2ip=$NVRAMVPN2IP; fi
        if [ "$lastvpn2ip" != "$vpn2ip" ]; then
          vpn2city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$vpn2ip | jq --raw-output .city"
          vpn2city="$(eval $vpn2city)"; if echo $vpn2city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then vpn2city="Undetermined"; fi
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - API call made to determine geolocation of VPN$vpn2slot: $vpn2ip ($vpn2city)" >> $LOGFILE
        fi
      fi
      vpn2on="True"
    else
      vpn2on="False"
    fi

    #Check to see if there's a 3rd VPN connection
    vpn3slot=3
    VPN3State="$(_VPN_GetClientState_ ${vpn3slot})"
    if [ -z "$VPN3State" ]; then VPN3State=0; fi # to catch possible wireguard interference
    if [ "$VPN3State" -eq 2 ]; then
      TUN3="tun1"$vpn3slot
      NVRAMVPN3ADDR="$($timeoutcmd$timeoutsec nvram get vpn_client"$vpn3slot"_addr)"
      NVRAMVPN3IP="$(ping -c 1 -w 1 $NVRAMVPN3ADDR | awk -F '[()]' '/PING/ { print $2}')"

      if [ "$(echo "$NVRAMVPN3IP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        vpn3ip="$NVRAMVPN3IP"
        vpn3city="Private Network"
      else
        lastvpn3ip="$oldvpn3ip"
        vpn3ip=$(curl --silent --fail --interface $TUN3 --request GET --url https://ipv4.icanhazip.com) # Grab the public IP of the VPN Connection
        if [ -z "$vpn3ip" ]; then vpn3ip=$NVRAMVPN3IP; fi
        if [ "$lastvpn3ip" != "$vpn3ip" ]; then
          vpn3city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$vpn3ip | jq --raw-output .city"
          vpn3city="$(eval $vpn3city)"; if echo $vpn3city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then vpn3city="Undetermined"; fi
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - API call made to determine geolocation of VPN$vpn3slot: $vpn3ip ($vpn3city)" >> $LOGFILE
        fi
      fi
      vpn3on="True"
    else
      vpn3on="False"
    fi

    #Check to see if there's a 4th VPN connection
    vpn4slot=4
    VPN4State="$(_VPN_GetClientState_ ${vpn4slot})"
    if [ -z "$VPN4State" ]; then VPN4State=0; fi # to catch possible wireguard interference
    if [ "$VPN4State" -eq 2 ]; then
      TUN4="tun1"$vpn4slot
      NVRAMVPN4ADDR="$($timeoutcmd$timeoutsec nvram get vpn_client"$vpn4slot"_addr)"
      NVRAMVPN4IP="$(ping -c 1 -w 1 $NVRAMVPN4ADDR | awk -F '[()]' '/PING/ { print $2}')"

      if [ "$(echo "$NVRAMVPN4IP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        vpn4ip="$NVRAMVPN4IP"
        vpn4city="Private Network"
      else
        lastvpn4ip="$oldvpn4ip"
        vpn4ip=$(curl --silent --fail --interface $TUN4 --request GET --url https://ipv4.icanhazip.com) # Grab the public IP of the VPN Connection
        if [ -z "$vpn4ip" ]; then vpn4ip=$NVRAMVPN4IP; fi
        if [ "$lastvpn4ip" != "$vpn4ip" ]; then
          vpn4city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$vpn4ip | jq --raw-output .city"
          vpn4city="$(eval $vpn4city)"; if echo $vpn4city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then vpn4city="Undetermined"; fi
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - API call made to determine geolocation of VPN$vpn4slot: $vpn4ip ($vpn4city)" >> $LOGFILE
        fi
      fi
      vpn4on="True"
    else
      vpn4on="False"
    fi

    #Check to see if there's a 5th VPN connection
    vpn5slot=5
    VPN5State="$(_VPN_GetClientState_ ${vpn5slot})"
    if [ -z "$VPN5State" ]; then VPN5State=0; fi # to catch possible wireguard interference
    if [ "$VPN5State" -eq 2 ]; then
      TUN5="tun1"$vpn5slot
      NVRAMVPN5ADDR="$($timeoutcmd$timeoutsec nvram get vpn_client"$vpn5slot"_addr)"
      NVRAMVPN5IP="$(ping -c 1 -w 1 $NVRAMVPN5ADDR | awk -F '[()]' '/PING/ { print $2}')"

      if [ "$(echo "$NVRAMVPN5IP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        vpn5ip="$NVRAMVPN5IP"
        vpn5city="Private Network"
      else
        lastvpn5ip="$oldvpn5ip"
        vpn5ip=$(curl --silent --fail --interface $TUN5 --request GET --url https://ipv4.icanhazip.com) # Grab the public IP of the VPN Connection
        if [ -z "$vpn5ip" ]; then vpn5ip=$NVRAMVPN5IP; fi
        if [ "$lastvpn5ip" != "$vpn5ip" ]; then
          vpn5city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$vpn5ip | jq --raw-output .city"
          vpn5city="$(eval $vpn5city)"; if echo $vpn5city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then vpn5city="Undetermined"; fi
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - API call made to determine geolocation of VPN$vpn5slot: $vpn5ip ($vpn5city)" >> $LOGFILE
        fi
      fi
      vpn5on="True"
    else
      vpn5on="False"
    fi

    #Check to see if there's a WGC1 connection
    wg1slot=1
    WG1State="$(_WG_GetClientState_ ${wg1slot})"
    if [ -z "$WG1State" ]; then WG1State=0; fi
    if [ "$WG1State" -eq 2 ]; then
      WGTUN1="wgc$wg1slot"
      WGTUN1_IP=$($timeoutcmd$timeoutsec nvram get "$WGTUN1"_addr | cut -d '/' -f1)

      # Added based on suggestion from @ZebMcKayhan
      ip rule add from $WGTUN1_IP lookup $WGTUN1 prio 10 >/dev/null 2>&1

      icanhazwg1ip="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$WGTUN1" --request GET --url https://ipv4.icanhazip.com"
      icanhazwg1ip="$(eval $icanhazwg1ip)"
      if [ -z "$icanhazwg1ip" ] || echo "$icanhazwg1ip" | grep -qoE 'Internet|traffic|Error|error'
      then
        NVRAMWG1IP="000.000.000.000"
      else
        NVRAMWG1IP="$icanhazwg1ip"
      fi

      # Added based on suggestion from @ZebMcKayhan
      ip rule del prio 10 >/dev/null 2>&1

      if [ "$(echo "$NVRAMWG1IP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        wg1ip="$NVRAMWG1IP"
        wg1city="Private Network"
      else
        lastwg1ip="$oldwg1ip"
        wg1ip="$NVRAMWG1IP"
        #if [ -z "$wg1ip" ]; then wg1ip=$WGTUN1_IP; fi
        if [ "$lastwg1ip" != "$wg1ip" ]; then
          wg1city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$wg1ip | jq --raw-output .city"
          wg1city="$(eval $wg1city)"; if echo $wg1city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then wg1city="Undetermined"; fi
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - API call made to determine geolocation of WG$wg1slot: $wg1ip ($wg1city)" >> $LOGFILE
        else
          wg1city="$oldwg1city"
        fi
      fi
      wg1on="True"
    else
      wg1on="False"
    fi

    #Check to see if there's a WGC2 connection
    wg2slot=2
    WG2State="$(_WG_GetClientState_ ${wg2slot})"
    if [ -z "$WG2State" ]; then WG2State=0; fi
    if [ "$WG2State" -eq 2 ]; then
      WGTUN2="wgc$wg2slot"
      WGTUN2_IP=$($timeoutcmd$timeoutsec nvram get "$WGTUN2"_addr | cut -d '/' -f1)

      # Added based on suggestion from @ZebMcKayhan
      ip rule add from $WGTUN2_IP lookup $WGTUN2 prio 10 >/dev/null 2>&1

      icanhazwg2ip="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$WGTUN2" --request GET --url https://ipv4.icanhazip.com"
      icanhazwg2ip="$(eval $icanhazwg2ip)"
      if [ -z "$icanhazwg2ip" ] || echo "$icanhazwg2ip" | grep -qoE 'Internet|traffic|Error|error'
      then
        NVRAMWG2IP="000.000.000.000"
      else
        NVRAMWG2IP="$icanhazwg2ip"
      fi

      # Added based on suggestion from @ZebMcKayhan
      ip rule del prio 10 >/dev/null 2>&1

      if [ "$(echo "$NVRAMWG2IP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        wg2ip="$NVRAMWG2IP"
        wg2city="Private Network"
      else
        lastwg2ip="$oldwg2ip"
        wg2ip="$NVRAMWG2IP"
        if [ "$lastwg2ip" != "$wg2ip" ]; then
          wg2city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$wg2ip | jq --raw-output .city"
          wg2city="$(eval $wg2city)"; if echo $wg2city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then wg2city="Undetermined"; fi
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - API call made to determine geolocation of WG$wg2slot: $wg2ip ($wg2city)" >> $LOGFILE
        else
          wg2city="$oldwg2city"
        fi
      fi
      wg2on="True"
    else
      wg2on="False"
    fi

    #Check to see if there's a WGC3 connection
    wg3slot=3
    WG3State="$(_WG_GetClientState_ ${wg3slot})"
    if [ -z "$WG3State" ]; then WG3State=0; fi
    if [ "$WG3State" -eq 2 ]; then
      WGTUN3="wgc$wg3slot"
      WGTUN3_IP=$($timeoutcmd$timeoutsec nvram get "$WGTUN3"_addr | cut -d '/' -f1)

      # Added based on suggestion from @ZebMcKayhan
      ip rule add from $WGTUN3_IP lookup $WGTUN3 prio 10 >/dev/null 2>&1

      icanhazwg3ip="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$WGTUN3" --request GET --url https://ipv4.icanhazip.com"
      icanhazwg3ip="$(eval $icanhazwg3ip)"
      if [ -z "$icanhazwg3ip" ] || echo "$icanhazwg3ip" | grep -qoE 'Internet|traffic|Error|error'
      then
        NVRAMWG3IP="000.000.000.000"
      else
        NVRAMWG3IP="$icanhazwg3ip"
      fi

      # Added based on suggestion from @ZebMcKayhan
      ip rule del prio 10 >/dev/null 2>&1

      if [ "$(echo "$NVRAMWG3IP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        wg3ip="$NVRAMWG3IP"
        wg3city="Private Network"
      else
        lastwg3ip="$oldwg3ip"
        wg3ip="$NVRAMWG3IP"
        if [ "$lastwg3ip" != "$wg3ip" ]; then
          wg3city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$wg3ip | jq --raw-output .city"
          wg3city="$(eval $wg3city)"; if echo $wg3city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then wg3city="Undetermined"; fi
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - API call made to determine geolocation of WG$wg3slot: $wg3ip ($wg3city)" >> $LOGFILE
        else
          wg3city="$oldwg3city"
        fi
      fi
      wg3on="True"
    else
      wg3on="False"
    fi

    #Check to see if there's a WGC4 connection
    wg4slot=4
    WG4State="$(_WG_GetClientState_ ${wg4slot})"
    if [ -z "$WG4State" ]; then WG4State=0; fi
    if [ "$WG4State" -eq 2 ]; then
      WGTUN4="wgc$wg4slot"
      WGTUN4_IP=$($timeoutcmd$timeoutsec nvram get "$WGTUN4"_addr | cut -d '/' -f1)

      # Added based on suggestion from @ZebMcKayhan
      ip rule add from $WGTUN4_IP lookup $WGTUN4 prio 10 >/dev/null 2>&1

      icanhazwg4ip="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$WGTUN4" --request GET --url https://ipv4.icanhazip.com"
      icanhazwg4ip="$(eval $icanhazwg4ip)"
      if [ -z "$icanhazwg4ip" ] || echo "$icanhazwg4ip" | grep -qoE 'Internet|traffic|Error|error'
      then
        NVRAMWG4IP="000.000.000.000"
      else
        NVRAMWG4IP="$icanhazwg4ip"
      fi

      # Added based on suggestion from @ZebMcKayhan
      ip rule del prio 10 >/dev/null 2>&1

      if [ "$(echo "$NVRAMWG4IP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        wg4ip="$NVRAMWG4IP"
        wg4city="Private Network"
      else
        lastwg4ip="$oldwg4ip"
        wg4ip="$NVRAMWG4IP"
        if [ "$lastwg4ip" != "$wg4ip" ]; then
          wg4city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$wg4ip | jq --raw-output .city"
          wg4city="$(eval $wg4city)"; if echo $wg4city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then wg4city="Undetermined"; fi
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - API call made to determine geolocation of WG$wg4slot: $wg4ip ($wg4city)" >> $LOGFILE
        else
          wg4city="$oldwg4city"
        fi
      fi
      wg4on="True"
    else
      wg4on="False"
    fi

    #Check to see if there's a WGC5 connection
    wg5slot=5
    WG5State="$(_WG_GetClientState_ ${wg5slot})"
    if [ -z "$WG5State" ]; then WG5State=0; fi
    if [ "$WG5State" -eq 2 ]; then
      WGTUN5="wgc$wg5slot"
      WGTUN5_IP=$($timeoutcmd$timeoutsec nvram get "$WGTUN5"_addr | cut -d '/' -f1)

      # Added based on suggestion from @ZebMcKayhan
      ip rule add from $WGTUN5_IP lookup $WGTUN5 prio 10 >/dev/null 2>&1

      icanhazwg5ip="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$WGTUN5" --request GET --url https://ipv4.icanhazip.com"
      icanhazwg5ip="$(eval $icanhazwg5ip)"
      if [ -z "$icanhazwg5ip" ] || echo "$icanhazwg5ip" | grep -qoE 'Internet|traffic|Error|error'
      then
        NVRAMWG5IP="000.000.000.000"
      else
        NVRAMWG5IP="$icanhazwg5ip"
      fi

      # Added based on suggestion from @ZebMcKayhan
      ip rule del prio 10 >/dev/null 2>&1

      if [ "$(echo "$NVRAMWG5IP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        wg5ip="$NVRAMWG5IP"
        wg5city="Private Network"
      else
        lastwg5ip="$oldwg5ip"
        wg5ip="$NVRAMWG5IP"
        if [ "$lastwg5ip" != "$wg5ip" ]; then
          wg5city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$wg5ip | jq --raw-output .city"
          wg5city="$(eval $wg5city)"; if echo $wg5city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then wg5city="Undetermined"; fi
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - API call made to determine geolocation of WG$wg5slot: $wg5ip ($wg5city)" >> $LOGFILE
        else
          wg5city="$oldwg5city"
        fi
      fi
      wg5on="True"
    else
      wg5on="False"
    fi

    if [ "$WAN0AltModes" == "0" ] || [ "$OpsMode" == "1" ]
    then
       if [ -z $wan0ip ]; then dns1ip="0.0.0.0"; fi
       if [ -z $wan1ip ]; then dns1ip="0.0.0.0"; fi
    fi
    if [ -z $lanip ]; then dns1ip="0.0.0.0"; fi
    if [ -z $dns1ip ]; then dns1ip="0.0.0.0"; fi
    if [ -z $dns2ip ]; then dns2ip="0.0.0.0"; fi
    if [ $dns1ip == "0.0.0.0" ] && [ ! -z $dns3ip ]; then dns1ip=$dns3ip; fi
    if [ $dns2ip == "0.0.0.0" ] && [ ! -z $dns4ip ]; then dns2ip=$dns4ip; fi
    if [ "$vpn1on" == "False" ]; then vpnip="0.0.0.0"; fi
    if [ "$vpn2on" == "False" ]; then vpn2ip="0.0.0.0"; fi
    if [ "$vpn3on" == "False" ]; then vpn3ip="0.0.0.0"; fi
    if [ "$vpn4on" == "False" ]; then vpn4ip="0.0.0.0"; fi
    if [ "$vpn5on" == "False" ]; then vpn5ip="0.0.0.0"; fi
    if [ "$wg1on" == "False" ]; then wg1ip="0.0.0.0"; fi
    if [ "$wg2on" == "False" ]; then wg2ip="0.0.0.0"; fi
    if [ "$wg3on" == "False" ]; then wg3ip="0.0.0.0"; fi
    if [ "$wg4on" == "False" ]; then wg4ip="0.0.0.0"; fi
    if [ "$wg5on" == "False" ]; then wg5ip="0.0.0.0"; fi

    # Many thanks to @SomewhereOverTheRainbow for his help and suggestions on getting IP6 info!
    if [ "$WAN0AltModes" == "0" ] || [ "$OpsMode" == "1" ]; then
       wanip6="$(ip -o -6 addr list "$WANIFNAME" scope global | awk 'NR==1{ split($4, ip_addr, "/"); print ip_addr[1] }')"
    fi
    lanip6="$(ip -o -6 addr list br0 scope global | awk 'NR==1{ split($4, ip_addr, "/"); print ip_addr[1] }')"

  # Network - Wifi - Temp
    # Standard Dual-Band config
    w24tempraw=$($timeoutcmd$timeoutsec wl -i $ifname24 phy_tempsense | awk '{print $1}' ) >/dev/null 2>&1
    w5tempraw=$($timeoutcmd$timeoutsec wl -i $ifname5 phy_tempsense | awk '{print $1}' ) >/dev/null 2>&1
    if [ -z $w24tempraw ] || [ $w24tempraw -eq 0 ]; then w24tempraw=1; fi  #in case it does not return a valid number
    if [ -z $w5tempraw ] || [ $w5tempraw -eq 0 ]; then w5tempraw=1; fi
    w24temp=$(awk -v v1=$w24tempraw 'BEGIN{printf "\n" (v1/2)+20}' | cut -d . -f 1)
    w5temp=$(awk -v v1=$w5tempraw 'BEGIN{printf "\n" (v1/2)+20}' | cut -d . -f 1)

    # Tri or Quad Band 5GHz
    if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2455" == "True" ]; then
       w52tempraw=$($timeoutcmd$timeoutsec wl -i $ifname52 phy_tempsense | awk '{print $1}' ) >/dev/null 2>&1
       if [ -z $w52tempraw ] || [ $w52tempraw -eq 0 ]; then w52tempraw=1; fi
       w52temp=$(awk -v v1=$w52tempraw 'BEGIN{printf "\n" (v1/2)+20}' | cut -d . -f 1)
    fi
    # Tri or Quad-Band 6GHz
    if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2456" == "True" ] || [ "$FourBandCustom56624" == "True" ]; then
       w6tempraw=$($timeoutcmd$timeoutsec wl -i $ifname6 phy_tempsense | awk '{print $1}' ) >/dev/null 2>&1
       if [ -z $w6tempraw ] || [ $w6tempraw -eq 0 ]; then w6tempraw=1; fi
       w6temp=$(awk -v v1=$w6tempraw 'BEGIN{printf "\n" (v1/2)+20}' | cut -d . -f 1)
    fi
    if [ "$FourBandCustom56624" == "True" ]; then
       w62tempraw=$($timeoutcmd$timeoutsec wl -i $ifname62 phy_tempsense | awk '{print $1}' ) >/dev/null 2>&1
       if [ -z $w62tempraw ] || [ $w62tempraw -eq 0 ]; then w62tempraw=1; fi
       w62temp=$(awk -v v1=$w62tempraw 'BEGIN{printf "\n" (v1/2)+20}' | cut -d . -f 1)
    fi

  # Network - Wifi - Up/Down via Scheduler
  if [ "$FourBandCustom55624" == "True" ]; then
    if [ ! -z $($timeoutcmd$timeoutsec nvram get wl0_sched_v2) ]; then w5udsched="Scheduler[+]"; else w5udsched="Scheduler[-]"; fi
    if [ ! -z $($timeoutcmd$timeoutsec nvram get wl1_sched_v2) ]; then w52udsched="Scheduler[+]"; else w52udsched="Scheduler[-]"; fi
    if [ ! -z $($timeoutcmd$timeoutsec nvram get wl2_sched_v2) ]; then w6udsched="Scheduler[+]"; else w6udsched="Scheduler[-]"; fi
    if [ ! -z $($timeoutcmd$timeoutsec nvram get wl3_sched_v2) ]; then w24udsched="Scheduler[+]"; else w24udsched="Scheduler[-]"; fi
  elif [ "$FourBandCustom56624" == "True" ]; then
    if [ ! -z $($timeoutcmd$timeoutsec nvram get wl0_sched_v2) ]; then w5udsched="Scheduler[+]"; else w5udsched="Scheduler[-]"; fi
    if [ ! -z $($timeoutcmd$timeoutsec nvram get wl1_sched_v2) ]; then w6udsched="Scheduler[+]"; else w6udsched="Scheduler[-]"; fi
    if [ ! -z $($timeoutcmd$timeoutsec nvram get wl2_sched_v2) ]; then w62udsched="Scheduler[+]"; else w62udsched="Scheduler[-]"; fi
    if [ ! -z $($timeoutcmd$timeoutsec nvram get wl3_sched_v2) ]; then w24udsched="Scheduler[+]"; else w24udsched="Scheduler[-]"; fi
  elif [ "$ThreeBand2456" == "True" ]; then
    if [ ! -z $($timeoutcmd$timeoutsec nvram get wl0_sched_v2) ]; then w24udsched="Scheduler[+]"; else w24udsched="Scheduler[-]"; fi
    if [ ! -z $($timeoutcmd$timeoutsec nvram get wl1_sched_v2) ]; then w5udsched="Scheduler[+]"; else w5udsched="Scheduler[-]"; fi
    if [ ! -z $($timeoutcmd$timeoutsec nvram get wl2_sched_v2) ]; then w6udsched="Scheduler[+]"; else w6udsched="Scheduler[-]"; fi
  elif [ "$ThreeBand2455" == "True" ]; then
    if [ ! -z $($timeoutcmd$timeoutsec nvram get wl0_sched_v2) ]; then w24udsched="Scheduler[+]"; else w24udsched="Scheduler[-]"; fi
    if [ ! -z $($timeoutcmd$timeoutsec nvram get wl1_sched_v2) ]; then w5udsched="Scheduler[+]"; else w5udsched="Scheduler[-]"; fi
    if [ ! -z $($timeoutcmd$timeoutsec nvram get wl2_sched_v2) ]; then w52udsched="Scheduler[+]"; else w52udsched="Scheduler[-]"; fi
  else
    if [ ! -z $($timeoutcmd$timeoutsec nvram get wl0_sched_v2) ]; then w24udsched="Scheduler[+]"; else w24udsched="Scheduler[-]"; fi
    if [ ! -z $($timeoutcmd$timeoutsec nvram get wl1_sched_v2) ]; then w5udsched="Scheduler[+]"; else w5udsched="Scheduler[-]"; fi
  fi

  w24updown=$($timeoutcmd$timeoutsec wl -i $ifname24 bss | awk '{print toupper($1)}' ) >/dev/null 2>&1
  w5updown=$($timeoutcmd$timeoutsec wl -i $ifname5 bss | awk '{print toupper($1)}' ) >/dev/null 2>&1
  if [ -z "$w24updown" ]; then w24updown="UP"; fi
  if [ -z "$w5updown" ]; then w5updown="UP"; fi

  # Tri or Quad Band 5GHz
  if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2455" == "True" ]; then
     w52updown=$($timeoutcmd$timeoutsec wl -i $ifname52 bss | awk '{print toupper($1)}' ) >/dev/null 2>&1
     if [ -z "$w52updown" ]; then w52updown="UP"; fi
  fi
  # Tri or Quad-Band 6GHz
  if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2456" == "True" ] || [ "$FourBandCustom56624" == "True" ]; then
     w6updown=$($timeoutcmd$timeoutsec wl -i $ifname6 bss | awk '{print toupper($1)}' ) >/dev/null 2>&1
     if [ -z $w6updown ]; then w6updown="UP"; fi
  fi
  if [ "$FourBandCustom56624" == "True" ]; then
     w62updown=$($timeoutcmd$timeoutsec wl -i $ifname62 bss | awk '{print toupper($1)}' ) >/dev/null 2>&1
     if [ -z $w62updown ]; then w62updown="UP"; fi
  fi

    # Network - Wifi - Traffic
    # Standard Dual Band
    new24rxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname24/statistics/rx_bytes)"
    new24txbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname24/statistics/tx_bytes)"
    new5rxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname5/statistics/rx_bytes)"
    new5txbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname5/statistics/tx_bytes)"

    # Tri or Quad Band 5GHz
    if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2455" == "True" ]
    then
       new52rxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname52/statistics/rx_bytes)"
       new52txbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname52/statistics/tx_bytes)"
    fi
    # Tri or Quad Band 6GHz
    if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2456" == "True" ] || [ "$FourBandCustom56624" == "True" ]
    then
       new6rxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname6/statistics/rx_bytes)"
       new6txbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname6/statistics/tx_bytes)"
    fi
    if [ "$FourBandCustom56624" == "True" ]
    then
       new62rxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname62/statistics/rx_bytes)"
       new62txbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname62/statistics/tx_bytes)"
    fi

    # Network - LAN - Traffic
    newlanrxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/br0/statistics/rx_bytes)"
    newlantxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/br0/statistics/tx_bytes)"

    # Network - WAN - Traffic
    if [ "$WAN0AltModes" == "0" ] || [ "$OpsMode" == "1" ]
    then
       if [ $WANOverride == "Auto" ]; then WANIFNAME=$(get_wan_setting ifname); else WANIFNAME=$WANOverride; fi
       newwanrxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$WANIFNAME/statistics/rx_bytes)"
       newwantxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$WANIFNAME/statistics/tx_bytes)"
    fi

    # Network - VPN - Traffic
    # Grab total bytes VPN Traffic Measurement
    if [ "$vpn1on" == "True" ]; then
      newvpntxrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client$vpn1slot/status 2>/dev/null)
      newvpnrxbytes="$(echo $newvpntxrxbytes | cut -d' ' -f1)"
      newvpntxbytes="$(echo $newvpntxrxbytes | cut -d' ' -f2)"
      if [ -z $newvpnrxbytes ]; then newvpnrxbytes=0; fi
      if [ -z $newvpntxbytes ]; then newvpntxbytes=0; fi

      if [ $newvpnrxbytes -le 0 ]; then
         newvpnrxbytes=0
      elif [ $newvpntxbytes -le 0 ]; then
         newvpntxbytes=0
      fi
    fi

    if [ "$vpn2on" == "True" ]; then
      newvpn2txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client$vpn2slot/status 2>/dev/null)
      newvpn2rxbytes="$(echo $newvpn2txrxbytes | cut -d' ' -f1)"
      newvpn2txbytes="$(echo $newvpn2txrxbytes | cut -d' ' -f2)"
      if [ -z $newvpn2rxbytes ]; then newvpn2rxbytes=0; fi
      if [ -z $newvpn2txbytes ]; then newvpn2txbytes=0; fi

      if [ $newvpn2rxbytes -le 0 ]; then
         newvpn2rxbytes=0
      elif [ $newvpn2txbytes -le 0 ]; then
         newvpn2txbytes=0
      fi
    fi

    if [ "$vpn3on" == "True" ]; then
      newvpn3txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client$vpn3slot/status 2>/dev/null)
      newvpn3rxbytes="$(echo $newvpn3txrxbytes | cut -d' ' -f1)"
      newvpn3txbytes="$(echo $newvpn3txrxbytes | cut -d' ' -f2)"
      if [ -z $newvpn3rxbytes ]; then newvpn3rxbytes=0; fi
      if [ -z $newvpn3txbytes ]; then newvpn3txbytes=0; fi

      if [ $newvpn3rxbytes -le 0 ]; then
         newvpn3rxbytes=0
      elif [ $newvpn3txbytes -le 0 ]; then
         newvpn3txbytes=0
      fi
    fi

    if [ "$vpn4on" == "True" ]; then
      newvpn4txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client$vpn4slot/status 2>/dev/null)
      newvpn4rxbytes="$(echo $newvpn4txrxbytes | cut -d' ' -f1)"
      newvpn4txbytes="$(echo $newvpn4txrxbytes | cut -d' ' -f2)"
      if [ -z $newvpn4rxbytes ]; then newvpn4rxbytes=0; fi
      if [ -z $newvpn4txbytes ]; then newvpn4txbytes=0; fi

      if [ $newvpn4rxbytes -le 0 ]; then
         newvpn4rxbytes=0
      elif [ $newvpn4txbytes -le 0 ]; then
         newvpn4txbytes=0
      fi
    fi

    if [ "$vpn5on" == "True" ]; then
      newvpn5txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client$vpn5slot/status 2>/dev/null)
      newvpn5rxbytes="$(echo $newvpn5txrxbytes | cut -d' ' -f1)"
      newvpn5txbytes="$(echo $newvpn5txrxbytes | cut -d' ' -f2)"
      if [ -z $newvpn5rxbytes ]; then newvpn5rxbytes=0; fi
      if [ -z $newvpn5txbytes ]; then newvpn5txbytes=0; fi

      if [ $newvpn5rxbytes -le 0 ]; then
         newvpn5rxbytes=0
      elif [ $newvpn5txbytes -le 0 ]; then
         newvpn5txbytes=0
      fi
    fi

    # Check the wireguard connections
    if [ "$wg1on" == "True" ]; then
      newwg1txrxbytes=$(wg show wgc1 transfer)
      newwg1rxbytes="$(echo $newwg1txrxbytes | cut -d' ' -f3)"
      newwg1txbytes="$(echo $newwg1txrxbytes | cut -d' ' -f2)"
      if [ -z $newwg1rxbytes ] || [ $newwg1rxbytes -le 0 ]; then newwg1rxbytes=0; fi
      if [ -z $newwg1txbytes ] || [ $newwg1txbytes -le 0 ]; then newwg1txbytes=0; fi
    fi

    if [ "$wg2on" == "True" ]; then
      newwg2txrxbytes=$(wg show wgc2 transfer)
      newwg2rxbytes="$(echo $newwg2txrxbytes | cut -d' ' -f3)"
      newwg2txbytes="$(echo $newwg2txrxbytes | cut -d' ' -f2)"
      if [ -z $newwg2rxbytes ] || [ $newwg2rxbytes -le 0 ]; then newwg2rxbytes=0; fi
      if [ -z $newwg2txbytes ] || [ $newwg2txbytes -le 0 ]; then newwg2txbytes=0; fi
    fi

    if [ "$wg3on" == "True" ]; then
      newwg3txrxbytes=$(wg show wgc3 transfer)
      newwg3rxbytes="$(echo $newwg3txrxbytes | cut -d' ' -f3)"
      newwg3txbytes="$(echo $newwg3txrxbytes | cut -d' ' -f2)"
      if [ -z $newwg3rxbytes ] || [ $newwg3rxbytes -le 0 ]; then newwg3rxbytes=0; fi
      if [ -z $newwg3txbytes ] || [ $newwg3txbytes -le 0 ]; then newwg3txbytes=0; fi
    fi

    if [ "$wg4on" == "True" ]; then
      newwg4txrxbytes=$(wg show wgc4 transfer)
      newwg4rxbytes="$(echo $newwg4txrxbytes | cut -d' ' -f3)"
      newwg4txbytes="$(echo $newwg4txrxbytes | cut -d' ' -f2)"
      if [ -z $newwg4rxbytes ] || [ $newwg4rxbytes -le 0 ]; then newwg4rxbytes=0; fi
      if [ -z $newwg4txbytes ] || [ $newwg4txbytes -le 0 ]; then newwg4txbytes=0; fi
    fi

    if [ "$wg5on" == "True" ]; then
      newwg5txrxbytes=$(wg show wgc5 transfer)
      newwg5rxbytes="$(echo $newwg5txrxbytes | cut -d' ' -f3)"
      newwg5txbytes="$(echo $newwg5txrxbytes | cut -d' ' -f2)"
      if [ -z $newwg5rxbytes ] || [ $newwg5rxbytes -le 0 ]; then newwg5rxbytes=0; fi
      if [ -z $newwg5txbytes ] || [ $newwg5txbytes -le 0 ]; then newwg5txbytes=0; fi
    fi

    # Network - Traffic - Calculations to find the difference between old and new total bytes send/received and divided to give Megabits
    if [ "$WAN0AltModes" == "0" ] || [ "$OpsMode" == "1" ]; then
       diffwanrxbytes=$(awk -v new=$newwanrxbytes -v old=$oldwanrxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
       diffwantxbytes=$(awk -v new=$newwantxbytes -v old=$oldwantxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    fi
    diff24rxbytes=$(awk -v new=$new24rxbytes -v old=$old24rxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    diff24txbytes=$(awk -v new=$new24txbytes -v old=$old24txbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    diff5rxbytes=$(awk -v new=$new5rxbytes -v old=$old5rxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    diff5txbytes=$(awk -v new=$new5txbytes -v old=$old5txbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    difflanrxbytes=$(awk -v new=$newlanrxbytes -v old=$oldlanrxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    difflantxbytes=$(awk -v new=$newlantxbytes -v old=$oldlantxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2455" == "True" ]; then
       diff52rxbytes=$(awk -v new=$new52rxbytes -v old=$old52rxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
       diff52txbytes=$(awk -v new=$new52txbytes -v old=$old52txbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    fi
    if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2456" == "True" ] || [ "$FourBandCustom56624" == "True" ]; then
       diff6rxbytes=$(awk -v new=$new6rxbytes -v old=$old6rxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
       diff6txbytes=$(awk -v new=$new6txbytes -v old=$old6txbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    fi
    if [ "$FourBandCustom56624" == "True" ]; then
       diff62rxbytes=$(awk -v new=$new62rxbytes -v old=$old62rxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
       diff62txbytes=$(awk -v new=$new62txbytes -v old=$old62txbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    fi
    if [ "$vpn1on" == "True" ]; then
       diffvpnrxbytes=$(awk -v new=$newvpnrxbytes -v old=$oldvpnrxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
       diffvpntxbytes=$(awk -v new=$newvpntxbytes -v old=$oldvpntxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    fi
    if [ "$vpn2on" == "True" ]; then
       diffvpn2rxbytes=$(awk -v new=$newvpn2rxbytes -v old=$oldvpn2rxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
       diffvpn2txbytes=$(awk -v new=$newvpn2txbytes -v old=$oldvpn2txbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    fi
    if [ "$vpn3on" == "True" ]; then
       diffvpn3rxbytes=$(awk -v new=$newvpn3rxbytes -v old=$oldvpn3rxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
       diffvpn3txbytes=$(awk -v new=$newvpn3txbytes -v old=$oldvpn3txbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    fi
    if [ "$vpn4on" == "True" ]; then
       diffvpn4rxbytes=$(awk -v new=$newvpn4rxbytes -v old=$oldvpn4rxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
       diffvpn4txbytes=$(awk -v new=$newvpn4txbytes -v old=$oldvpn4txbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    fi
    if [ "$vpn5on" == "True" ]; then
       diffvpn5rxbytes=$(awk -v new=$newvpn5rxbytes -v old=$oldvpn5rxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
       diffvpn5txbytes=$(awk -v new=$newvpn5txbytes -v old=$oldvpn5txbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    fi
    if [ "$wg1on" == "True" ]; then
       diffwg1rxbytes=$(awk -v new=$newwg1rxbytes -v old=$oldwg1rxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
       diffwg1txbytes=$(awk -v new=$newwg1txbytes -v old=$oldwg1txbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    fi
    if [ "$wg2on" == "True" ]; then
       diffwg2rxbytes=$(awk -v new=$newwg2rxbytes -v old=$oldwg2rxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
       diffwg2txbytes=$(awk -v new=$newwg2txbytes -v old=$oldwg2txbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    fi
    if [ "$wg3on" == "True" ]; then
       diffwg3rxbytes=$(awk -v new=$newwg3rxbytes -v old=$oldwg3rxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
       diffwg3txbytes=$(awk -v new=$newwg3txbytes -v old=$oldwg3txbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    fi
    if [ "$wg4on" == "True" ]; then
       diffwg4rxbytes=$(awk -v new=$newwg4rxbytes -v old=$oldwg4rxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
       diffwg4txbytes=$(awk -v new=$newwg4txbytes -v old=$oldwg4txbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    fi
    if [ "$wg5on" == "True" ]; then
       diffwg5rxbytes=$(awk -v new=$newwg5rxbytes -v old=$oldwg5rxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
       diffwg5txbytes=$(awk -v new=$newwg5txbytes -v old=$oldwg5txbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    fi

    # Network - Traffic - Results are further divided by the timer/interval to give Megabits/sec
    if [ "$WAN0AltModes" = "0" ] || [ "$OpsMode" = "1" ]
    then
       wanrxmbrate=$(awk -v rb=$diffwanrxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
       wantxmbrate=$(awk -v tb=$diffwantxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    else
       wanrxmbrate=0
       wantxmbrate=0
    fi

    w24rxmbrate=$(awk -v rb=$diff24rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
    w24txmbrate=$(awk -v tb=$diff24txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    w5rxmbrate=$(awk -v rb=$diff5rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
    w5txmbrate=$(awk -v tb=$diff5txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    lanrxmbrate=$(awk -v rb=$difflanrxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
    lantxmbrate=$(awk -v tb=$difflantxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)

    if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2455" == "True" ]
    then
       w52rxmbrate=$(awk -v rb=$diff52rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
       w52txmbrate=$(awk -v tb=$diff52txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    else
       w52rxmbrate=0
       w52txmbrate=0
    fi
    if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2456" == "True" ] || [ "$FourBandCustom56624" == "True" ]
    then
       w6rxmbrate=$(awk -v rb=$diff6rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
       w6txmbrate=$(awk -v tb=$diff6txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    else
       w6rxmbrate=0
       w6txmbrate=0
    fi
    if [ "$FourBandCustom56624" == "True" ]
    then
       w62rxmbrate=$(awk -v rb=$diff62rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
       w62txmbrate=$(awk -v tb=$diff62txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    else
       w62rxmbrate=0
       w62txmbrate=0
    fi
    if [ "$vpn1on" == "True" ]
    then
       vpnrxmbrate=$(awk -v rb=$diffvpnrxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
       vpntxmbrate=$(awk -v tb=$diffvpntxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    else
       vpnrxmbrate=0
       vpntxmbrate=0
    fi
    if [ "$vpn2on" == "True" ]
    then
       vpn2rxmbrate=$(awk -v rb=$diffvpn2rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
       vpn2txmbrate=$(awk -v tb=$diffvpn2txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    else
       vpn2rxmbrate=0
       vpn2txmbrate=0
    fi
    if [ "$vpn3on" == "True" ]
    then
       vpn3rxmbrate=$(awk -v rb=$diffvpn3rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
       vpn3txmbrate=$(awk -v tb=$diffvpn3txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    else
       vpn3rxmbrate=0
       vpn3txmbrate=0
    fi
    if [ "$vpn4on" == "True" ]
    then
       vpn4rxmbrate=$(awk -v rb=$diffvpn4rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
       vpn4txmbrate=$(awk -v tb=$diffvpn4txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    else
       vpn4rxmbrate=0
       vpn4txmbrate=0
    fi
    if [ "$vpn5on" == "True" ]
    then
       vpn5rxmbrate=$(awk -v rb=$diffvpn5rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
       vpn5txmbrate=$(awk -v tb=$diffvpn5txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    else
       vpn5rxmbrate=0
       vpn5txmbrate=0
    fi
    if [ "$wg1on" == "True" ]
    then
       wg1rxmbrate=$(awk -v rb=$diffwg1rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
       wg1txmbrate=$(awk -v tb=$diffwg1txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    else
       wg1rxmbrate=0
       wg1txmbrate=0
    fi
    if [ "$wg2on" == "True" ]
    then
       wg2rxmbrate=$(awk -v rb=$diffwg2rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
       wg2txmbrate=$(awk -v tb=$diffwg2txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    else
       wg2rxmbrate=0
       wg2txmbrate=0
    fi
    if [ "$wg3on" == "True" ]
    then
       wg3rxmbrate=$(awk -v rb=$diffwg3rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
       wg3txmbrate=$(awk -v tb=$diffwg3txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    else
       wg3rxmbrate=0
       wg3txmbrate=0
    fi
    if [ "$wg4on" == "True" ]
    then
       wg4rxmbrate=$(awk -v rb=$diffwg4rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
       wg4txmbrate=$(awk -v tb=$diffwg4txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    else
       wg4rxmbrate=0
       wg4txmbrate=0
    fi
    if [ "$wg5on" == "True" ]
    then
       wg5rxmbrate=$(awk -v rb=$diffwg5rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
       wg5txmbrate=$(awk -v tb=$diffwg5txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    else
       wg5rxmbrate=0
       wg5txmbrate=0
    fi
    if [ "$WAN0AltModes" == "0" ] || [ "$OpsMode" == "1" ]
    then
       wanrxmbratedisplay=$(awk -v rb=$diffwanrxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
       wantxmbratedisplay=$(awk -v tb=$diffwantxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
    fi

    w24rxmbratedisplay=$(awk -v rb=$diff24rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
    w24txmbratedisplay=$(awk -v tb=$diff24txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
    w5rxmbratedisplay=$(awk -v rb=$diff5rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
    w5txmbratedisplay=$(awk -v tb=$diff5txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
    lanrxmbratedisplay=$(awk -v rb=$difflanrxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
    lantxmbratedisplay=$(awk -v tb=$difflantxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')

    if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2455" == "True" ]
    then
       w52rxmbratedisplay=$(awk -v rb=$diff52rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
       w52txmbratedisplay=$(awk -v tb=$diff52txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
    else
       w52rxmbratedisplay=""
       w52txmbratedisplay=""
    fi
    if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2456" == "True" ] || [ "$FourBandCustom56624" == "True" ]
    then
       w6rxmbratedisplay=$(awk -v rb=$diff6rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
       w6txmbratedisplay=$(awk -v tb=$diff6txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
    else
       w6rxmbratedisplay=""
       w6txmbratedisplay=""
    fi
    if [ "$FourBandCustom56624" == "True" ]
    then
       w62rxmbratedisplay=$(awk -v rb=$diff62rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
       w62txmbratedisplay=$(awk -v tb=$diff62txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
    else
       w62rxmbratedisplay=""
       w62txmbratedisplay=""
    fi
    if [ "$vpn1on" == "True" ]
    then
       vpnrxmbratedisplay=$(awk -v rb=$diffvpnrxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
       vpntxmbratedisplay=$(awk -v tb=$diffvpntxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
    else
       vpnrxmbratedisplay=""
       vpntxmbratedisplay=""
    fi
    if [ "$vpn2on" == "True" ]
    then
       vpn2rxmbratedisplay=$(awk -v rb=$diffvpn2rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
       vpn2txmbratedisplay=$(awk -v tb=$diffvpn2txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
    else
       vpn2rxmbratedisplay=""
       vpn2txmbratedisplay=""
    fi
    if [ "$vpn3on" == "True" ]
    then
       vpn3rxmbratedisplay=$(awk -v rb=$diffvpn3rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
       vpn3txmbratedisplay=$(awk -v tb=$diffvpn3txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
    else
       vpn3rxmbratedisplay=""
       vpn3txmbratedisplay=""
    fi
    if [ "$vpn4on" == "True" ]
    then
       vpn4rxmbratedisplay=$(awk -v rb=$diffvpn4rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
       vpn4txmbratedisplay=$(awk -v tb=$diffvpn4txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
    else
       vpn4rxmbratedisplay=""
       vpn4txmbratedisplay=""
    fi
    if [ "$vpn5on" == "True" ]
    then
       vpn5rxmbratedisplay=$(awk -v rb=$diffvpn5rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
       vpn5txmbratedisplay=$(awk -v tb=$diffvpn5txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
    else
       vpn5rxmbratedisplay=""
       vpn5txmbratedisplay=""
    fi
    if [ "$wg1on" == "True" ]
    then
       wg1rxmbratedisplay=$(awk -v rb=$diffwg1rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
       wg1txmbratedisplay=$(awk -v tb=$diffwg1txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
    else
       wg1rxmbratedisplay=""
       wg1txmbratedisplay=""
    fi
    if [ "$wg2on" == "True" ]
    then
       wg2rxmbratedisplay=$(awk -v rb=$diffwg2rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
       wg2txmbratedisplay=$(awk -v tb=$diffwg2txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
    else
       wg2rxmbratedisplay=""
       wg2txmbratedisplay=""
    fi
    if [ "$wg3on" == "True" ]
    then
       wg3rxmbratedisplay=$(awk -v rb=$diffwg3rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
       wg3txmbratedisplay=$(awk -v tb=$diffwg3txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
    else
       wg3rxmbratedisplay=""
       wg3txmbratedisplay=""
    fi
    if [ "$wg4on" == "True" ]
    then
       wg4rxmbratedisplay=$(awk -v rb=$diffwg4rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
       wg4txmbratedisplay=$(awk -v tb=$diffwg4txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
    else
       wg4rxmbratedisplay=""
       wg4txmbratedisplay=""
    fi
    if [ "$wg5on" == "True" ]
    then
       wg5rxmbratedisplay=$(awk -v rb=$diffwg5rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
       wg5txmbratedisplay=$(awk -v tb=$diffwg5txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
    else
       wg5rxmbratedisplay=""
       wg5txmbratedisplay=""
    fi

    # Uptime calc #
    uptimeStr="$(awk '{printf("%3dd %02dh %02dm %02ds\n",($1/60/60/24),($1/60/60%24),($1/60%60),($1%60))}' /proc/uptime)"
}

# -------------------------------------------------------------------------------------------------------------------------

# This function displays the stats UI for page 1
DisplayPage1()
{
  clear
  if [ "$UpdateNotify" != "0" ]; then
    echo -e "$UpdateNotify${CClear}"
  fi
  showheader
  echo ""
  echo -e "${InvDkGray}${CWhite} CPU                                                                                                           ${CClear}"
  echo ""
  echo -e "${InvGreen} ${CClear} ${CWhite}Uptime     ${CDkGray}[                               ${CWhite}$uptimeStr${CDkGray}                                ]${CClear}"
  echo -e "${InvGreen} ${CClear} ${CWhite}CPU Load   ${CDkGray}[                         ${CGreen}1m: ${CWhite}$cpuload1m  ${CGreen}5m: ${CWhite}$cpuload5m  ${CGreen}15m: ${CWhite}$cpuload15m${CDkGray}                         ]${CClear}"
  preparebar 79 "|"
  progressbar $oldcpuusr1 100 " CPU User  " "%%" "Standard" $olddisplaycpuusr1
  echo ""
  preparebar 79 "|"
  progressbar $oldcpusys1 100 " CPU System" "%%" "Standard" $olddisplaycpusys1
  echo ""
  preparebar 79 "|"
  progressbar $oldcpunice1 100 " CPU Nice  " "%%" "Standard" $olddisplaycpunice1
  echo ""
  preparebar 79 "|"
  progressbar $oldcpuidle1 100 " CPU Idle  " "%%" "Reverse" $olddisplaycpuidle1
  echo ""
  preparebar 79 "|"
  progressbar $oldcpuirq1 100 " CPU IRQ   " "%%" "Standard" $olddisplaycpuirq1
  echo ""
  preparebar 79 "|"
  converttemps $oldF_cputemp
  progressbar $currenttemp $currentrange " CPU Temp  " $TempUnits "CPU" $currenttemp $currentrange
  echo ""
  echo ""
  echo -e "${InvDkGray}${CWhite} Memory                                                                                                        ${CClear}"
  echo ""
  echo -en "${InvGreen} ${CClear} ${CWhite}Mem Total  ${CDkGray}[                                    ${CWhite}"
  printf "%-7s" "$totalphysmem MB"
  echo -e "${CDkGray}                                    ]${CClear}"
  preparebar 79 "|"
  progressbar $oldmemused2 $oldtotalmemory " Mem Used  " "MB" "Standard"
  echo ""
  preparebar 79 "|"
  progressbar $oldmemfree2 $oldtotalmemory " Mem Free  " "MB" "Reverse"
  echo ""
  preparebar 79 "|"
  progressbar $oldmemshrd2 $oldtotalmemory " Mem Shared" "MB" "Standard"
  echo ""
  preparebar 79 "|"
  progressbar $oldmembuff2 $oldtotalmemory " Mem Buffer" "MB" "Standard"
  echo ""
  preparebar 79 "|"
  progressbar $oldmemcach2 $oldtotalmemory " Mem Cache " "MB" "Standard"
  echo ""
  preparebar 79 "|"
  progressbar $oldnvramused $oldtotalnvram " NVRAM Used" "B" "Standard"
  echo ""
  echo ""
  echo -e "${InvDkGray}${CWhite} Disk                                                                                                          ${CClear}"
  echo ""
  echo -en "${InvGreen} ${CClear} ${CWhite}Swap Size  ${CDkGray}[                                    ${CWhite}"
  printf "%-8s" "$swaptotal MB"
  echo -e "${CDkGray}                                   ]${CClear}"
  preparebar 79 "|"
  progressbar $oldswapused $oldswaptotal " Swap Used " "MB" "Standard"
  echo ""
  preparebar 79 "|"
  progressbar $oldjffsused $oldjffstotal " JFFS Used " "MB" "Standard"

  #Disk - SD devices
  if [ -s /jffs/addons/rtrmon.d/sdresult.txt ]
  then
    sdcnt=$(cat /jffs/addons/rtrmon.d/sdresult.txt | wc -l) >/dev/null 2>&1
    if [ -z "$sdcnt" ] || [ $sdcnt -lt 1 ]; then
       sdcnt=0
    fi
  else
     sdcnt=0
  fi

  CNT=0
  while [ "$CNT" -lt "$sdcnt" ]  # Loop through number of /dev/sd*'s #
  do
    CNT="$((CNT+1))"
    dfresults="$(sed -n "${CNT}p" /jffs/addons/rtrmon.d/sdresult.txt)"
    if [ -z "$dfresults" ]; then break; fi
    sdname="$(echo $dfresults | awk '{print $1}')"
    sdtotal="$(echo $dfresults | awk '{print $2}')"
    sdused="$(echo $dfresults | awk '{print $3}')"

    sdtotal=$(echo "$sdtotal 1048576" | awk '{print $1/$2}' | cut -d . -f 1)
    sdused=$(echo "$sdused 1048576" | awk '{print $1/$2}' | cut -d . -f 1)
    if [ $sdtotal == "0" ]; then sdtotal=1; fi
    if [ $sdused == "0" ]; then sdused=1; fi
    sdnameformat=$(printf "%-10s" $sdname)

    echo ""
    preparebar 79 "|"
    progressbar $sdused $sdtotal " $sdnameformat" "GB" "Standard"
  done
}

# -------------------------------------------------------------------------------------------------------------------------

# This function displays the stats UI for page 2
DisplayPage2()
{
  clear
  if [ "$UpdateNotify" != "0" ]; then
    echo -e "$UpdateNotify${CClear}"
  fi
  showheader
  if [ "$WAN0AltModes" == "0" ] || [ "$OpsMode" == "1" ]; then
    echo ""
    echo -e "${InvDkGray}${CWhite} WAN                                                                                                           ${CClear}"
    echo ""
    if [ "$ScreenshotMode" == "1" ]; then
      oldwan0ip="1.2.3.4" #demo
      oldwanip6="abc1:23de::f456:ghi7:89jk:l0mn:opqr" #demo
      oldvpnip="2.3.4.5" #demo
      oldvpnip2="3.4.5.6" #demo
      oldvpnip3="4.5.6.7" #demo
      oldvpnip4="5.6.7.8" #demo
      oldvpnip5="6.7.8.9" #demo
      oldvpncity="Rivendell" #demo
      oldvpn2city="Mordor" #demo
      oldvpn3city="Minas Tirith" #demo
      oldvpn4city="Edoras" #demo
      oldvpn5city="Aglarond" #demo
    fi
    echo -en "${InvGreen} ${CClear} ${CWhite}WAN 0/1 IP ${CDkGray}[ ${CWhite}"
    printf '%03d.%03d.%03d.%03d'  ${oldwan0ip//./ }
    echo -en " / "
    printf '%03d.%03d.%03d.%03d'  ${oldwan1ip//./ }
    echo -en "${CDkGray} ] ${CWhite}  DNS ${CDkGray}[ ${CWhite}"
    if [ $olddns1ip = "0.0.0.0" ]; then printf "000.000.000.000"; else printf '%03d.%03d.%03d.%03d'  ${olddns1ip//./ }; fi
    echo -en " / "
    if [ $olddns2ip = "0.0.0.0" ]; then printf "000.000.000.000"; else printf '%03d.%03d.%03d.%03d'  ${olddns2ip//./ }; fi
    echo -e "${CDkGray} ] ${InvDkGray}${CWhite}IFace: $WANIFNAME${CClear}"
    if [ ! -z $oldwanip6 ]; then echo -e "${InvGreen} ${CClear} ${CWhite}WAN 0/1 I6 ${CDkGray}[ ${CWhite}$oldwanip6${CClear}"; fi
    preparebar 79 "|"
    progressbar $oldwanrxmbrate $MaxSpeedInet " Avg WAN RX" "Mbps" "Standard" $oldwanrxmbratedisplay $MaxSpeedInet
    echo ""
    preparebar 79 "|"
    progressbar $oldwantxmbrate $MaxSpeedInetUL " Avg WAN TX" "Mbps" "Standard" $oldwantxmbratedisplay $MaxSpeedInetUL
    echo ""
  fi
  echo ""
  echo -e "${InvDkGray}${CWhite} LAN                                                                                                           ${CClear}"
  echo ""
  echo -en "${InvGreen} ${CClear}${CWhite} BR0 LAN IP ${CDkGray}[ ${CWhite}"
  printf '%03d.%03d.%03d.%03d'  ${oldlanip//./ }
  echo -e "${CDkGray}                                                               ] ${InvDkGray}${CWhite}IFace: br0${CClear}"
  if [ ! -z $oldlanip6 ]; then echo -e "${InvGreen} ${CClear} ${CWhite}BR0 LAN I6 ${CDkGray}[ ${CWhite}$oldlanip6${CClear}"; fi

  preparebar 79 "|"
  progressbar $oldlanrxmbrate $MaxSpeedLAN " Avg LAN RX" "Mbps" "Standard" $oldlanrxmbratedisplay $MaxSpeedLAN
  echo ""
  preparebar 79 "|"
  if [ ${oldlantxmbrate%.*} -lt 0 ]; then oldlantxmbrate=0; oldlantxmbratedisplay=0; fi
  progressbar $oldlantxmbrate $MaxSpeedLAN " Avg LAN TX" "Mbps" "Standard" $oldlantxmbratedisplay $MaxSpeedLAN

  if [ "$vpn1on" == "True" ]; then
    echo ""
    echo ""
    echo -e "${InvDkGray}${CWhite} OVPN$vpn1slot                                                                                                         ${CClear}"
    echo ""
    if [ "$oldvpncity" == "Private Network" ]; then
      echo -en "${InvGreen} ${CClear}${CWhite} PRV VPN IP ${CDkGray}[ ${CWhite}"
      printf '%03d.%03d.%03d.%03d'  ${oldvpnip//./ }
      echo -en "${CDkGray}                   ]  ${CWhite}CITY ${CDkGray}[ ${CWhite}"

      printf "%-33s" "$oldvpncity"

      echo -e "${CDkGray} ] ${InvDkGray}${CWhite}TUN: tun1$vpn1slot${CClear}"
    else
      echo -en "${InvGreen} ${CClear}${CWhite} PUB VPN IP ${CDkGray}[ ${CWhite}"
      printf '%03d.%03d.%03d.%03d'  ${oldvpnip//./ }
      echo -en "${CDkGray}                   ]  ${CWhite}CITY ${CDkGray}[ ${CWhite}"

      printf "%-33s" "$oldvpncity"

      echo -e "${CDkGray} ] ${InvDkGray}${CWhite}TUN: tun1$vpn1slot${CClear}"
    fi
    if [ ${oldvpntxmbrate%.*} -lt 0 ]; then oldvpntxmbrate=0; oldvpntxmbratedisplay=0; fi
    preparebar 79 "|"
    progressbar $oldvpntxmbrate $MaxSpeedInet " Avg VPN RX" "Mbps" "Standard" $oldvpntxmbratedisplay $MaxSpeedInet
    echo ""
    if [ ${oldvpnrxmbrate%.*} -lt 0 ]; then oldvpnrxmbrate=0; oldvpnrxmbratedisplay=0; fi
    preparebar 79 "|"
    progressbar $oldvpnrxmbrate $MaxSpeedInetUL " Avg VPN TX" "Mbps" "Standard" $oldvpnrxmbratedisplay $MaxSpeedInetUL
  fi

  if [ "$vpn2on" == "True" ]; then
    echo ""
    echo ""
    echo -e "${InvDkGray}${CWhite} OVPN$vpn2slot                                                                                                         ${CClear}"
    echo ""
    if [ "$oldvpn2city" == "Private Network" ]; then
      echo -en "${InvGreen} ${CClear}${CWhite} PRV VPN IP ${CDkGray}[ ${CWhite}"
      printf '%03d.%03d.%03d.%03d'  ${oldvpn2ip//./ }
      echo -en "${CDkGray}                   ]  ${CWhite}CITY ${CDkGray}[ ${CWhite}"

      printf "%-33s" "$oldvpn2city"

      echo -e "${CDkGray} ] ${InvDkGray}${CWhite}TUN: tun1$vpn2slot${CClear}"
    else
      echo -en "${InvGreen} ${CClear}${CWhite} PUB VPN IP ${CDkGray}[ ${CWhite}"
      printf '%03d.%03d.%03d.%03d'  ${oldvpn2ip//./ }
      echo -en "${CDkGray}                   ]  ${CWhite}CITY ${CDkGray}[ ${CWhite}"

      printf "%-33s" "$oldvpn2city"

      echo -e "${CDkGray} ] ${InvDkGray}${CWhite}TUN: tun1$vpn2slot${CClear}"
    fi
    if [ ${oldvpn2txmbrate%.*} -lt 0 ]; then oldvpn2txmbrate=0; oldvpn2txmbratedisplay=0; fi
    preparebar 79 "|"
    progressbar $oldvpn2txmbrate $MaxSpeedInet " Avg VPN RX" "Mbps" "Standard" $oldvpn2txmbratedisplay $MaxSpeedInet
    echo ""
    if [ ${oldvpn2rxmbrate%.*} -lt 0 ]; then oldvpn2rxmbrate=0; oldvpn2rxmbratedisplay=0; fi
    preparebar 79 "|"
    progressbar $oldvpn2rxmbrate $MaxSpeedInetUL " Avg VPN TX" "Mbps" "Standard" $oldvpn2rxmbratedisplay $MaxSpeedInetUL
  fi

  if [ "$vpn3on" == "True" ]; then
    echo ""
    echo ""
    echo -e "${InvDkGray}${CWhite} OVPN$vpn3slot                                                                                                         ${CClear}"
    echo ""
    if [ "$oldvpn3city" == "Private Network" ]; then
      echo -en "${InvGreen} ${CClear}${CWhite} PRV VPN IP ${CDkGray}[ ${CWhite}"
      printf '%03d.%03d.%03d.%03d'  ${oldvpn3ip//./ }
      echo -en "${CDkGray}                   ]  ${CWhite}CITY ${CDkGray}[ ${CWhite}"

      printf "%-33s" "$oldvpn3city"

      echo -e "${CDkGray} ] ${InvDkGray}${CWhite}TUN: tun1$vpn3slot${CClear}"
    else
      echo -en "${InvGreen} ${CClear}${CWhite} PUB VPN IP ${CDkGray}[ ${CWhite}"
      printf '%03d.%03d.%03d.%03d'  ${oldvpn3ip//./ }
      echo -en "${CDkGray}                   ]  ${CWhite}CITY ${CDkGray}[ ${CWhite}"

      printf "%-33s" "$oldvpn3city"

      echo -e "${CDkGray} ] ${InvDkGray}${CWhite}TUN: tun1$vpn3slot${CClear}"
    fi
    if [ ${oldvpn3txmbrate%.*} -lt 0 ]; then oldvpn3txmbrate=0; oldvpn3txmbratedisplay=0; fi
    preparebar 79 "|"
    progressbar $oldvpn3txmbrate $MaxSpeedInet " Avg VPN RX" "Mbps" "Standard" $oldvpn3txmbratedisplay $MaxSpeedInet
    echo ""
    if [ ${oldvpn3rxmbrate%.*} -lt 0 ]; then oldvpn3rxmbrate=0; oldvpn3rxmbratedisplay=0; fi
    preparebar 79 "|"
    progressbar $oldvpn3rxmbrate $MaxSpeedInetUL " Avg VPN TX" "Mbps" "Standard" $oldvpn3rxmbratedisplay $MaxSpeedInetUL
  fi

  if [ "$vpn4on" == "True" ]; then
    echo ""
    echo ""
    echo -e "${InvDkGray}${CWhite} OVPN$vpn4slot                                                                                                         ${CClear}"
    echo ""
    if [ "$oldvpn4city" == "Private Network" ]; then
      echo -en "${InvGreen} ${CClear}${CWhite} PRV VPN IP ${CDkGray}[ ${CWhite}"
      printf '%03d.%03d.%03d.%03d'  ${oldvpn4ip//./ }
      echo -en "${CDkGray}                   ]  ${CWhite}CITY ${CDkGray}[ ${CWhite}"

      printf "%-33s" "$oldvpn4city"

      echo -e "${CDkGray} ] ${InvDkGray}${CWhite}TUN: tun1$vpn4slot${CClear}"
    else
      echo -en "${InvGreen} ${CClear}${CWhite} PUB VPN IP ${CDkGray}[ ${CWhite}"
      printf '%03d.%03d.%03d.%03d'  ${oldvpn4ip//./ }
      echo -en "${CDkGray}                   ]  ${CWhite}CITY ${CDkGray}[ ${CWhite}"

      printf "%-33s" "$oldvpn4city"

      echo -e "${CDkGray} ] ${InvDkGray}${CWhite}TUN: tun1$vpn4slot${CClear}"
    fi
    if [ ${oldvpn4txmbrate%.*} -lt 0 ]; then oldvpn4txmbrate=0; oldvpn4txmbratedisplay=0; fi
    preparebar 79 "|"
    progressbar $oldvpn4txmbrate $MaxSpeedInet " Avg VPN RX" "Mbps" "Standard" $oldvpn4txmbratedisplay $MaxSpeedInet
    echo ""
    if [ ${oldvpn4rxmbrate%.*} -lt 0 ]; then oldvpn4rxmbrate=0; oldvpn4rxmbratedisplay=0; fi
    preparebar 79 "|"
    progressbar $oldvpn4rxmbrate $MaxSpeedInetUL " Avg VPN TX" "Mbps" "Standard" $oldvpn4rxmbratedisplay $MaxSpeedInetUL
  fi

  if [ "$vpn5on" == "True" ]; then
    echo ""
    echo ""
    echo -e "${InvDkGray}${CWhite} OVPN$vpn5slot                                                                                                         ${CClear}"
    echo ""
    if [ "$oldvpn5city" == "Private Network" ]; then
      echo -en "${InvGreen} ${CClear}${CWhite} PRV VPN IP ${CDkGray}[ ${CWhite}"
      printf '%03d.%03d.%03d.%03d'  ${oldvpn5ip//./ }
      echo -en "${CDkGray}                   ]  ${CWhite}CITY ${CDkGray}[ ${CWhite}"

      printf "%-33s" "$oldvpn5city"

      echo -e "${CDkGray} ] ${InvDkGray}${CWhite}TUN: tun1$vpn5slot${CClear}"
    else
      echo -en "${InvGreen} ${CClear}${CWhite} PUB VPN IP ${CDkGray}[ ${CWhite}"
      printf '%03d.%03d.%03d.%03d'  ${oldvpn5ip//./ }
      echo -en "${CDkGray}                   ]  ${CWhite}CITY ${CDkGray}[ ${CWhite}"

      printf "%-33s" "$oldvpn5city"

      echo -e "${CDkGray} ] ${InvDkGray}${CWhite}TUN: tun1$vpn5slot${CClear}"
    fi
    if [ ${oldvpn5txmbrate%.*} -lt 0 ]; then oldvpn5txmbrate=0; oldvpn5txmbratedisplay=0; fi
    preparebar 79 "|"
    progressbar $oldvpn5txmbrate $MaxSpeedInet " Avg VPN RX" "Mbps" "Standard" $oldvpn5txmbratedisplay $MaxSpeedInet
    echo ""
    if [ ${oldvpn5rxmbrate%.*} -lt 0 ]; then oldvpn5rxmbrate=0; oldvpn5rxmbratedisplay=0; fi
    preparebar 79 "|"
    progressbar $oldvpn5rxmbrate $MaxSpeedInetUL " Avg VPN TX" "Mbps" "Standard" $oldvpn5rxmbratedisplay $MaxSpeedInetUL
  fi

  if [ "$wg1on" == "True" ]; then
    echo ""
    echo ""
    echo -e "${InvDkGray}${CWhite} WG$wg1slot                                                                                                           ${CClear}"
    echo ""
    if [ "$oldwg1city" == "Private Network" ]; then
      echo -en "${InvGreen} ${CClear}${CWhite} PRV WG IP  ${CDkGray}[ ${CWhite}"
      printf '%03d.%03d.%03d.%03d'  ${oldwg1ip//./ }
      echo -en "${CDkGray}                   ]  ${CWhite}CITY ${CDkGray}[ ${CWhite}"

      printf "%-33s" "$oldwg1city"

      echo -e "${CDkGray} ] ${InvDkGray}${CWhite}TUN: wgc$wg1slot${CClear}"
    else
      echo -en "${InvGreen} ${CClear}${CWhite} PUB WG IP  ${CDkGray}[ ${CWhite}"
      printf '%03d.%03d.%03d.%03d'  ${oldwg1ip//./ }
      echo -en "${CDkGray}                   ]  ${CWhite}CITY ${CDkGray}[ ${CWhite}"

      printf "%-33s" "$oldwg1city"

      echo -e "${CDkGray} ] ${InvDkGray}${CWhite}TUN: wgc$wg1slot${CClear}"
    fi
    if [ ${oldwg1txmbrate%.*} -lt 0 ]; then oldwg1txmbrate=0; oldwg1txmbratedisplay=0; fi
    preparebar 79 "|"
    progressbar $oldwg1txmbrate $MaxSpeedInet " Avg WG RX " "Mbps" "Standard" $oldwg1txmbratedisplay $MaxSpeedInet
    echo ""
    if [ ${oldwg1rxmbrate%.*} -lt 0 ]; then oldwg1rxmbrate=0; oldwg1rxmbratedisplay=0; fi
    preparebar 79 "|"
    progressbar $oldwg1rxmbrate $MaxSpeedInetUL " Avg WG TX " "Mbps" "Standard" $oldwg1rxmbratedisplay $MaxSpeedInetUL
  fi

  if [ "$wg2on" == "True" ]; then
    echo ""
    echo ""
    echo -e "${InvDkGray}${CWhite} WG$wg2slot                                                                                                           ${CClear}"
    echo ""
    if [ "$oldwg2city" == "Private Network" ]; then
      echo -en "${InvGreen} ${CClear}${CWhite} PRV WG IP  ${CDkGray}[ ${CWhite}"
      printf '%03d.%03d.%03d.%03d'  ${oldwg2ip//./ }
      echo -en "${CDkGray}                   ]  ${CWhite}CITY ${CDkGray}[ ${CWhite}"

      printf "%-33s" "$oldwg2city"

      echo -e "${CDkGray} ] ${InvDkGray}${CWhite}TUN: wgc$wg2slot${CClear}"
    else
      echo -en "${InvGreen} ${CClear}${CWhite} PUB WG IP  ${CDkGray}[ ${CWhite}"
      printf '%03d.%03d.%03d.%03d'  ${oldwg2ip//./ }
      echo -en "${CDkGray}                   ]  ${CWhite}CITY ${CDkGray}[ ${CWhite}"

      printf "%-33s" "$oldwg2city"

      echo -e "${CDkGray} ] ${InvDkGray}${CWhite}TUN: wgc$wg2slot${CClear}"
    fi
    if [ ${oldwg2txmbrate%.*} -lt 0 ]; then oldwg2txmbrate=0; oldwg2txmbratedisplay=0; fi
    preparebar 79 "|"
    progressbar $oldwg2txmbrate $MaxSpeedInet " Avg WG RX " "Mbps" "Standard" $oldwg2txmbratedisplay $MaxSpeedInet
    echo ""
    if [ ${oldwg2rxmbrate%.*} -lt 0 ]; then oldwg2rxmbrate=0; oldwg2rxmbratedisplay=0; fi
    preparebar 79 "|"
    progressbar $oldwg2rxmbrate $MaxSpeedInetUL " Avg WG TX " "Mbps" "Standard" $oldwg2rxmbratedisplay $MaxSpeedInetUL
  fi

  if [ "$wg3on" == "True" ]; then
    echo ""
    echo ""
    echo -e "${InvDkGray}${CWhite} WG$wg3slot                                                                                                           ${CClear}"
    echo ""
    if [ "$oldwg3city" == "Private Network" ]; then
      echo -en "${InvGreen} ${CClear}${CWhite} PRV WG IP  ${CDkGray}[ ${CWhite}"
      printf '%03d.%03d.%03d.%03d'  ${oldwg3ip//./ }
      echo -en "${CDkGray}                   ]  ${CWhite}CITY ${CDkGray}[ ${CWhite}"

      printf "%-33s" "$oldwg3city"

      echo -e "${CDkGray} ] ${InvDkGray}${CWhite}TUN: wgc$wg3slot${CClear}"
    else
      echo -en "${InvGreen} ${CClear}${CWhite} PUB WG IP  ${CDkGray}[ ${CWhite}"
      printf '%03d.%03d.%03d.%03d'  ${oldwg3ip//./ }
      echo -en "${CDkGray}                   ]  ${CWhite}CITY ${CDkGray}[ ${CWhite}"

      printf "%-33s" "$oldwg3city"

      echo -e "${CDkGray} ] ${InvDkGray}${CWhite}TUN: wgc$wg3slot${CClear}"
    fi
    if [ ${oldwg3txmbrate%.*} -lt 0 ]; then oldwg3txmbrate=0; oldwg3txmbratedisplay=0; fi
    preparebar 79 "|"
    progressbar $oldwg3txmbrate $MaxSpeedInet " Avg WG RX " "Mbps" "Standard" $oldwg3txmbratedisplay $MaxSpeedInet
    echo ""
    if [ ${oldwg3rxmbrate%.*} -lt 0 ]; then oldwg3rxmbrate=0; oldwg3rxmbratedisplay=0; fi
    preparebar 79 "|"
    progressbar $oldwg3rxmbrate $MaxSpeedInetUL " Avg WG TX " "Mbps" "Standard" $oldwg3rxmbratedisplay $MaxSpeedInetUL
  fi

  if [ "$wg4on" == "True" ]; then
    echo ""
    echo ""
    echo -e "${InvDkGray}${CWhite} WG$wg4slot                                                                                                           ${CClear}"
    echo ""
    if [ "$oldwg4city" == "Private Network" ]; then
      echo -en "${InvGreen} ${CClear}${CWhite} PRV WG IP  ${CDkGray}[ ${CWhite}"
      printf '%03d.%03d.%03d.%03d'  ${oldwg4ip//./ }
      echo -en "${CDkGray}                   ]  ${CWhite}CITY ${CDkGray}[ ${CWhite}"

      printf "%-33s" "$oldwg4city"

      echo -e "${CDkGray} ] ${InvDkGray}${CWhite}TUN: wgc$wg4slot${CClear}"
    else
      echo -en "${InvGreen} ${CClear}${CWhite} PUB WG IP  ${CDkGray}[ ${CWhite}"
      printf '%03d.%03d.%03d.%03d'  ${oldwg4ip//./ }
      echo -en "${CDkGray}                   ]  ${CWhite}CITY ${CDkGray}[ ${CWhite}"

      printf "%-33s" "$oldwg4city"

      echo -e "${CDkGray} ] ${InvDkGray}${CWhite}TUN: wgc$wg4slot${CClear}"
    fi
    if [ ${oldwg4txmbrate%.*} -lt 0 ]; then oldwg4txmbrate=0; oldwg4txmbratedisplay=0; fi
    preparebar 79 "|"
    progressbar $oldwg4txmbrate $MaxSpeedInet " Avg WG RX " "Mbps" "Standard" $oldwg4txmbratedisplay $MaxSpeedInet
    echo ""
    if [ ${oldwg4rxmbrate%.*} -lt 0 ]; then oldwg4rxmbrate=0; oldwg4rxmbratedisplay=0; fi
    preparebar 79 "|"
    progressbar $oldwg4rxmbrate $MaxSpeedInetUL " Avg WG TX " "Mbps" "Standard" $oldwg4rxmbratedisplay $MaxSpeedInetUL
  fi

  if [ "$wg5on" == "True" ]; then
    echo ""
    echo ""
    echo -e "${InvDkGray}${CWhite} WG$wg5slot                                                                                                          ${CClear}"
    echo ""
    if [ "$oldwg5city" == "Private Network" ]; then
      echo -en "${InvGreen} ${CClear}${CWhite} PRV WG IP  ${CDkGray}[ ${CWhite}"
      printf '%03d.%03d.%03d.%03d'  ${oldwg5ip//./ }
      echo -en "${CDkGray}                   ]  ${CWhite}CITY ${CDkGray}[ ${CWhite}"

      printf "%-33s" "$oldwg5city"

      echo -e "${CDkGray} ] ${InvDkGray}${CWhite}TUN: wgc$wg5slot${CClear}"
    else
      echo -en "${InvGreen} ${CClear}${CWhite} PUB WG IP  ${CDkGray}[ ${CWhite}"
      printf '%03d.%03d.%03d.%03d'  ${oldwg5ip//./ }
      echo -en "${CDkGray}                   ]  ${CWhite}CITY ${CDkGray}[ ${CWhite}"

      printf "%-33s" "$oldwg5city"

      echo -e "${CDkGray} ] ${InvDkGray}${CWhite}TUN: wgc$wg5slot${CClear}"
    fi
    if [ ${oldwg5txmbrate%.*} -lt 0 ]; then oldwg5txmbrate=0; oldwg5txmbratedisplay=0; fi
    preparebar 79 "|"
    progressbar $oldwg5txmbrate $MaxSpeedInet " Avg WG RX " "Mbps" "Standard" $oldwg5txmbratedisplay $MaxSpeedInet
    echo ""
    if [ ${oldwg5rxmbrate%.*} -lt 0 ]; then oldwg5rxmbrate=0; oldwg5rxmbratedisplay=0; fi
    preparebar 79 "|"
    progressbar $oldwg5rxmbrate $MaxSpeedInetUL " Avg WG TX " "Mbps" "Standard" $oldwg5rxmbratedisplay $MaxSpeedInetUL
  fi

}

# -------------------------------------------------------------------------------------------------------------------------

# This function displays the stats UI for page 3
DisplayPage3()
{
  clear
  if [ "$UpdateNotify" != "0" ]; then
    echo -e "$UpdateNotify${CClear}"
  fi
  showheader
  # Per @Stephen Harrington's sugguestion, check NVRAM to see if Wifi is turned on, else mark them as disabled
  if [ "$FourBandCustom55624" == "True" ]; then
    if [ $($timeoutcmd$timeoutsec nvram get wl0_radio) -eq 0 ]; then
      MaxSpeed5GhzNow=0
    else
      MaxSpeed5GhzNow=$MaxSpeed5Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl1_radio) -eq 0 ]; then
      MaxSpeed52GhzNow=0
    else
      MaxSpeed52GhzNow=$MaxSpeed5Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl2_radio) -eq 0 ]; then
      MaxSpeed6GhzNow=0
    else
      MaxSpeed6GhzNow=$MaxSpeed6Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl3_radio) -eq 0 ]; then
      MaxSpeed24GhzNow=0
    else
      MaxSpeed24GhzNow=$MaxSpeed24Ghz
    fi
  elif [ "$FourBandCustom56624" == "True" ]; then
    if [ $($timeoutcmd$timeoutsec nvram get wl0_radio) -eq 0 ]; then
      MaxSpeed5GhzNow=0
    else
      MaxSpeed5GhzNow=$MaxSpeed5Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl1_radio) -eq 0 ]; then
      MaxSpeed6GhzNow=0
    else
      MaxSpeed6GhzNow=$MaxSpeed6Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl2_radio) -eq 0 ]; then
      MaxSpeed62GhzNow=0
    else
      MaxSpeed62GhzNow=$MaxSpeed6Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl3_radio) -eq 0 ]; then
      MaxSpeed24GhzNow=0
    else
      MaxSpeed24GhzNow=$MaxSpeed24Ghz
    fi
  elif [ "$ThreeBand2456" == "True" ]; then
    if [ $($timeoutcmd$timeoutsec nvram get wl0_radio) -eq 0 ]; then
      MaxSpeed24GhzNow=0
    else
      MaxSpeed24GhzNow=$MaxSpeed24Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl1_radio) -eq 0 ]; then
      MaxSpeed5GhzNow=0
    else
      MaxSpeed5GhzNow=$MaxSpeed5Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl2_radio) -eq 0 ]; then
      MaxSpeed6GhzNow=0
    else
      MaxSpeed6GhzNow=$MaxSpeed6Ghz
    fi
  elif [ "$ThreeBand2455" == "True" ]; then
    if [ $($timeoutcmd$timeoutsec nvram get wl0_radio) -eq 0 ]; then
      MaxSpeed24GhzNow=0
    else
      MaxSpeed24GhzNow=$MaxSpeed24Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl1_radio) -eq 0 ]; then
      MaxSpeed5GhzNow=0
    else
      MaxSpeed5GhzNow=$MaxSpeed5Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl2_radio) -eq 0 ]; then
      MaxSpeed52GhzNow=0
    else
      MaxSpeed52GhzNow=$MaxSpeed5Ghz
    fi
  else
    if [ $($timeoutcmd$timeoutsec nvram get wl0_radio) -eq 0 ]; then
      MaxSpeed24GhzNow=0
    else
      MaxSpeed24GhzNow=$MaxSpeed24Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl1_radio) -eq 0 ]; then
      MaxSpeed5GhzNow=0
    else
      MaxSpeed5GhzNow=$MaxSpeed5Ghz
    fi
  fi

  echo ""
  echo -e "${InvDkGray}${CWhite} WiFi                                                                                                          ${CClear}"
  echo ""
  if [ "$MaxSpeed24GhzNow" != "0" ]; then
    if [ "$w24updown" == "UP" ]; then
      echo -e "${InvGreen} ${CClear} ${CWhite}2.4GHz     ${CDkGray}[ ${CWhite}Enabled - $w24udsched - UP                                                   ${CDkGray}] ${InvDkGray}${CWhite}IFace: $ifname24${CClear}"
    else
      echo -e "${InvGreen} ${CClear} ${CWhite}2.4GHz     ${CDkGray}[ ${CWhite}Enabled - $w24udsched - DOWN                                                 ${CDkGray}] ${InvDkGray}${CWhite}IFace: $ifname24${CClear}"
    fi
    preparebar 79 "|"
    progressbar $oldw24rxmbrate $MaxSpeed24GhzNow " Avg 24G RX" "Mbps" "Standard" $oldw24rxmbratedisplay $MaxSpeed24GhzNow
    echo ""
    preparebar 79 "|"
    progressbar $oldw24txmbrate $MaxSpeed24GhzNow " Avg 24G TX" "Mbps" "Standard" $oldw24txmbratedisplay $MaxSpeed24GhzNow
    echo ""
    preparebar 79 "|"
    converttemps $oldw24temp
    progressbar $currenttemp $currentrange " 2.4G Temp " $TempUnits "Standard" $currenttemp $currentrange
  else
    echo -e "${InvRed} ${CClear}${CWhite} 2.4GHz     ${CDkGray}[ ${CRed}Disabled                                                                      ${CDkGray}]${CClear}"
  fi
  if [ "$MaxSpeed5GhzNow" != "0" ]; then
    echo ""
    echo ""
    if [ "$w5updown" == "UP" ]; then
      echo -e "${InvGreen} ${CClear} ${CWhite}5.0GHz     ${CDkGray}[ ${CWhite}Enabled - $w5udsched - UP                                                   ${CDkGray}] ${InvDkGray}${CWhite}IFace: $ifname5${CClear}"
    else
      echo -e "${InvGreen} ${CClear} ${CWhite}5.0GHz     ${CDkGray}[ ${CWhite}Enabled - $w5udsched - DOWN                                                 ${CDkGray}] ${InvDkGray}${CWhite}IFace: $ifname5${CClear}"
    fi
    preparebar 79 "|"
    progressbar $oldw5rxmbrate $MaxSpeed5GhzNow " Avg 5G1 RX" "Mbps" "Standard" $oldw5rxmbratedisplay $MaxSpeed5GhzNow
    echo ""
    preparebar 79 "|"
    progressbar $oldw5txmbrate $MaxSpeed5GhzNow " Avg 5G1 TX" "Mbps" "Standard" $oldw5txmbratedisplay $MaxSpeed5GhzNow
    echo ""
    preparebar 79 "|"
    converttemps $oldw5temp
    progressbar $currenttemp $currentrange " 5G-1 Temp " $TempUnits "Standard" $currenttemp $currentrange
  else
    echo ""
    echo ""
    echo -e "${InvRed} ${CClear}${CWhite} 5.0GHz     ${CDkGray}[ ${CRed}Disabled                                                                      ${CDkGray}]${CClear}"
  fi
  if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2455" == "True" ]; then
    if [ "$MaxSpeed52GhzNow" != "0" ]; then
      echo ""
      echo ""
      if [ "$w52updown" == "UP" ]; then
        echo -e "${InvGreen} ${CClear} ${CWhite}5.0GHz (2) ${CDkGray}[ ${CWhite}Enabled - $w52udsched - UP                                                   ${CDkGray}] ${InvDkGray}${CWhite}IFace: $ifname52${CClear}"
      else
        echo -e "${InvGreen} ${CClear} ${CWhite}5.0GHz (2) ${CDkGray}[ ${CWhite}Enabled - $w52udsched - DOWN                                                 ${CDkGray}] ${InvDkGray}${CWhite}IFace: $ifname52${CClear}"
      fi
      preparebar 79 "|"
      progressbar $oldw52rxmbrate $MaxSpeed5GhzNow " Avg 5G2 RX" "Mbps" "Standard" $oldw52rxmbratedisplay $MaxSpeed5GhzNow
      echo ""
      preparebar 79 "|"
      progressbar $oldw52txmbrate $MaxSpeed5GhzNow " Avg 5G2 TX" "Mbps" "Standard" $oldw52txmbratedisplay $MaxSpeed5GhzNow
      echo ""
      preparebar 79 "|"
      converttemps $oldw52temp
      progressbar $currenttemp $currentrange " 5G-2 Temp " $TempUnits "Standard" $currenttemp $currentrange
    else
      echo ""
      echo ""
      echo -e "${InvRed} ${CClear}${CWhite} 5.0GHz (2) ${CDkGray}[ ${CRed}Disabled                                                                    ${CDkGray}]${CClear}"
    fi
  fi
  if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2456" == "True" ] || [ "$FourBandCustom56624" == "True" ]; then
    if [ "$MaxSpeed6GhzNow" != "0" ]; then
      echo ""
      echo ""
      if [ "$w6updown" == "UP" ]; then
        echo -e "${InvGreen} ${CClear} ${CWhite}6.0GHz     ${CDkGray}[ ${CWhite}Enabled - $w6udsched - UP                                                   ${CDkGray}] ${InvDkGray}${CWhite}IFace: $ifname6${CClear}"
      else
        echo -e "${InvGreen} ${CClear} ${CWhite}6.0GHz     ${CDkGray}[ ${CWhite}Enabled - $w6udsched - DOWN                                                 ${CDkGray}] ${InvDkGray}${CWhite}IFace: $ifname6${CClear}"
      fi
      preparebar 79 "|"
      progressbar $oldw6rxmbrate $MaxSpeed6GhzNow " Avg 60G RX" "Mbps" "Standard" $oldw6rxmbratedisplay $MaxSpeed6GhzNow
      echo ""
      preparebar 79 "|"
      progressbar $oldw6txmbrate $MaxSpeed6GhzNow " Avg 60G TX" "Mbps" "Standard" $oldw6txmbratedisplay $MaxSpeed6GhzNow
      echo ""
      preparebar 79 "|"
      converttemps $oldw6temp
      progressbar $currenttemp $currentrange " 6.0G Temp " $TempUnits "Standard" $currenttemp $currentrange
    else
      echo ""
      echo ""
      echo -e "${InvRed} ${CClear}${CWhite} 6.0GHz     ${CDkGray}[ ${CRed}Disabled                                                                    ${CDkGray}]${CClear}"
    fi
  fi
  if [ "$FourBandCustom56624" == "True" ]; then
    if [ "$MaxSpeed62GhzNow" != "0" ]; then
      echo ""
      echo ""
      if [ "$w62updown" == "UP" ]; then
        echo -e "${InvGreen} ${CClear} ${CWhite}6.0GHz (2) ${CDkGray}[ ${CWhite}Enabled - $w62udsched - UP                                                   ${CDkGray}] ${InvDkGray}${CWhite}IFace: $ifname62${CClear}"
      else
        echo -e "${InvGreen} ${CClear} ${CWhite}6.0GHz (2) ${CDkGray}[ ${CWhite}Enabled - $w62udsched - DOWN                                                 ${CDkGray}] ${InvDkGray}${CWhite}IFace: $ifname62${CClear}"
      fi
      preparebar 79 "|"
      progressbar $oldw62rxmbrate $MaxSpeed62GhzNow " Avg 6G2 RX" "Mbps" "Standard" $oldw62rxmbratedisplay $MaxSpeed62GhzNow
      echo ""
      preparebar 79 "|"
      progressbar $oldw62txmbrate $MaxSpeed62GhzNow " Avg 6G2 TX" "Mbps" "Standard" $oldw62txmbratedisplay $MaxSpeed62GhzNow
      echo ""
      preparebar 79 "|"
      converttemps $oldw62temp
      progressbar $currenttemp $currentrange " 6G-2 Temp " $TempUnits "Standard" $currenttemp $currentrange
    else
      echo ""
      echo ""
      echo -e "${InvRed} ${CClear}${CWhite} 6.0GHz (2) ${CDkGray}[ ${CRed}Disabled                                                                    ${CDkGray}]${CClear}"
    fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# This function displays the stats UI for page 4
DisplayPage4()
{
  clear
  if [ "$UpdateNotify" != "0" ]; then
    echo -e "$UpdateNotify${CClear}"
  fi
  showheader
  echo ""
  echo -e "${InvDkGray}${CWhite} Speedtest                                                                                                     ${CClear}"

  if [ "$QueueVPNSlot1" = "1" ]; then
    DisplaySpdtst 1
  elif [ "$QueueVPNSlot2" = "1" ]; then
    DisplaySpdtst 2
  elif [ "$QueueVPNSlot3" = "1" ]; then
    DisplaySpdtst 3
  elif [ "$QueueVPNSlot4" = "1" ]; then
    DisplaySpdtst 4
  elif [ "$QueueVPNSlot5" = "1" ]; then
    DisplaySpdtst 5
  elif [ "$QueueWGSlot1" = "1" ]; then
    DisplaySpdtst 6
  elif [ "$QueueWGSlot2" = "1" ]; then
    DisplaySpdtst 7
  elif [ "$QueueWGSlot3" = "1" ]; then
    DisplaySpdtst 8
  elif [ "$QueueWGSlot4" = "1" ]; then
    DisplaySpdtst 9
  elif [ "$QueueWGSlot5" = "1" ]; then
    DisplaySpdtst 0
  else
    DisplaySpdtst
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# This function displays speedtest results and runs new speedtest
# $1 = VPN Slot

DisplaySpdtst()
{
  if [ "$Speedtst" = "0" ] || [ ! -f $OOKLAPATH ]; then
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvRed} ${CClear} ${CRed}[Ookla Speedtest is not installed/configured]${CClear}"
    sleep 3
    return
  fi

  # Check to see if previous results are available to display
  if [ -f "$SPDRESPATH" ]; then
    source "$SPDRESPATH"
  else
    SpdDate="No previous results found"
    SpdServer="Press 'I' to Initiate a Speedtest"
    SpdLatency=0
    SpdJitter=0
    SpdPacketLoss=0
    SpdDownload=0
    SpdUpload=0
  fi

  echo -e "${InvGreen} ${CClear}"

  if [ "$QueueSpdTest" = "1" ]
  then
    #run speedtest and save Results
    printf "\r${InvGreen} ${CClear} ${CGreen}[Initializing WAN Speedtest]"
    #printf "${CGreen}\r[Initializing WAN Speedtest]"
    if [ $spdtestsvrID == "0" ]; then
      speed="$(/jffs/addons/rtrmon.d/speedtest --format=csv --interface=$WANIFNAME --accept-license --accept-gdpr 2>&1)"
    else
      speed="$(/jffs/addons/rtrmon.d/speedtest --format=csv --interface=$WANIFNAME --server-id=$spdtestsvrID --accept-license --accept-gdpr 2>&1)"
    fi
    SpdDate=$(date)
    SpdServer=$(echo $speed | awk -F '","' 'NR==1 {print $1}' | sed -e 's/^"//' -e 's/"$//' -e 's/[^a-zA-Z0-9 -]//g')
    SpdLatency=$(echo $speed | awk -F '","' 'NR==1 {print $3}' | sed -e 's/^"//' -e 's/"$//')
    SpdLatencyLo=$(echo $speed | awk -F '","' 'NR==1 {print $20}' | sed -e 's/^"//' -e 's/"$//')
    SpdLatencyHi=$(echo $speed | awk -F '","' 'NR==1 {print $21}' | sed -e 's/^"//' -e 's/"$//')
    SpdJitter=$(echo $speed | awk -F '","' 'NR==1 {print $4}' | sed -e 's/^"//' -e 's/"$//')
    SpdPacketLoss=$(echo $speed | awk -F '","' 'NR==1 {print $5}' | sed -e 's/^"//' -e 's/"$//')
    SpdDownload=$(echo $speed | awk -F '","' 'NR==1 {print $6}' | sed -e 's/^"//' -e 's/"$//')
    SpdUpload=$(echo $speed | awk -F '","' 'NR==1 {print $7}' | sed -e 's/^"//' -e 's/"$//')
    SpdDLLatency=$(echo $speed | awk -F '","' 'NR==1 {print $12}' | sed -e 's/^"//' -e 's/"$//')
    SpdDLLatencyJt=$(echo $speed | awk -F '","' 'NR==1 {print $13}' | sed -e 's/^"//' -e 's/"$//')
    SpdDLLatencyLo=$(echo $speed | awk -F '","' 'NR==1 {print $14}' | sed -e 's/^"//' -e 's/"$//')
    SpdDLLatencyHi=$(echo $speed | awk -F '","' 'NR==1 {print $15}' | sed -e 's/^"//' -e 's/"$//')
    SpdULLatency=$(echo $speed | awk -F '","' 'NR==1 {print $16}' | sed -e 's/^"//' -e 's/"$//')
    SpdULLatencyJt=$(echo $speed | awk -F '","' 'NR==1 {print $17}' | sed -e 's/^"//' -e 's/"$//')
    SpdULLatencyLo=$(echo $speed | awk -F '","' 'NR==1 {print $18}' | sed -e 's/^"//' -e 's/"$//')
    SpdULLatencyHi=$(echo $speed | awk -F '","' 'NR==1 {print $19}' | sed -e 's/^"//' -e 's/"$//')

    if [ $SpdDownload -eq 0 ]; then SpdDownload=1; fi
    if [ $SpdUpload -eq 0 ]; then SpdUpload=1; fi

    SpdDownloadLog=$(awk -v down=$SpdDownload -v mb=125000 'BEGIN{printf "%.0f\n", down/mb}')
    SpdUploadLog=$(awk -v up=$SpdUpload -v mb=125000 'BEGIN{printf "%.0f\n", up/mb}')
    SpdInterface=$WANIFNAME

    echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - New Speedtest Results -- Down:$SpdDownloadLog Mbps | Up:$SpdUploadLog Mbps | Latency:$SpdLatency ms | Jitter:$SpdJitter ms | PacketLoss:$SpdPacketLoss %" >> $LOGFILE

    { echo 'SpdDate="'"$SpdDate"'"'
      echo 'SpdServer="'"$SpdServer"'"'
      echo 'SpdInterface="'"$SpdInterface"'"'
      echo 'SpdLatency='$SpdLatency
      echo 'SpdLatencyLo='$SpdLatencyLo
      echo 'SpdLatencyHi='$SpdLatencyHi
      echo 'SpdJitter='$SpdJitter
      echo 'SpdPacketLoss='$SpdPacketLoss
      echo 'SpdDownload='$SpdDownload
      echo 'SpdUpload='$SpdUpload
      echo 'SpdDLLatency='$SpdDLLatency
      echo 'SpdDLLatencyJt='$SpdDLLatencyJt
      echo 'SpdDLLatencyLo='$SpdDLLatencyLo
      echo 'SpdDLLatencyHi='$SpdDLLatencyHi
      echo 'SpdULLatency='$SpdULLatency
      echo 'SpdULLatencyJt='$SpdULLatencyJt
      echo 'SpdULLatencyLo='$SpdULLatencyLo
      echo 'SpdULLatencyHi='$SpdULLatencyHi
    } > "$SPDRESPATH"
    printf "${CGreen}\r"
    QueueSpdTest=0
  fi

  if [ "$1" = "1" ] || [ "$1" = "2" ] || [ "$1" = "3" ] || [ "$1" = "4" ] || [ "$1" = "5" ]
  then
    #run VPN speedtest and save Results
    selectedvpnslot="vpn${1}on"
    eval selectedvpnslot="\$${selectedvpnslot}"
    if [ "$selectedvpnslot" = "True" ] && [ "$VPNSite2Site" = "0" ]
    then
      printf "\r${InvGreen} ${CClear} ${CGreen}[Initializing VPN$1 Speedtest]"
      if [ $spdtestsvrID == "0" ]; then
        speed="$(/jffs/addons/rtrmon.d/speedtest --format=csv --interface=tun1$1 --accept-license --accept-gdpr 2>&1)"
      else
        speed="$(/jffs/addons/rtrmon.d/speedtest --format=csv --interface=tun1$1 --server-id=$spdtestsvrID --accept-license --accept-gdpr 2>&1)"
      fi
      SpdDate=$(date)
      SpdServer=$(echo $speed | awk -F '","' 'NR==1 {print $1}' | sed -e 's/^"//' -e 's/"$//' -e 's/[^a-zA-Z0-9 -]//g')
      SpdLatency=$(echo $speed | awk -F '","' 'NR==1 {print $3}' | sed -e 's/^"//' -e 's/"$//')
      SpdLatencyLo=$(echo $speed | awk -F '","' 'NR==1 {print $20}' | sed -e 's/^"//' -e 's/"$//')
      SpdLatencyHi=$(echo $speed | awk -F '","' 'NR==1 {print $21}' | sed -e 's/^"//' -e 's/"$//')
      SpdJitter=$(echo $speed | awk -F '","' 'NR==1 {print $4}' | sed -e 's/^"//' -e 's/"$//')
      SpdPacketLoss=$(echo $speed | awk -F '","' 'NR==1 {print $5}' | sed -e 's/^"//' -e 's/"$//')
      SpdDownload=$(echo $speed | awk -F '","' 'NR==1 {print $6}' | sed -e 's/^"//' -e 's/"$//')
      SpdUpload=$(echo $speed | awk -F '","' 'NR==1 {print $7}' | sed -e 's/^"//' -e 's/"$//')
      SpdDLLatency=$(echo $speed | awk -F '","' 'NR==1 {print $12}' | sed -e 's/^"//' -e 's/"$//')
      SpdDLLatencyJt=$(echo $speed | awk -F '","' 'NR==1 {print $13}' | sed -e 's/^"//' -e 's/"$//')
      SpdDLLatencyLo=$(echo $speed | awk -F '","' 'NR==1 {print $14}' | sed -e 's/^"//' -e 's/"$//')
      SpdDLLatencyHi=$(echo $speed | awk -F '","' 'NR==1 {print $15}' | sed -e 's/^"//' -e 's/"$//')
      SpdULLatency=$(echo $speed | awk -F '","' 'NR==1 {print $16}' | sed -e 's/^"//' -e 's/"$//')
      SpdULLatencyJt=$(echo $speed | awk -F '","' 'NR==1 {print $17}' | sed -e 's/^"//' -e 's/"$//')
      SpdULLatencyLo=$(echo $speed | awk -F '","' 'NR==1 {print $18}' | sed -e 's/^"//' -e 's/"$//')
      SpdULLatencyHi=$(echo $speed | awk -F '","' 'NR==1 {print $19}' | sed -e 's/^"//' -e 's/"$//')

      if [ $SpdDownload -eq 0 ]; then SpdDownload=1; fi
      if [ $SpdUpload -eq 0 ]; then SpdUpload=1; fi

      SpdDownloadLog=$(awk -v down=$SpdDownload -v mb=125000 'BEGIN{printf "%.0f\n", down/mb}')
      SpdUploadLog=$(awk -v up=$SpdUpload -v mb=125000 'BEGIN{printf "%.0f\n", up/mb}')
      SpdInterface="tun1$1"

      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - New VPN$1 Speedtest Results -- Down:$SpdDownloadLog Mbps | Up:$SpdUploadLog Mbps | Latency:$SpdLatency ms | Jitter:$SpdJitter ms | PacketLoss:$SpdPacketLoss %" >> $LOGFILE

      { echo 'SpdDate="'"$SpdDate"'"'
        echo 'SpdServer="'"$SpdServer"'"'
        echo 'SpdInterface="'"$SpdInterface"'"'
        echo 'SpdLatency='$SpdLatency
        echo 'SpdLatencyLo='$SpdLatencyLo
        echo 'SpdLatencyHi='$SpdLatencyHi
        echo 'SpdJitter='$SpdJitter
        echo 'SpdPacketLoss='$SpdPacketLoss
        echo 'SpdDownload='$SpdDownload
        echo 'SpdUpload='$SpdUpload
        echo 'SpdDLLatency='$SpdDLLatency
        echo 'SpdDLLatencyJt='$SpdDLLatencyJt
        echo 'SpdDLLatencyLo='$SpdDLLatencyLo
        echo 'SpdDLLatencyHi='$SpdDLLatencyHi
        echo 'SpdULLatency='$SpdULLatency
        echo 'SpdULLatencyJt='$SpdULLatencyJt
        echo 'SpdULLatencyLo='$SpdULLatencyLo
        echo 'SpdULLatencyHi='$SpdULLatencyHi
      } > $SPDRESPATH
      printf "\r${CClear}"
      QueueVPNSlot1=0
      QueueVPNSlot2=0
      QueueVPNSlot3=0
      QueueVPNSlot4=0
      QueueVPNSlot5=0
    else
      printf "\r${InvRed} ${CClear}${CRed} [No valid VPN tunnel detected to run Speedtest on]${CClear}"
      sleep 3
      printf "\r${CClear}                                                                             "
      QueueVPNSlot1=0
      QueueVPNSlot2=0
      QueueVPNSlot3=0
      QueueVPNSlot4=0
      QueueVPNSlot5=0
    fi
  fi

  if [ "$1" = "0" ] || [ "$1" = "6" ] || [ "$1" = "7" ] || [ "$1" = "8" ] || [ "$1" = "9" ]
  then
    if [ $1 -eq 6 ]; then selectedslotnum=1
    elif [ $1 -eq 7 ]; then selectedslotnum=2
    elif [ $1 -eq 8 ]; then selectedslotnum=3
    elif [ $1 -eq 9 ]; then selectedslotnum=4
    elif [ $1 -eq 0 ]; then selectedslotnum=5
    fi
    #run WG speedtest and save Results
    selectedwgslot="wg${selectedslotnum}on"
    eval selectedwgslot="\$${selectedwgslot}"
    if [ "$selectedwgslot" = "True" ] && [ "$VPNSite2Site" = "0" ]
    then

      SPDWGTUN="wgc$selectedslotnum"
      SPDNVRAMWGSLOTADDR=$($timeoutcmd$timeoutsec nvram get "$SPDWGTUN"_addr | cut -d '/' -f1)

      # Added based on suggestion from @ZebMcKayhan
      ip rule add from $SPDNVRAMWGSLOTADDR lookup $SPDWGTUN prio 10 >/dev/null 2>&1

      printf "\r${InvGreen} ${CClear} ${CGreen}[Initializing WG${selectedslotnum} Speedtest]"
      if [ $spdtestsvrID == "0" ]; then
        speed="$(/jffs/addons/rtrmon.d/speedtest --format=csv --interface=wgc${selectedslotnum} --accept-license --accept-gdpr 2>&1)"
      else
      speed="$(/jffs/addons/rtrmon.d/speedtest --format=csv --interface=wgc${selectedslotnum} --server-id=$spdtestsvrID --accept-license --accept-gdpr 2>&1)"
      fi

      # Added based on suggestion from @ZebMcKayhan
      ip rule del prio 10 >/dev/null 2>&1

      SpdDate=$(date)
      SpdServer=$(echo $speed | awk -F '","' 'NR==1 {print $1}' | sed -e 's/^"//' -e 's/"$//' -e 's/[^a-zA-Z0-9 -]//g')
      SpdLatency=$(echo $speed | awk -F '","' 'NR==1 {print $3}' | sed -e 's/^"//' -e 's/"$//')
      SpdLatencyLo=$(echo $speed | awk -F '","' 'NR==1 {print $20}' | sed -e 's/^"//' -e 's/"$//')
      SpdLatencyHi=$(echo $speed | awk -F '","' 'NR==1 {print $21}' | sed -e 's/^"//' -e 's/"$//')
      SpdJitter=$(echo $speed | awk -F '","' 'NR==1 {print $4}' | sed -e 's/^"//' -e 's/"$//')
      SpdPacketLoss=$(echo $speed | awk -F '","' 'NR==1 {print $5}' | sed -e 's/^"//' -e 's/"$//')
      SpdDownload=$(echo $speed | awk -F '","' 'NR==1 {print $6}' | sed -e 's/^"//' -e 's/"$//')
      SpdUpload=$(echo $speed | awk -F '","' 'NR==1 {print $7}' | sed -e 's/^"//' -e 's/"$//')
      SpdDLLatency=$(echo $speed | awk -F '","' 'NR==1 {print $12}' | sed -e 's/^"//' -e 's/"$//')
      SpdDLLatencyJt=$(echo $speed | awk -F '","' 'NR==1 {print $13}' | sed -e 's/^"//' -e 's/"$//')
      SpdDLLatencyLo=$(echo $speed | awk -F '","' 'NR==1 {print $14}' | sed -e 's/^"//' -e 's/"$//')
      SpdDLLatencyHi=$(echo $speed | awk -F '","' 'NR==1 {print $15}' | sed -e 's/^"//' -e 's/"$//')
      SpdULLatency=$(echo $speed | awk -F '","' 'NR==1 {print $16}' | sed -e 's/^"//' -e 's/"$//')
      SpdULLatencyJt=$(echo $speed | awk -F '","' 'NR==1 {print $17}' | sed -e 's/^"//' -e 's/"$//')
      SpdULLatencyLo=$(echo $speed | awk -F '","' 'NR==1 {print $18}' | sed -e 's/^"//' -e 's/"$//')
      SpdULLatencyHi=$(echo $speed | awk -F '","' 'NR==1 {print $19}' | sed -e 's/^"//' -e 's/"$//')

      if [ $SpdDownload -eq 0 ]; then SpdDownload=1; fi
      if [ $SpdUpload -eq 0 ]; then SpdUpload=1; fi

      SpdDownloadLog=$(awk -v down=$SpdDownload -v mb=125000 'BEGIN{printf "%.0f\n", down/mb}')
      SpdUploadLog=$(awk -v up=$SpdUpload -v mb=125000 'BEGIN{printf "%.0f\n", up/mb}')
      SpdInterface="wgc${selectedslotnum}"

      echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - New WG${selectedslotnum} Speedtest Results -- Down:$SpdDownloadLog Mbps | Up:$SpdUploadLog Mbps | Latency:$SpdLatency ms | Jitter:$SpdJitter ms | PacketLoss:$SpdPacketLoss %" >> $LOGFILE

      { echo 'SpdDate="'"$SpdDate"'"'
        echo 'SpdServer="'"$SpdServer"'"'
        echo 'SpdInterface="'"$SpdInterface"'"'
        echo 'SpdLatency='$SpdLatency
        echo 'SpdLatencyLo='$SpdLatencyLo
        echo 'SpdLatencyHi='$SpdLatencyHi
        echo 'SpdJitter='$SpdJitter
        echo 'SpdPacketLoss='$SpdPacketLoss
        echo 'SpdDownload='$SpdDownload
        echo 'SpdUpload='$SpdUpload
        echo 'SpdDLLatency='$SpdDLLatency
        echo 'SpdDLLatencyJt='$SpdDLLatencyJt
        echo 'SpdDLLatencyLo='$SpdDLLatencyLo
        echo 'SpdDLLatencyHi='$SpdDLLatencyHi
        echo 'SpdULLatency='$SpdULLatency
        echo 'SpdULLatencyJt='$SpdULLatencyJt
        echo 'SpdULLatencyLo='$SpdULLatencyLo
        echo 'SpdULLatencyHi='$SpdULLatencyHi
      } > $SPDRESPATH
      printf "\r${CClear}"
      QueueWGSlot1=0
      QueueWGSlot2=0
      QueueWGSlot3=0
      QueueWGSlot4=0
      QueueWGSlot5=0
    else
      printf "\r${InvRed} ${CClear}${CRed} [No valid WG tunnel detected to run Speedtest on]${CClear}"
      sleep 3
      printf "\r${CClear}                                                                             "
      QueueWGSlot1=0
      QueueWGSlot2=0
      QueueWGSlot3=0
      QueueWGSlot4=0
      QueueWGSlot5=0
    fi
  fi

  # Display previous results
  if [ $SpdDownload -eq 0 ] || [ -z $SpdDownload ]; then SpdDownload=1; fi
  if [ $SpdUpload -eq 0 ] || [ -z $SpdUpload ]; then SpdUpload=1; fi

  SpdDownload=$(awk -v down=$SpdDownload -v mb=125000 'BEGIN{printf "%.0f\n", down/mb}')
  SpdUpload=$(awk -v up=$SpdUpload -v mb=125000 'BEGIN{printf "%.0f\n", up/mb}')

  if [ "$ScreenshotMode" == "1" ]; then
    SpdServer="Starlink Satellite Transceiver #488028"
  fi

  if [ "$vpn1on" == "True" ] || [ "$vpn2on" == "True" ] || [ "$vpn3on" == "True" ] || [ "$vpn4on" == "True" ] || [ "$vpn5on" == "True" ] || [ "$wg1on" == "True" ] || [ "$wg2on" == "True" ] || [ "$wg3on" == "True" ] || [ "$wg4on" == "True" ]|| [ "$wg5on" == "True" ]; then
    printf "\r${InvGreen} ${CClear} ${CGreen}(I)${CWhite}nitiate WAN Speedtest on: ${CGreen}$WANIFNAME  ${CWhite}|  VPN 1:${CGreen}(1) ${CWhite}2:${CGreen}(2) ${CWhite}3:${CGreen}(3) ${CWhite}4:${CGreen}(4) ${CWhite}5:${CGreen}(5) ${CWhite} |  WG 1:${CGreen}(6) ${CWhite}2:${CGreen}(7) ${CWhite}3:${CGreen}(8) ${CWhite}4:${CGreen}(9) ${CWhite}5:${CGreen}(0)${CClear}"
  else
    printf "\r${InvGreen} ${CClear} ${CGreen}(I)${CWhite}nitiate WAN Speedtest${CClear}                                            "
  fi
  echo ""
  echo -e "${InvGreen} ${CClear}${CDkGray}--------------------------------------------------------------------------------------------------------------${CClear}"
  echo ""
  echo -e "${InvGreen} ${CClear} ${CWhite}Test Date    ${CDkGray}[ ${CGreen}$SpdDate${CClear}"
  echo -e "${InvGreen} ${CClear} ${CWhite}Server       ${CDkGray}[ ${CGreen}$SpdServer${CClear}"
  echo -e "${InvGreen} ${CClear} ${CWhite}Interface    ${CDkGray}[ ${CGreen}$SpdInterface${CClear}"
  echo ""
  echo -e "${InvGreen} ${CClear} ${CWhite}Idle Latency ${CDkGray}[ ${CGreen}$SpdLatency (ms)${CWhite} | Latency Low: ${CGreen}$SpdLatencyLo (ms) ${CWhite}| High: ${CGreen}$SpdLatencyHi (ms)${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${CWhite}Idle Jitter  ${CDkGray}[ ${CGreen}$SpdJitter (ms)${CClear}"
  echo -e "${InvGreen} ${CClear} ${CWhite}PacketLoss   ${CDkGray}[ ${CGreen}$SpdPacketLoss (%)${CClear}"
  echo ""
  echo -e "${InvGreen} ${CClear} ${CWhite}Download     ${CDkGray}[ ${CGreen}$SpdDownload (Mbps)${CWhite} | Jitter: ${CGreen}$SpdDLLatencyJt (ms)${CClear}"
  echo -e "${InvGreen} ${CClear} ${CDkGray}             [ ${CWhite}Latency: ${CGreen}$SpdDLLatency (ms)${CWhite} | Latency Low: ${CGreen}$SpdDLLatencyLo (ms) ${CWhite}| High: ${CGreen}$SpdDLLatencyHi (ms)${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${CCyan}Upload       ${CDkGray}[ ${CGreen}$SpdUpload (Mbps)${CWhite} | Jitter: ${CGreen}$SpdULLatencyJt (ms)${CClear}"
  echo -e "${InvGreen} ${CClear} ${CDkGray}             [ ${CWhite}Latency: ${CGreen}$SpdULLatency (ms)${CWhite} | Latency Low: ${CGreen}$SpdULLatencyLo (ms) ${CWhite}| High: ${CGreen}$SpdULLatencyHi (ms)${CClear}"
  echo ""
  preparebar 79 "|"
  progressbar $SpdDownload $MaxSpeedInet " DL vs WAN " "Mbps" "Reverse" $SpdDownload $MaxSpeedInet
  echo ""
  preparebar 79 "|"
  progressbar $SpdUpload $MaxSpeedInetUL " UL vs WAN " "Mbps" "Reverse" $SpdUpload $MaxSpeedInetUL
}

# -------------------------------------------------------------------------------------------------------------------------

# This function displays the stats UI for page 5 which includes network diagnostics and open port scanning
DisplayPage5()
{
  local ALIVE
  local YEAR
  local NW_STATE
  local RES_STATE
  local HOST_STATE
  local CURL_STATE
  local SPIDER_STATE
  local SSL_STATE
  #oldwan0ip="123.45.67.89"

  # Check to see if previous results are available to display
  if [ -f "$DIAGRESPATH" ]; then
    source "$DIAGRESPATH"
  else
    Lastruntime="No previous results found"
    LocalClockTest="Failed"
    NetworkConnTest="Failed"
    NetworkResTest="Failed"
    DigFuncTest="Failed"
    CurlFuncTest="Failed"
    SpiderFuncTest="Failed"
    SSLHandshakeTest="Failed"
  fi

  clear
  if [ "$UpdateNotify" != "0" ]; then
    echo -e "$UpdateNotify${CClear}"
  fi
  showheader
  echo ""
  echo -e "${InvGreen} ${CClear}${InvDkGray}${CWhite} Network Diagnostics                                                                                          ${CClear}"
  echo -e "${InvGreen} ${CClear}"
  echo -e "${InvGreen} ${CClear} ${CWhite}Run ${CGreen}(D)${CWhite}iagnostics  |  Last Run Date/Time: ${CGreen}$Lastruntime"
  echo -e "${InvGreen} ${CClear}${CDkGray}--------------------------------------------------------------------------------------------------------------${CClear}"
  echo ""

  if [ "$QueueNetworkDiag" = "1" ]
  then
     #run network diags and save Results
     printf "${InvYellow} ${CClear} ${CWhite}Local Clock Test...          ${CYellow}[Checking] ${CDkGray}| date > 1970${CClear}"
      YEAR="$(/bin/date +"%Y")"
      sleep 1
      if [ "$YEAR" -gt 1970 ]; then
        printf "\r${InvGreen} ${CClear} ${CWhite}Local Clock Test...          ${CGreen}[Passed]   ${CDkGray}| date > 1970${CClear}"
        LocalClockTest="Passed"
      else
        printf "\r${InvRed} ${CClear} ${CWhite}Local Clock Test...          ${CRed}[Failed]   ${CDkGray}| date > 1970${CClear}"
        LocalClockTest="Failed"
      fi
    echo ""
    printf "${InvYellow} ${CClear} ${CWhite}Network Connectivity Test... ${CYellow}[Checking] ${CDkGray}| ping 1.1.1.1 -c1 -W2${CClear}"
      NW_STATE="$(ping 1.1.1.1 -c1 -W2 >/dev/null 2>&1; echo $?)"
      sleep 1
      if [ "$NW_STATE" = "0" ]; then
        printf "\r${InvGreen} ${CClear} ${CWhite}Network Connectivity Test... ${CGreen}[Passed]   ${CDkGray}| ping 1.1.1.1 -c1 -W2${CClear}"
        NetworkConnTest="Passed"
      else
        printf "\r${InvRed} ${CClear} ${CWhite}Network Connectivity Test... ${CRed}[Failed]   ${CDkGray}| ping 1.1.1.1 -c1 -W2${CClear}"
        NetworkConnTest="Failed"
      fi
    echo ""

    if [ "$WAN0AltModes" == "0" ] || [ "$OpsMode" == "1" ]; then
      printf "${InvYellow} ${CClear} ${CWhite}Network Resolution Test...   ${CYellow}[Checking] ${CDkGray}| nslookup google.com 127.0.0.1${CClear}"
        RES_STATE="$(nslookup google.com 127.0.0.1 >/dev/null 2>&1; echo $?)"
        sleep 1
        if [ "$RES_STATE" = "0" ]; then
          printf "\r${InvGreen} ${CClear} ${CWhite}Network Resolution Test...   ${CGreen}[Passed]   ${CDkGray}| nslookup google.com 127.0.0.1${CClear}"
          NetworkResTest="Passed"
        else
          printf "\r${InvRed} ${CClear} ${CWhite}Network Resolution Test...   ${CRed}[Failed]   ${CDkGray}| nslookup google.com 127.0.0.1${CClear}"
          NetworkResTest="Failed"
        fi
      echo ""
    else
      printf "${InvYellow} ${CClear} ${CWhite}Network Resolution Test...   ${CYellow}[Checking] ${CDkGray}| nslookup google.com${CClear}"
        RES_STATE="$(nslookup google.com >/dev/null 2>&1; echo $?)"
        sleep 1
        if [ "$RES_STATE" = "0" ]; then
          printf "\r${InvGreen} ${CClear} ${CWhite}Network Resolution Test...   ${CGreen}[Passed]   ${CDkGray}| nslookup google.com${CClear}"
          NetworkResTest="Passed"
        else
          printf "\r${InvRed} ${CClear} ${CWhite}Network Resolution Test...   ${CRed}[Failed]   ${CDkGray}| nslookup google.com${CClear}"
          NetworkResTest="Failed"
        fi
      echo ""
    fi

    printf "${InvYellow} ${CClear} ${CWhite}Dig Functionality Test...    ${CYellow}[Checking] ${CDkGray}| dig google.com${CClear}"
      DIG_STATE="$(dig google.com >/dev/null 2>&1; echo $?)"
      sleep 1
      if [ "$DIG_STATE" = "0" ]; then
        printf "\r${InvGreen} ${CClear} ${CWhite}Dig Functionality Test...    ${CGreen}[Passed]   ${CDkGray}| dig google.com${CClear}"
        DigFuncTest="Passed"
      else
        printf "\r${InvRed} ${CClear} ${CWhite}Dig Functionality Test...    ${CRed}[Failed]   ${CDkGray}| dig google.com${CClear}"
        DigFuncTest="Failed"
      fi
    echo ""

    printf "${InvYellow} ${CClear} ${CWhite}Curl Functionality Test...   ${CYellow}[Checking] ${CDkGray}| curl -Is http://www.google.com | head -n 1${CClear}"
      CURL_STATE="$(curl -Is http://www.google.com | head -n 1 >/dev/null 2>&1; echo $?)"
      sleep 1
      if [ "$CURL_STATE" = "0" ]; then
        printf "\r${InvGreen} ${CClear} ${CWhite}Curl Functionality Test...   ${CGreen}[Passed]   ${CDkGray}| curl -Is http://www.google.com | head -n 1${CClear}"
        CurlFuncTest="Passed"
      else
        printf "\r${InvRed} ${CClear} ${CWhite}Curl Functionality Test...   ${CRed}[Failed]   ${CDkGray}| curl -Is http://www.google.com | head -n 1${CClear}"
        CurlFuncTest="Failed"
      fi
    echo ""

    printf "${InvYellow} ${CClear} ${CWhite}Spider Functionality Test... ${CYellow}[Checking] ${CDkGray}| wget -q --spider http://google.com${CClear}"
      SPIDER_STATE="$(wget -q --spider http://google.com >/dev/null 2>&1; echo $?)"
      sleep 1
      if [ "$SPIDER_STATE" = "0" ]; then
        printf "\r${InvGreen} ${CClear} ${CWhite}Spider Functionality Test... ${CGreen}[Passed]   ${CDkGray}| wget -q --spider http://google.com${CClear}"
        SpiderFuncTest="Passed"
      else
        printf "\r${InvRed} ${CClear} ${CWhite}Spider Functionality Test... ${CRed}[Failed]   ${CDkGray}| wget -q --spider http://google.com${CClear}"
        SpiderFuncTest="Failed"
      fi
    echo ""

    printf "${InvYellow} ${CClear} ${CWhite}SSL Handshake Test...        ${CYellow}[Checking] ${CDkGray}| nc -w3 8.8.8.8 443 && echo | openssl s_client -connect 8.8.8.8:443>${CClear}"
      SSL_STATE="$(nc -w3 8.8.8.8 443 >/dev/null 2>&1 && echo | openssl s_client -connect 8.8.8.8:443 >/dev/null 2>&1 | awk 'handshake && $1 == "Verification" { if ($2=="OK") exit; exit 1 } $1 $2 == "SSLhandshake" { handshake = 1 }' >/dev/null 2>&1; echo $?)"
      sleep 1
      if [ "$SSL_STATE" = "0" ]; then
        printf "\r${InvGreen} ${CClear} ${CWhite}SSL Handshake Test...        ${CGreen}[Passed]   ${CDkGray}| nc -w3 8.8.8.8 443 && echo | openssl s_client -connect 8.8.8.8:443>${CClear}"
        SSLHandshakeTest="Passed"
      else
        printf "\r${InvRed} ${CClear} ${CWhite}SSL Handshake Test...        ${CRed}[Failed]   ${CDkGray}| nc -w3 8.8.8.8 443 && echo | openssl s_client -connect 8.8.8.8:443>${CClear}"
        SSLHandshakeTest="Failed"
      fi
    echo ""
    echo ""
    echo -e "${InvGreen} ${CClear}${InvDkGray}${CWhite} NMAP Port Scan Results                                                                                       ${CClear}"

    if [ "$PSView" == "TCP" ]; then
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear}${CWhite} Show Open ${InvDkGray} ${CGreen}(T)${CWhite}CP ${CClear}${CWhite} Ports  |  Show Open  ${CGreen}(U)${CWhite}DP  Ports${CClear}"
      echo -e "${InvGreen} ${CClear}${CDkGray}--------------------------------------------------------------------------------------------------------------${CClear}"
      echo ""
      if [ "$WAN0AltModes" == "0" ] || [ "$OpsMode" == "1" ]; then
        echo -e "${InvGreen} ${CClear} ${CWhite}WAN0 IP: ${CGreen}$oldwan0ip${CClear}"
        WANnmap=$(nmap $oldwan0ip | grep "open")
        if [ -z "$WANnmap" ]; then echo "None"; else nmap $oldwan0ip | grep "open"; fi
        echo ""
      fi
      echo -e "${InvGreen} ${CClear} ${CWhite}BR0 IP: ${CGreen}$oldlanip${CClear}"
      LANnmap=$(nmap $oldlanip | grep "open")
      if [ -z "$LANnmap" ]; then echo "None"; else nmap $oldlanip | grep "open"; fi
    elif [ "$PSView" == "UDP" ]; then
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear}${CWhite} Show Open  ${CGreen}(T)${CWhite}CP  Ports  |  Show Open ${InvDkGray} ${CGreen}(U)${CWhite}DP ${CClear}${CWhite} Ports${CClear}"
      echo -e "${InvGreen} ${CClear}${CDkGray}--------------------------------------------------------------------------------------------------------------${CClear}"
      echo ""
      if [ "$WAN0AltModes" == "0" ] || [ "$OpsMode" == "1" ]; then
        echo -e "${InvGreen} ${CClear} ${CWhite}WAN0 IP: ${CGreen}$oldwan0ip${CClear}"
        WANUnmap=$(nmap -sU $oldwan0ip | grep "open")
        if [ -z "$WANUnmap" ]; then echo "None"; else nmap -sU $oldwan0ip | grep "open"; fi
      echo ""
      fi
      echo -e "${InvGreen} ${CClear} ${CWhite}BR0 IP: ${CGreen}$oldlanip${CClear}"
      LANUnmap=$(nmap -sU $oldlanip | grep "open")
      if [ -z "$LANUnmap" ]; then echo "None"; else nmap -sU $oldlanip | grep "open"; fi
    fi

  { echo 'Lastruntime="'"$(date)"'"'
    echo 'LocalClockTest="'"$LocalClockTest"'"'
    echo 'NetworkConnTest="'"$NetworkConnTest"'"'
    echo 'NetworkResTest="'"$NetworkResTest"'"'
    echo 'DigFuncTest="'"$DigFuncTest"'"'
    echo 'CurlFuncTest="'"$CurlFuncTest"'"'
    echo 'SpiderFuncTest="'"$SpiderFuncTest"'"'
    echo 'SSLHandshakeTest="'"$SSLHandshakeTest"'"'
  } > $DIAGRESPATH

  if [ "$WAN0AltModes" == "0" ] || [ "$OpsMode" == "1" ]; then
    nmap $oldwan0ip -oN $NMAPWANRESPATH | grep "open" >/dev/null 2>&1
    nmap $oldwan0ip -sU -oN $NMAPUWANRESPATH | grep "open" >/dev/null 2>&1
  fi

  nmap $oldlanip -oN $NMAPLANRESPATH | grep "open" >/dev/null 2>&1
  nmap $oldlanip -sU -oN $NMAPULANRESPATH | grep "open" >/dev/null 2>&1

  QueueNetworkDiag=0

else

  if [ "$LocalClockTest" == "Passed" ]; then
    printf "\r${InvGreen} ${CClear} ${CWhite}Local Clock Test...          ${CGreen}[Passed]   ${CDkGray}| date > 1970${CClear}"
  else
    printf "\r${InvRed} ${CClear} ${CWhite}Local Clock Test...          ${CRed}[Failed]   ${CDkGray}| date > 1970${CClear}"
  fi
  echo ""
  if [ "$NetworkConnTest" == "Passed" ]; then
    printf "\r${InvGreen} ${CClear} ${CWhite}Network Connectivity Test... ${CGreen}[Passed]   ${CDkGray}| ping 1.1.1.1 -c1 -W2${CClear}"
  else
    printf "\r${InvRed} ${CClear} ${CWhite}Network Connectivity Test... ${CRed}[Failed]   ${CDkGray}| ping 1.1.1.1 -c1 -W2${CClear}"
  fi
  echo ""
  if [ "$WAN0AltModes" == "0" ] || [ "$OpsMode" == "1" ]; then
    if [ "$NetworkResTest" == "Passed" ]; then
      printf "\r${InvGreen} ${CClear} ${CWhite}Network Resolution Test...   ${CGreen}[Passed]   ${CDkGray}| nslookup google.com 127.0.0.1${CClear}"
    else
      printf "\r${InvRed} ${CClear} ${CWhite}Network Resolution Test...   ${CRed}[Failed]   ${CDkGray}| nslookup google.com 127.0.0.1${CClear}"
    fi
  else
    if [ "$NetworkResTest" == "Passed" ]; then
      printf "\r${InvGreen} ${CClear} ${CWhite}Network Resolution Test...   ${CGreen}[Passed]   ${CDkGray}| nslookup google.com${CClear}"
    else
      printf "\r${InvRed} ${CClear} ${CWhite}Network Resolution Test...   ${CRed}[Failed]   ${CDkGray}| nslookup google.com${CClear}"
    fi
  fi
  echo ""
  if [ "$DigFuncTest" == "Passed" ]; then
    printf "\r${InvGreen} ${CClear} ${CWhite}Dig Functionality Test...    ${CGreen}[Passed]   ${CDkGray}| dig google.com${CClear}"
  else
    printf "\r${InvRed} ${CClear} ${CWhite}Dig Functionality Test...    ${CRed}[Failed]   ${CDkGray}| dig google.com${CClear}"
  fi
  echo ""
  if [ "$CurlFuncTest" == "Passed" ]; then
    printf "\r${InvGreen} ${CClear} ${CWhite}Curl Functionality Test...   ${CGreen}[Passed]   ${CDkGray}| curl -Is http://www.google.com | head -n 1${CClear}"
  else
    printf "\r${InvRed} ${CClear} ${CWhite}Curl Functionality Test...   ${CRed}[Failed]   ${CDkGray}| curl -Is http://www.google.com | head -n 1${CClear}"
  fi
  echo ""
  if [ "$SpiderFuncTest" == "Passed" ]; then
    printf "\r${InvGreen} ${CClear} ${CWhite}Spider Functionality Test... ${CGreen}[Passed]   ${CDkGray}| wget -q --spider http://google.com${CClear}"
  else
    printf "\r${InvRed} ${CClear} ${CWhite}Spider Functionality Test... ${CRed}[Failed]   ${CDkGray}| wget -q --spider http://google.com${CClear}"
  fi
  echo ""
  if [ "$SSLHandshakeTest" == "Passed" ]; then
    printf "\r${InvGreen} ${CClear} ${CWhite}SSL Handshake Test...        ${CGreen}[Passed]   ${CDkGray}| nc -w3 8.8.8.8 443 && echo | openssl s_client -connect 8.8.8.8:443>${CClear}"
  else
    printf "\r${InvRed} ${CClear} ${CWhite}SSL Handshake Test...        ${CRed}[Failed]   ${CDkGray}| nc -w3 8.8.8.8 443 && echo | openssl s_client -connect 8.8.8.8:443>${CClear}"
  fi
  echo ""
  echo ""
  echo -e "${InvGreen} ${CClear}${InvDkGray}${CWhite} NMAP Port Scan Results                                                                                       ${CClear}"

  if [ "$PSView" == "TCP" ]; then
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear}${CWhite} Show Open ${InvDkGray} ${CGreen}(T)${CWhite}CP ${CClear}${CWhite} Ports  |  Show Open  ${CGreen}(U)${CWhite}DP  Ports${CClear}"
    echo -e "${InvGreen} ${CClear}${CDkGray}--------------------------------------------------------------------------------------------------------------${CClear}"
    echo ""
    if [ "$ScreenshotMode" == "1" ]; then
      oldwan0ip="12.34.56.78" #demo
    fi
    if [ "$WAN0AltModes" == "0" ] || [ "$OpsMode" == "1" ]; then
      echo -e "${InvGreen} ${CClear} ${CWhite}WAN0 IP: ${CGreen}$oldwan0ip${CClear}"
      if [ ! -f $NMAPWANRESPATH ]; then
        echo "None"
      else
        WANnmap=$(cat $NMAPWANRESPATH | grep "open")
        if [ -z "$WANnmap" ]; then echo "None"; else cat $NMAPWANRESPATH | grep "open"; fi
      fi
    echo ""
    fi
    echo -e "${InvGreen} ${CClear} ${CWhite}BR0 IP: ${CGreen}$oldlanip${CClear}"
    if [ ! -f $NMAPLANRESPATH ]; then
      echo "None"
    else
      LANnmap=$(cat $NMAPLANRESPATH | grep "open")
      if [ -z "$LANnmap" ]; then echo "None"; else cat $NMAPLANRESPATH | grep "open"; fi
    fi
  elif [ "$PSView" == "UDP" ]; then
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear}${CWhite} Show Open  ${CGreen}(T)${CWhite}CP  Ports  |  Show Open ${InvDkGray} ${CGreen}(U)${CWhite}DP ${CClear}${CWhite} Ports${CClear}"
    echo -e "${InvGreen} ${CClear}${CDkGray}--------------------------------------------------------------------------------------------------------------${CClear}"
    echo ""
    if [ "$WAN0AltModes" == "0" ] || [ "$OpsMode" == "1" ]; then
      echo -e "${InvGreen} ${CClear} ${CWhite}WAN0 IP: ${CGreen}$oldwan0ip${CClear}"
      if [ ! -f $NMAPUWANRESPATH ]; then
        echo "None"
      else
        WANUnmap=$(cat $NMAPUWANRESPATH | grep "open")
        if [ -z "$WANUnmap" ]; then echo "None"; else cat $NMAPUWANRESPATH | grep "open"; fi
      fi
      echo ""
    fi
    echo -e "${InvGreen} ${CClear} ${CWhite}BR0 IP: ${CGreen}$oldlanip${CClear}"
    if [ ! -f $NMAPULANRESPATH ]; then
      echo "None"
    else
      LANUnmap=$(cat $NMAPULANRESPATH | grep "open")
      if [ -z "$LANUnmap" ]; then echo "None"; else cat $NMAPULANRESPATH | grep "open"; fi
    fi
  fi
fi
}

# -------------------------------------------------------------------------------------------------------------------------

# This function displays the stats UI for page 6 which includes top bandwidth connections for WAN, LAN and VPN
DisplayPage6()
{
  clear
  if [ "$UpdateNotify" != "0" ]; then
    echo -e "$UpdateNotify${CClear}"
  fi
  showheader
  echo ""
  echo -e "${InvGreen} ${CClear}${InvDkGray}${CWhite} Top 10 Network Connections/Bandwidth Stats                                                                   ${CClear}"
  echo -e "${InvGreen} ${CClear}"

  if [ "$QueueNetworkConn" = "1" ]
  then
    #run network diags and save Results
    printf "${InvGreen} ${CClear} ${CWhite}[Updating WAN( ) LAN( ) VPN( ) WG( ) Statistics ... Please stand by...]"
    if [ "$WAN0AltModes" == "0" ] || [ "$OpsMode" == "1" ]; then
      iftop -t -i $WANIFNAME 2>&1 | sed '/^==/ q' > /jffs/addons/rtrmon.d/wanresult.txt
    fi
    printf "\r${InvGreen} ${CClear} ${CWhite}[Updating WAN(${CGreen}X${CWhite}) LAN( ) VPN( ) WG( ) Statistics ... Please stand by...]"
    iftop -t -i br0 2>&1 | sed '/^==/ q' > /jffs/addons/rtrmon.d/lanresult.txt
    printf "\r${InvGreen} ${CClear} ${CWhite}[Updating WAN(${CGreen}X${CWhite}) LAN(${CGreen}X${CWhite}) VPN( ) WG( ) Statistics ... Please stand by...]"

    if [ "$vpn1on" == "True" ] || [ "$vpn2on" == "True" ] || [ "$vpn3on" == "True" ] || [ "$vpn4on" == "True" ] || [ "$vpn5on" == "True" ]
    then
      slot=0
      while [ "$slot" -ne 5 ]
      do
        slot="$((slot+1))"
        selectedslot="vpn${slot}on"
        eval selectedslot="\$${selectedslot}"
        if [ "$selectedslot" = "True" ] && [ "$VPNSite2Site" = "0" ]
        then
          NVRAMVPNSLOTADDR=$($timeoutcmd$timeoutsec nvram get vpn_client"$slot"_addr)
          NVRAMVPNSLOTIP=$(ping -c 1 -w 1 $NVRAMVPNSLOTADDR | awk -F '[()]' '/PING/ { print $2}')
          if [ "$(echo "$NVRAMVPNSLOTIP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
            { echo 'Private Tunnel'
            } > /jffs/addons/rtrmon.d/vpn${slot}result.txt
          else
            iftop -t -i tun1$slot 2>&1 | sed '/^==/ q' > /jffs/addons/rtrmon.d/vpn${slot}result.txt
          fi
        fi
      done
    fi

    printf "\r${InvGreen} ${CClear} ${CWhite}[Updating WAN(${CGreen}X${CWhite}) LAN(${CGreen}X${CWhite}) VPN(${CGreen}X${CWhite}) WG( ) Statistics ... Please stand by...]"

    if [ "$wg1on" == "True" ] || [ "$wg2on" == "True" ] || [ "$wg3on" == "True" ] || [ "$wg4on" == "True" ] || [ "$wg5on" == "True" ]
    then
      slot=0
      while [ "$slot" -ne 5 ]
      do
        slot="$((slot+1))"
        selectedslot="wg${slot}on"
        eval selectedslot="\$${selectedslot}"
        if [ "$selectedslot" = "True" ] && [ "$VPNSite2Site" = "0" ]
        then
          WGTUN="wgc$slot"
          NVRAMWGSLOTADDR=$($timeoutcmd$timeoutsec nvram get "$WGTUN"_addr | cut -d '/' -f1)

          # Added based on suggestion from @ZebMcKayhan
          ip rule add from $NVRAMWGSLOTADDR lookup $WGTUN prio 10 >/dev/null 2>&1

          icanhazwgip="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$WGTUN" --request GET --url https://ipv4.icanhazip.com"
          icanhazwgip="$(eval $icanhazwgip)"
          if [ -z "$icanhazwgip" ] || echo "$icanhazwgip" | grep -qoE 'Internet|traffic|Error|error'
          then
            { echo 'Error determining WG$slot IP'
            } > /jffs/addons/rtrmon.d/wgc${slot}result.txt
          else
            NVRAMWGIP="$icanhazwgip"
          fi

          # Added based on suggestion from @ZebMcKayhan
          ip rule del prio 10 >/dev/null 2>&1

          if [ "$(echo "$NVRAMWGIP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
            { echo 'Private Tunnel'
            } > /jffs/addons/rtrmon.d/wgc${slot}result.txt
          else
            iftop -t -i wgc$slot 2>&1 | sed '/^==/ q' > /jffs/addons/rtrmon.d/wgc${slot}result.txt
          fi
        fi
      done
    fi

    printf "\r${InvGreen} ${CClear} ${CWhite}[Updating WAN(${CGreen}X${CWhite}) LAN(${CGreen}X${CWhite}) VPN(${CGreen}X${CWhite}) WG(${CGreen}X${CWhite}) Statistics ... Please stand by...]"
    sleep 1
    printf "\r                                                                                                 "
    QueueNetworkConn=0
    testrun="$(date +%s)"

    if [ -z "${testrun:+xSETx}" ]
    then
      lastrun="Not Current"
    else
      currtime="$(date +%s)"
      mindiffs="$(( ($currtime - $testrun)/60 ))"
      lastrun="$mindiffs Minute(s) ago"
    fi

    echo -e "\r${InvGreen} ${CClear} ${CWhite}Refresh ${CGreen}(C)${CWhite}urrent Statistics  |  Stats Age: ${CGreen}$lastrun${CClear}"
  else
    if [ -z "${testrun:+xSETx}" ]
    then
      lastrun="Not Current"
    else
      currtime="$(date +%s)"
      mindiffs="$(( ($currtime - $testrun)/60 ))"
      lastrun="$mindiffs Minute(s) ago"
    fi
    echo -e "${InvGreen} ${CClear} ${CWhite}Refresh ${CGreen}(C)${CWhite}urrent Statistics  |  Stats Age: ${CGreen}$lastrun${CClear}"
  fi

  if [ "$NCView" == "WAN" ]; then
    if [ "$vpn1on" == "True" ] || [ "$vpn2on" == "True" ] || [ "$vpn3on" == "True" ] || [ "$vpn4on" == "True" ] || [ "$vpn5on" == "True" ] || [ "$wg1on" == "True" ] || [ "$wg2on" == "True" ] || [ "$wg3on" == "True" ] || [ "$wg4on" == "True" ] || [ "$wg5on" == "True" ]; then
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear}${CWhite} View ${InvDkGray} ${CGreen}(W)${CWhite}AN ${CClear}${CWhite} |  ${CGreen}(L)${CWhite}AN  |  ${CGreen}(V)${CWhite}PN  |  W${CGreen}(G)${CClear}"
    else
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear}${CWhite} View ${InvDkGray} ${CGreen}(W)${CWhite}AN ${CClear}${CWhite} |  ${CGreen}(L)${CWhite}AN${CClear}"
    fi

    echo -e "${InvGreen} ${CClear}${CDkGray}--------------------------------------------------------------------------------------------------------------${CClear}"
    echo ""
    echo -e "${InvGreen} ${CClear}${InvDkGray}${CWhite} WAN                                                                                                          ${CClear}"

    wansegments1=$(cat /jffs/addons/rtrmon.d/wanresult.txt 2>&1 | awk 'NR==7 {print $1, $2, $4} NR==8 {print $1, $3}')

    line1="$(echo $wansegments1 | awk '{print $1}')"
    dest1="$(echo $wansegments1 | awk '{print $2}')"
    out1="$(echo $wansegments1 | awk '{print $3}')"
    src1="$(echo $wansegments1 | awk '{print $4}')"
    in1="$(echo $wansegments1 | awk '{print $5}')"

    wansegments2=$(cat /jffs/addons/rtrmon.d/wanresult.txt 2>&1 | awk 'NR==9 {print $1, $2, $4} NR==10 {print $1, $3}')

    line2="$(echo $wansegments2 | awk '{print $1}')"
    dest2="$(echo $wansegments2 | awk '{print $2}')"
    out2="$(echo $wansegments2 | awk '{print $3}')"
    src2="$(echo $wansegments2 | awk '{print $4}')"
    in2="$(echo $wansegments2 | awk '{print $5}')"

    wansegments3=$(cat /jffs/addons/rtrmon.d/wanresult.txt 2>&1 | awk 'NR==11 {print $1, $2, $4} NR==12 {print $1, $3}')

    line3="$(echo $wansegments3 | awk '{print $1}')"
    dest3="$(echo $wansegments3 | awk '{print $2}')"
    out3="$(echo $wansegments3 | awk '{print $3}')"
    src3="$(echo $wansegments3 | awk '{print $4}')"
    in3="$(echo $wansegments3 | awk '{print $5}')"

    wansegments4=$(cat /jffs/addons/rtrmon.d/wanresult.txt 2>&1 | awk 'NR==13 {print $1, $2, $4} NR==14 {print $1, $3}')

    line4="$(echo $wansegments4 | awk '{print $1}')"
    dest4="$(echo $wansegments4 | awk '{print $2}')"
    out4="$(echo $wansegments4 | awk '{print $3}')"
    src4="$(echo $wansegments4 | awk '{print $4}')"
    in4="$(echo $wansegments4 | awk '{print $5}')"

    wansegments5=$(cat /jffs/addons/rtrmon.d/wanresult.txt 2>&1 | awk 'NR==15 {print $1, $2, $4} NR==16 {print $1, $3}')

    line5="$(echo $wansegments5 | awk '{print $1}')"
    dest5="$(echo $wansegments5 | awk '{print $2}')"
    out5="$(echo $wansegments5 | awk '{print $3}')"
    src5="$(echo $wansegments5 | awk '{print $4}')"
    in5="$(echo $wansegments5 | awk '{print $5}')"

    wansegments6=$(cat /jffs/addons/rtrmon.d/wanresult.txt 2>&1 | awk 'NR==17 {print $1, $2, $4} NR==18 {print $1, $3}')

    line6="$(echo $wansegments6 | awk '{print $1}')"
    dest6="$(echo $wansegments6 | awk '{print $2}')"
    out6="$(echo $wansegments6 | awk '{print $3}')"
    src6="$(echo $wansegments6 | awk '{print $4}')"
    in6="$(echo $wansegments6 | awk '{print $5}')"

    wansegments7=$(cat /jffs/addons/rtrmon.d/wanresult.txt 2>&1 | awk 'NR==19 {print $1, $2, $4} NR==20 {print $1, $3}')

    line7="$(echo $wansegments7 | awk '{print $1}')"
    dest7="$(echo $wansegments7 | awk '{print $2}')"
    out7="$(echo $wansegments7 | awk '{print $3}')"
    src7="$(echo $wansegments7 | awk '{print $4}')"
    in7="$(echo $wansegments7 | awk '{print $5}')"

    wansegments8=$(cat /jffs/addons/rtrmon.d/wanresult.txt 2>&1 | awk 'NR==21 {print $1, $2, $4} NR==22 {print $1, $3}')

    line8="$(echo $wansegments8 | awk '{print $1}')"
    dest8="$(echo $wansegments8 | awk '{print $2}')"
    out8="$(echo $wansegments8 | awk '{print $3}')"
    src8="$(echo $wansegments8 | awk '{print $4}')"
    in8="$(echo $wansegments8 | awk '{print $5}')"

    wansegments9=$(cat /jffs/addons/rtrmon.d/wanresult.txt 2>&1 | awk 'NR==23 {print $1, $2, $4} NR==24 {print $1, $3}')

    line9="$(echo $wansegments9 | awk '{print $1}')"
    dest9="$(echo $wansegments9 | awk '{print $2}')"
    out9="$(echo $wansegments9 | awk '{print $3}')"
    src9="$(echo $wansegments9 | awk '{print $4}')"
    in9="$(echo $wansegments9 | awk '{print $5}')"

    wansegments10=$(cat /jffs/addons/rtrmon.d/wanresult.txt 2>&1 | awk 'NR==25 {print $1, $2, $4} NR==26 {print $1, $3}')

    line10="$(echo $wansegments10 | awk '{print $1}')"
    dest10="$(echo $wansegments10 | awk '{print $2}')"
    out10="$(echo $wansegments10 | awk '{print $3}')"
    src10="$(echo $wansegments10 | awk '{print $4}')"
    in10="$(echo $wansegments10 | awk '{print $5}')"

    if [ "$line1" == "1" ]; then
      printf "${CWhite}%-82s${CGreen}%s\n" " $line1  $dest1 <=> $src1" "  Out: $out1 | In: $in1"
    else
      echo "No Data"
    fi

    if [ "$line2" == "2" ]; then
      printf "${CWhite}%-82s${CGreen}%s\n" " $line2  $dest2 <=> $src2" "  Out: $out2 | In: $in2"
    fi

    if [ "$line3" == "3" ]; then
      printf "${CWhite}%-82s${CGreen}%s\n" " $line3  $dest3 <=> $src3" "  Out: $out3 | In: $in3"
    fi

    if [ "$line4" == "4" ]; then
      printf "${CWhite}%-82s${CGreen}%s\n" " $line4  $dest4 <=> $src4" "  Out: $out4 | In: $in4"
    fi

    if [ "$line5" == "5" ]; then
      printf "${CWhite}%-82s${CGreen}%s\n" " $line5  $dest5 <=> $src5" "  Out: $out5 | In: $in5"
    fi

    if [ "$line6" == "6" ]; then
      printf "${CWhite}%-82s${CGreen}%s\n" " $line6  $dest6 <=> $src6" "  Out: $out6 | In: $in6"
    fi

    if [ "$line7" == "7" ]; then
      printf "${CWhite}%-82s${CGreen}%s\n" " $line7  $dest7 <=> $src7" "  Out: $out7 | In: $in7"
    fi

    if [ "$line8" == "8" ]; then
      printf "${CWhite}%-82s${CGreen}%s\n" " $line8  $dest8 <=> $src8" "  Out: $out8 | In: $in8"
    fi

    if [ "$line9" == "9" ]; then
      printf "${CWhite}%-82s${CGreen}%s\n" " $line9  $dest9 <=> $src9" "  Out: $out9 | In: $in9"
    fi

    if [ "$line10" == "10" ]; then
      printf "${CWhite}%-82s${CGreen}%s\n" "$line10  $dest10 <=> $src10" "  Out: $out10 | In: $in10"
    fi
  fi

  if [ "$NCView" == "LAN" ]; then
    if [ "$vpn1on" == "True" ] || [ "$vpn2on" == "True" ] || [ "$vpn3on" == "True" ] || [ "$vpn4on" == "True" ] || [ "$vpn5on" == "True" ] || [ "$wg1on" == "True" ] || [ "$wg2on" == "True" ] || [ "$wg3on" == "True" ] || [ "$wg4on" == "True" ] || [ "$wg5on" == "True" ]; then
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear}${CWhite} View  ${CGreen}(W)${CWhite}AN  | ${InvDkGray} ${CGreen}(L)${CWhite}AN ${CClear}${CWhite} |  ${CGreen}(V)${CWhite}PN  |  W${CGreen}(G)${CClear}"
    else
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear}${CWhite} View  ${CGreen}(W)${CWhite}AN  | ${InvDkGray} ${CGreen}(L)${CWhite}AN ${CClear}"
    fi

    echo -e "${InvGreen} ${CClear}${CDkGray}--------------------------------------------------------------------------------------------------------------${CClear}"
    echo ""

    echo -e "${InvGreen} ${CClear}${InvDkGray}${CWhite} LAN                                                                                                          ${CClear}"

    lansegments1=$(cat /jffs/addons/rtrmon.d/lanresult.txt 2>&1 | awk 'NR==7 {print $1, $2, $4} NR==8 {print $1, $3}')

    line1="$(echo $lansegments1 | awk '{print $1}')"
    dest1="$(echo $lansegments1 | awk '{print $2}')"
    out1="$(echo $lansegments1 | awk '{print $3}')"
    src1="$(echo $lansegments1 | awk '{print $4}')"
    in1="$(echo $lansegments1 | awk '{print $5}')"

    lansegments2=$(cat /jffs/addons/rtrmon.d/lanresult.txt 2>&1 | awk 'NR==9 {print $1, $2, $4} NR==10 {print $1, $3}')

    line2="$(echo $lansegments2 | awk '{print $1}')"
    dest2="$(echo $lansegments2 | awk '{print $2}')"
    out2="$(echo $lansegments2 | awk '{print $3}')"
    src2="$(echo $lansegments2 | awk '{print $4}')"
    in2="$(echo $lansegments2 | awk '{print $5}')"

    lansegments3=$(cat /jffs/addons/rtrmon.d/lanresult.txt 2>&1 | awk 'NR==11 {print $1, $2, $4} NR==12 {print $1, $3}')

    line3="$(echo $lansegments3 | awk '{print $1}')"
    dest3="$(echo $lansegments3 | awk '{print $2}')"
    out3="$(echo $lansegments3 | awk '{print $3}')"
    src3="$(echo $lansegments3 | awk '{print $4}')"
    in3="$(echo $lansegments3 | awk '{print $5}')"

    lansegments4=$(cat /jffs/addons/rtrmon.d/lanresult.txt 2>&1 | awk 'NR==13 {print $1, $2, $4} NR==14 {print $1, $3}')

    line4="$(echo $lansegments4 | awk '{print $1}')"
    dest4="$(echo $lansegments4 | awk '{print $2}')"
    out4="$(echo $lansegments4 | awk '{print $3}')"
    src4="$(echo $lansegments4 | awk '{print $4}')"
    in4="$(echo $lansegments4 | awk '{print $5}')"

    lansegments5=$(cat /jffs/addons/rtrmon.d/lanresult.txt 2>&1 | awk 'NR==15 {print $1, $2, $4} NR==16 {print $1, $3}')

    line5="$(echo $lansegments5 | awk '{print $1}')"
    dest5="$(echo $lansegments5 | awk '{print $2}')"
    out5="$(echo $lansegments5 | awk '{print $3}')"
    src5="$(echo $lansegments5 | awk '{print $4}')"
    in5="$(echo $lansegments5 | awk '{print $5}')"

    lansegments6=$(cat /jffs/addons/rtrmon.d/lanresult.txt 2>&1 | awk 'NR==17 {print $1, $2, $4} NR==18 {print $1, $3}')

    line6="$(echo $lansegments6 | awk '{print $1}')"
    dest6="$(echo $lansegments6 | awk '{print $2}')"
    out6="$(echo $lansegments6 | awk '{print $3}')"
    src6="$(echo $lansegments6 | awk '{print $4}')"
    in6="$(echo $lansegments6 | awk '{print $5}')"

    lansegments7=$(cat /jffs/addons/rtrmon.d/lanresult.txt 2>&1 | awk 'NR==19 {print $1, $2, $4} NR==20 {print $1, $3}')

    line7="$(echo $lansegments7 | awk '{print $1}')"
    dest7="$(echo $lansegments7 | awk '{print $2}')"
    out7="$(echo $lansegments7 | awk '{print $3}')"
    src7="$(echo $lansegments7 | awk '{print $4}')"
    in7="$(echo $lansegments7 | awk '{print $5}')"

    lansegments8=$(cat /jffs/addons/rtrmon.d/lanresult.txt 2>&1 | awk 'NR==21 {print $1, $2, $4} NR==22 {print $1, $3}')

    line8="$(echo $lansegments8 | awk '{print $1}')"
    dest8="$(echo $lansegments8 | awk '{print $2}')"
    out8="$(echo $lansegments8 | awk '{print $3}')"
    src8="$(echo $lansegments8 | awk '{print $4}')"
    in8="$(echo $lansegments8 | awk '{print $5}')"

    lansegments9=$(cat /jffs/addons/rtrmon.d/lanresult.txt 2>&1 | awk 'NR==23 {print $1, $2, $4} NR==24 {print $1, $3}')

    line9="$(echo $lansegments9 | awk '{print $1}')"
    dest9="$(echo $lansegments9 | awk '{print $2}')"
    out9="$(echo $lansegments9 | awk '{print $3}')"
    src9="$(echo $lansegments9 | awk '{print $4}')"
    in9="$(echo $lansegments9 | awk '{print $5}')"

    lansegments10=$(cat /jffs/addons/rtrmon.d/lanresult.txt 2>&1 | awk 'NR==25 {print $1, $2, $4} NR==26 {print $1, $3}')

    line10="$(echo $lansegments10 | awk '{print $1}')"
    dest10="$(echo $lansegments10 | awk '{print $2}')"
    out10="$(echo $lansegments10 | awk '{print $3}')"
    src10="$(echo $lansegments10 | awk '{print $4}')"
    in10="$(echo $lansegments10 | awk '{print $5}')"

    if [ "$line1" == "1" ]; then
      printf "${CWhite}%-82s${CGreen}%s\n" " $line1  $dest1 <=> $src1" "  Out: $out1 | In: $in1"
    else
      echo "No Data"
    fi

    if [ "$line2" == "2" ]; then
      printf "${CWhite}%-82s${CGreen}%s\n" " $line2  $dest2 <=> $src2" "  Out: $out2 | In: $in2"
    fi

    if [ "$line3" == "3" ]; then
      printf "${CWhite}%-82s${CGreen}%s\n" " $line3  $dest3 <=> $src3" "  Out: $out3 | In: $in3"
    fi

    if [ "$line4" == "4" ]; then
      printf "${CWhite}%-82s${CGreen}%s\n" " $line4  $dest4 <=> $src4" "  Out: $out4 | In: $in4"
    fi

    if [ "$line5" == "5" ]; then
      printf "${CWhite}%-82s${CGreen}%s\n" " $line5  $dest5 <=> $src5" "  Out: $out5 | In: $in5"
    fi

    if [ "$line6" == "6" ]; then
      printf "${CWhite}%-82s${CGreen}%s\n" " $line6  $dest6 <=> $src6" "  Out: $out6 | In: $in6"
    fi

    if [ "$line7" == "7" ]; then
      printf "${CWhite}%-82s${CGreen}%s\n" " $line7  $dest7 <=> $src7" "  Out: $out7 | In: $in7"
    fi

    if [ "$line8" == "8" ]; then
      printf "${CWhite}%-82s${CGreen}%s\n" " $line8  $dest8 <=> $src8" "  Out: $out8 | In: $in8"
    fi

    if [ "$line9" == "9" ]; then
      printf "${CWhite}%-82s${CGreen}%s\n" " $line9  $dest9 <=> $src9" "  Out: $out9 | In: $in9"
    fi

    if [ "$line10" == "10" ]; then
      printf "${CWhite}%-82s${CGreen}%s\n" "$line10  $dest10 <=> $src10" "  Out: $out10 | In: $in10"
    fi
  fi

  if [ "$NCView" = "VPN" ]
  then
    if [ "$vpn1on" == "True" ] || [ "$vpn2on" == "True" ] || [ "$vpn3on" == "True" ] || [ "$vpn4on" == "True" ] || [ "$vpn5on" == "True" ] || [ "$wg1on" == "True" ] || [ "$wg2on" == "True" ] || [ "$wg3on" == "True" ] || [ "$wg4on" == "True" ] || [ "$wg5on" == "True" ]; then
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear}${CWhite} View  ${CGreen}(W)${CWhite}AN  ${CWhite}|  ${CGreen}(L)${CWhite}AN  | ${InvDkGray} ${CGreen}(V)${CWhite}PN ${CClear} ${CWhite}|  W${CGreen}(G)${CClear}"
      echo -e "${InvGreen} ${CClear}${CDkGray}--------------------------------------------------------------------------------------------------------------${CClear}"
      echo ""

      slot=0
      while [ "$slot" -ne 5 ]
      do
        slot="$((slot+1))"
        selectedslot="vpn${slot}on"
        eval selectedslot="\$${selectedslot}"
        if [ "$selectedslot" = "True" ] && [ "$VPNSite2Site" = "0" ]
        then
          echo -e "${InvGreen} ${CClear}${InvDkGray}${CWhite} VPN$slot                                                                                                         ${CClear}"

          vpnsegments1=$(cat /jffs/addons/rtrmon.d/vpn${slot}result.txt 2>&1 | awk 'NR==7 {print $1, $2, $4} NR==8 {print $1, $3}')

          line1="$(echo $vpnsegments1 | awk '{print $1}')"
          dest1="$(echo $vpnsegments1 | awk '{print $2}')"
          out1="$(echo $vpnsegments1 | awk '{print $3}')"
          src1="$(echo $vpnsegments1 | awk '{print $4}')"
          in1="$(echo $vpnsegments1 | awk '{print $5}')"

          vpnsegments2=$(cat /jffs/addons/rtrmon.d/vpn${slot}result.txt 2>&1 | awk 'NR==9 {print $1, $2, $4} NR==10 {print $1, $3}')

          line2="$(echo $vpnsegments2 | awk '{print $1}')"
          dest2="$(echo $vpnsegments2 | awk '{print $2}')"
          out2="$(echo $vpnsegments2 | awk '{print $3}')"
          src2="$(echo $vpnsegments2 | awk '{print $4}')"
          in2="$(echo $vpnsegments2 | awk '{print $5}')"

          vpnsegments3=$(cat /jffs/addons/rtrmon.d/vpn${slot}result.txt 2>&1 | awk 'NR==11 {print $1, $2, $4} NR==12 {print $1, $3}')

          line3="$(echo $vpnsegments3 | awk '{print $1}')"
          dest3="$(echo $vpnsegments3 | awk '{print $2}')"
          out3="$(echo $vpnsegments3 | awk '{print $3}')"
          src3="$(echo $vpnsegments3 | awk '{print $4}')"
          in3="$(echo $vpnsegments3 | awk '{print $5}')"

          vpnsegments4=$(cat /jffs/addons/rtrmon.d/vpn${slot}result.txt 2>&1 | awk 'NR==13 {print $1, $2, $4} NR==14 {print $1, $3}')

          line4="$(echo $vpnsegments4 | awk '{print $1}')"
          dest4="$(echo $vpnsegments4 | awk '{print $2}')"
          out4="$(echo $vpnsegments4 | awk '{print $3}')"
          src4="$(echo $vpnsegments4 | awk '{print $4}')"
          in4="$(echo $vpnsegments4 | awk '{print $5}')"

          vpnsegments5=$(cat /jffs/addons/rtrmon.d/vpn${slot}result.txt 2>&1 | awk 'NR==15 {print $1, $2, $4} NR==16 {print $1, $3}')

          line5="$(echo $vpnsegments5 | awk '{print $1}')"
          dest5="$(echo $vpnsegments5 | awk '{print $2}')"
          out5="$(echo $vpnsegments5 | awk '{print $3}')"
          src5="$(echo $vpnsegments5 | awk '{print $4}')"
          in5="$(echo $vpnsegments5 | awk '{print $5}')"

          vpnsegments6=$(cat /jffs/addons/rtrmon.d/vpn${slot}result.txt 2>&1 | awk 'NR==17 {print $1, $2, $4} NR==18 {print $1, $3}')

          line6="$(echo $vpnsegments6 | awk '{print $1}')"
          dest6="$(echo $vpnsegments6 | awk '{print $2}')"
          out6="$(echo $vpnsegments6 | awk '{print $3}')"
          src6="$(echo $vpnsegments6 | awk '{print $4}')"
          in6="$(echo $vpnsegments6 | awk '{print $5}')"

          vpnsegments7=$(cat /jffs/addons/rtrmon.d/vpn${slot}result.txt 2>&1 | awk 'NR==19 {print $1, $2, $4} NR==20 {print $1, $3}')

          line7="$(echo $vpnsegments7 | awk '{print $1}')"
          dest7="$(echo $vpnsegments7 | awk '{print $2}')"
          out7="$(echo $vpnsegments7 | awk '{print $3}')"
          src7="$(echo $vpnsegments7 | awk '{print $4}')"
          in7="$(echo $vpnsegments7 | awk '{print $5}')"

          vpnsegments8=$(cat /jffs/addons/rtrmon.d/vpn${slot}result.txt 2>&1 | awk 'NR==21 {print $1, $2, $4} NR==22 {print $1, $3}')

          line8="$(echo $vpnsegments8 | awk '{print $1}')"
          dest8="$(echo $vpnsegments8 | awk '{print $2}')"
          out8="$(echo $vpnsegments8 | awk '{print $3}')"
          src8="$(echo $vpnsegments8 | awk '{print $4}')"
          in8="$(echo $vpnsegments8 | awk '{print $5}')"

          vpnsegments9=$(cat /jffs/addons/rtrmon.d/vpn${slot}result.txt 2>&1 | awk 'NR==23 {print $1, $2, $4} NR==24 {print $1, $3}')

          line9="$(echo $vpnsegments9 | awk '{print $1}')"
          dest9="$(echo $vpnsegments9 | awk '{print $2}')"
          out9="$(echo $vpnsegments9 | awk '{print $3}')"
          src9="$(echo $vpnsegments9 | awk '{print $4}')"
          in9="$(echo $vpnsegments9 | awk '{print $5}')"

          vpnsegments10=$(cat /jffs/addons/rtrmon.d/vpn${slot}result.txt 2>&1 | awk 'NR==25 {print $1, $2, $4} NR==26 {print $1, $3}')

          line10="$(echo $vpnsegments10 | awk '{print $1}')"
          dest10="$(echo $vpnsegments10 | awk '{print $2}')"
          out10="$(echo $vpnsegments10 | awk '{print $3}')"
          src10="$(echo $vpnsegments10 | awk '{print $4}')"
          in10="$(echo $vpnsegments10 | awk '{print $5}')"

          if [ "$line1" == "1" ]; then
            printf "${CWhite}%-82s${CGreen}%s\n" " $line1  $dest1 <=> $src1" "  Out: $out1 | In: $in1"
          else
            echo "No Data"
          fi

          if [ "$line2" == "2" ]; then
            printf "${CWhite}%-82s${CGreen}%s\n" " $line2  $dest2 <=> $src2" "  Out: $out2 | In: $in2"
          fi

          if [ "$line3" == "3" ]; then
            printf "${CWhite}%-82s${CGreen}%s\n" " $line3  $dest3 <=> $src3" "  Out: $out3 | In: $in3"
          fi

          if [ "$line4" == "4" ]; then
            printf "${CWhite}%-82s${CGreen}%s\n" " $line4  $dest4 <=> $src4" "  Out: $out4 | In: $in4"
          fi

          if [ "$line5" == "5" ]; then
            printf "${CWhite}%-82s${CGreen}%s\n" " $line5  $dest5 <=> $src5" "  Out: $out5 | In: $in5"
          fi

          if [ "$line6" == "6" ]; then
            printf "${CWhite}%-82s${CGreen}%s\n" " $line6  $dest6 <=> $src6" "  Out: $out6 | In: $in6"
          fi

          if [ "$line7" == "7" ]; then
            printf "${CWhite}%-82s${CGreen}%s\n" " $line7  $dest7 <=> $src7" "  Out: $out7 | In: $in7"
          fi

          if [ "$line8" == "8" ]; then
            printf "${CWhite}%-82s${CGreen}%s\n" " $line8  $dest8 <=> $src8" "  Out: $out8 | In: $in8"
          fi

          if [ "$line9" == "9" ]; then
            printf "${CWhite}%-82s${CGreen}%s\n" " $line9  $dest9 <=> $src9" "  Out: $out9 | In: $in9"
          fi

          if [ "$line10" == "10" ]; then
            printf "${CWhite}%-82s${CGreen}%s\n" "$line10  $dest10 <=> $src10" "  Out: $out10 | In: $in10"
          fi

          echo ""
        fi
      done
    fi
  fi

if [ "$NCView" = "WG" ]
  then
    if [ "$vpn1on" == "True" ] || [ "$vpn2on" == "True" ] || [ "$vpn3on" == "True" ] || [ "$vpn4on" == "True" ] || [ "$vpn5on" == "True" ] || [ "$wg1on" == "True" ] || [ "$wg2on" == "True" ] || [ "$wg3on" == "True" ] || [ "$wg4on" == "True" ] || [ "$wg5on" == "True" ]; then
      echo -e "${InvGreen} ${CClear}"
      echo -e "${InvGreen} ${CClear}${CWhite} View  ${CGreen}(W)${CWhite}AN  ${CWhite}|  ${CGreen}(L)${CWhite}AN  |  ${CGreen}(V)${CWhite}PN  | ${InvDkGray} W${CGreen}(G) ${CClear}"
      echo -e "${InvGreen} ${CClear}${CDkGray}--------------------------------------------------------------------------------------------------------------${CClear}"
      echo ""

      slot=0
      while [ "$slot" -ne 5 ]
      do
        slot="$((slot+1))"
        selectedslot="wg${slot}on"
        eval selectedslot="\$${selectedslot}"
        if [ "$selectedslot" = "True" ] && [ "$VPNSite2Site" = "0" ]
        then
          echo -e "${InvGreen} ${CClear}${InvDkGray}${CWhite} WG$slot                                                                                                          ${CClear}"

          wgsegments1=$(cat /jffs/addons/rtrmon.d/wgc${slot}result.txt 2>&1 | awk 'NR==7 {print $1, $2, $4} NR==8 {print $1, $3}')

          line1="$(echo $wgsegments1 | awk '{print $1}')"
          dest1="$(echo $wgsegments1 | awk '{print $2}')"
          out1="$(echo $wgsegments1 | awk '{print $3}')"
          src1="$(echo $wgsegments1 | awk '{print $4}')"
          in1="$(echo $wgsegments1 | awk '{print $5}')"

          wgsegments2=$(cat /jffs/addons/rtrmon.d/wgc${slot}result.txt 2>&1 | awk 'NR==9 {print $1, $2, $4} NR==10 {print $1, $3}')

          line2="$(echo $wgsegments2 | awk '{print $1}')"
          dest2="$(echo $wgsegments2 | awk '{print $2}')"
          out2="$(echo $wgsegments2 | awk '{print $3}')"
          src2="$(echo $wgsegments2 | awk '{print $4}')"
          in2="$(echo $wgsegments2 | awk '{print $5}')"

          wgsegments3=$(cat /jffs/addons/rtrmon.d/wgc${slot}result.txt 2>&1 | awk 'NR==11 {print $1, $2, $4} NR==12 {print $1, $3}')

          line3="$(echo $wgsegments3 | awk '{print $1}')"
          dest3="$(echo $wgsegments3 | awk '{print $2}')"
          out3="$(echo $wgsegments3 | awk '{print $3}')"
          src3="$(echo $wgsegments3 | awk '{print $4}')"
          in3="$(echo $wgsegments3 | awk '{print $5}')"

          wgsegments4=$(cat /jffs/addons/rtrmon.d/wgc${slot}result.txt 2>&1 | awk 'NR==13 {print $1, $2, $4} NR==14 {print $1, $3}')

          line4="$(echo $wgsegments4 | awk '{print $1}')"
          dest4="$(echo $wgsegments4 | awk '{print $2}')"
          out4="$(echo $wgsegments4 | awk '{print $3}')"
          src4="$(echo $wgsegments4 | awk '{print $4}')"
          in4="$(echo $wgsegments4 | awk '{print $5}')"

          wgsegments5=$(cat /jffs/addons/rtrmon.d/wgc${slot}result.txt 2>&1 | awk 'NR==15 {print $1, $2, $4} NR==16 {print $1, $3}')

          line5="$(echo $wgsegments5 | awk '{print $1}')"
          dest5="$(echo $wgsegments5 | awk '{print $2}')"
          out5="$(echo $wgsegments5 | awk '{print $3}')"
          src5="$(echo $wgsegments5 | awk '{print $4}')"
          in5="$(echo $wgsegments5 | awk '{print $5}')"

          wgsegments6=$(cat /jffs/addons/rtrmon.d/wgc${slot}result.txt 2>&1 | awk 'NR==17 {print $1, $2, $4} NR==18 {print $1, $3}')

          line6="$(echo $wgsegments6 | awk '{print $1}')"
          dest6="$(echo $wgsegments6 | awk '{print $2}')"
          out6="$(echo $wgsegments6 | awk '{print $3}')"
          src6="$(echo $wgsegments6 | awk '{print $4}')"
          in6="$(echo $wgsegments6 | awk '{print $5}')"

          wgsegments7=$(cat /jffs/addons/rtrmon.d/wgc${slot}result.txt 2>&1 | awk 'NR==19 {print $1, $2, $4} NR==20 {print $1, $3}')

          line7="$(echo $wgsegments7 | awk '{print $1}')"
          dest7="$(echo $wgsegments7 | awk '{print $2}')"
          out7="$(echo $wgsegments7 | awk '{print $3}')"
          src7="$(echo $wgsegments7 | awk '{print $4}')"
          in7="$(echo $wgsegments7 | awk '{print $5}')"

          wgsegments8=$(cat /jffs/addons/rtrmon.d/wgc${slot}result.txt 2>&1 | awk 'NR==21 {print $1, $2, $4} NR==22 {print $1, $3}')

          line8="$(echo $wgsegments8 | awk '{print $1}')"
          dest8="$(echo $wgsegments8 | awk '{print $2}')"
          out8="$(echo $wgsegments8 | awk '{print $3}')"
          src8="$(echo $wgsegments8 | awk '{print $4}')"
          in8="$(echo $wgsegments8 | awk '{print $5}')"

          wgsegments9=$(cat /jffs/addons/rtrmon.d/wgc${slot}result.txt 2>&1 | awk 'NR==23 {print $1, $2, $4} NR==24 {print $1, $3}')

          line9="$(echo $wgsegments9 | awk '{print $1}')"
          dest9="$(echo $wgsegments9 | awk '{print $2}')"
          out9="$(echo $wgsegments9 | awk '{print $3}')"
          src9="$(echo $wgsegments9 | awk '{print $4}')"
          in9="$(echo $wgsegments9 | awk '{print $5}')"

          wgsegments10=$(cat /jffs/addons/rtrmon.d/wgc${slot}result.txt 2>&1 | awk 'NR==25 {print $1, $2, $4} NR==26 {print $1, $3}')

          line10="$(echo $wgsegments10 | awk '{print $1}')"
          dest10="$(echo $wgsegments10 | awk '{print $2}')"
          out10="$(echo $wgsegments10 | awk '{print $3}')"
          src10="$(echo $wgsegments10 | awk '{print $4}')"
          in10="$(echo $wgsegments10 | awk '{print $5}')"

          if [ "$line1" == "1" ]; then
            printf "${CWhite}%-82s${CGreen}%s\n" " $line1  $dest1 <=> $src1" "  Out: $out1 | In: $in1"
          else
            echo "No Data"
          fi

          if [ "$line2" == "2" ]; then
            printf "${CWhite}%-82s${CGreen}%s\n" " $line2  $dest2 <=> $src2" "  Out: $out2 | In: $in2"
          fi

          if [ "$line3" == "3" ]; then
            printf "${CWhite}%-82s${CGreen}%s\n" " $line3  $dest3 <=> $src3" "  Out: $out3 | In: $in3"
          fi

          if [ "$line4" == "4" ]; then
            printf "${CWhite}%-82s${CGreen}%s\n" " $line4  $dest4 <=> $src4" "  Out: $out4 | In: $in4"
          fi

          if [ "$line5" == "5" ]; then
            printf "${CWhite}%-82s${CGreen}%s\n" " $line5  $dest5 <=> $src5" "  Out: $out5 | In: $in5"
          fi

          if [ "$line6" == "6" ]; then
            printf "${CWhite}%-82s${CGreen}%s\n" " $line6  $dest6 <=> $src6" "  Out: $out6 | In: $in6"
          fi

          if [ "$line7" == "7" ]; then
            printf "${CWhite}%-82s${CGreen}%s\n" " $line7  $dest7 <=> $src7" "  Out: $out7 | In: $in7"
          fi

          if [ "$line8" == "8" ]; then
            printf "${CWhite}%-82s${CGreen}%s\n" " $line8  $dest8 <=> $src8" "  Out: $out8 | In: $in8"
          fi

          if [ "$line9" == "9" ]; then
            printf "${CWhite}%-82s${CGreen}%s\n" " $line9  $dest9 <=> $src9" "  Out: $out9 | In: $in9"
          fi

          if [ "$line10" == "10" ]; then
            printf "${CWhite}%-82s${CGreen}%s\n" "$line10  $dest10 <=> $src10" "  Out: $out10 | In: $in10"
          fi

          echo ""
        fi
      done
    fi
  fi

}

# -------------------------------------------------------------------------------------------------------------------------
##------------------------------------------##
## Modified by ExtremeFiretop [2024-Aug-06] ##
##------------------------------------------##
# This function displays the stats UI for page 3
DisplayPage7()
{
  clear
  if [ "$UpdateNotify" != "0" ]; then
    echo -e "$UpdateNotify${CClear}"
  fi
  showheader
  # Create a temp arp table of connected wifi/lan clients
  cat /proc/net/arp > /jffs/addons/rtrmon.d/temparp.txt

  # Force create the processed clients list file
  touch /jffs/addons/rtrmon.d/processed_clients.txt
  # Force create the processed clients list file for VLAN
  touch /jffs/addons/rtrmon.d/processed_vlanclients.txt

  # Per @Stephen Harrington's sugguestion, check NVRAM to see if Wifi is turned on, else mark them as disabled
  if [ "$FourBandCustom55624" == "True" ]; then
    if [ $($timeoutcmd$timeoutsec nvram get wl0_radio) -eq 0 ]; then
      MaxSpeed5GhzNow=0
    else
      MaxSpeed5GhzNow=$MaxSpeed5Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl1_radio) -eq 0 ]; then
      MaxSpeed52GhzNow=0
    else
      MaxSpeed52GhzNow=$MaxSpeed5Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl2_radio) -eq 0 ]; then
      MaxSpeed6GhzNow=0
    else
      MaxSpeed6GhzNow=$MaxSpeed6Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl3_radio) -eq 0 ]; then
      MaxSpeed24GhzNow=0
    else
      MaxSpeed24GhzNow=$MaxSpeed24Ghz
    fi
  elif [ "$FourBandCustom56624" == "True" ]; then
    if [ $($timeoutcmd$timeoutsec nvram get wl0_radio) -eq 0 ]; then
      MaxSpeed5GhzNow=0
    else
      MaxSpeed5GhzNow=$MaxSpeed5Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl1_radio) -eq 0 ]; then
      MaxSpeed6GhzNow=0
    else
      MaxSpeed6GhzNow=$MaxSpeed6Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl2_radio) -eq 0 ]; then
      MaxSpeed62GhzNow=0
    else
      MaxSpeed62GhzNow=$MaxSpeed6Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl3_radio) -eq 0 ]; then
      MaxSpeed24GhzNow=0
    else
      MaxSpeed24GhzNow=$MaxSpeed24Ghz
    fi
  elif [ "$ThreeBand2456" == "True" ]; then
    if [ $($timeoutcmd$timeoutsec nvram get wl0_radio) -eq 0 ]; then
      MaxSpeed24GhzNow=0
    else
      MaxSpeed24GhzNow=$MaxSpeed24Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl1_radio) -eq 0 ]; then
      MaxSpeed5GhzNow=0
    else
      MaxSpeed5GhzNow=$MaxSpeed5Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl2_radio) -eq 0 ]; then
      MaxSpeed6GhzNow=0
    else
      MaxSpeed6GhzNow=$MaxSpeed6Ghz
    fi
  elif [ "$ThreeBand2455" == "True" ]; then
    if [ $($timeoutcmd$timeoutsec nvram get wl0_radio) -eq 0 ]; then
      MaxSpeed24GhzNow=0
    else
      MaxSpeed24GhzNow=$MaxSpeed24Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl1_radio) -eq 0 ]; then
      MaxSpeed5GhzNow=0
    else
      MaxSpeed5GhzNow=$MaxSpeed5Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl2_radio) -eq 0 ]; then
      MaxSpeed52GhzNow=0
    else
      MaxSpeed52GhzNow=$MaxSpeed5Ghz
    fi
  else
    if [ $($timeoutcmd$timeoutsec nvram get wl0_radio) -eq 0 ]; then
      MaxSpeed24GhzNow=0
    else
      MaxSpeed24GhzNow=$MaxSpeed24Ghz
    fi
    if [ $($timeoutcmd$timeoutsec nvram get wl1_radio) -eq 0 ]; then
      MaxSpeed5GhzNow=0
    else
      MaxSpeed5GhzNow=$MaxSpeed5Ghz
    fi
  fi

  if [ "$SortbyOpt" = "Name" ]; then
     SortbyNum="1"
  elif [ "$SortbyOpt" = "IP" ]; then
     SortbyNum="2"
  elif [ "$SortbyOpt" = "MAC" ]; then
     SortbyNum="3"
  else
     SortbyNum="1"
  fi
  prevSortByOpt="$SortbyOpt"

  #Testing
  #MaxSpeed24GhzNow=0
  #w24updown="UP" #testing
  echo ""
  echo -e "${InvGreen} ${CClear}${InvDkGray}${CWhite} Attached Wireless + Wired Clients                                                                            ${CClear}"
  if [ "$SortbyOpt" = "Name" ]; then
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear}${CWhite} Sort By: ${InvDkGray}${CGreen} (!)${CWhite}Name ${CClear}${CWhite}  |  ${CGreen}(@)${CWhite}IP  |  ${CGreen}(#)${CWhite}MAC${CClear}"
  elif [ "$SortbyOpt" = "IP" ]; then
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear}${CWhite} Sort By: ${CGreen} (!)${CWhite}Name  | ${InvDkGray} ${CGreen}(@)${CWhite}IP ${CClear}${CWhite} |  ${CGreen}(#)${CWhite}MAC${CClear}"
  elif [ "$SortbyOpt" = "MAC" ]; then
    echo -e "${InvGreen} ${CClear}"
    echo -e "${InvGreen} ${CClear}${CWhite} Sort By: ${CGreen} (!)${CWhite}Name  |  ${CGreen}(@)${CWhite}IP  | ${InvDkGray} ${CGreen}(#)${CWhite}MAC ${CClear}"
  fi
  echo -e "${InvGreen} ${CClear}${CDkGray}--------------------------------------------------------------------------------------------------------------${CClear}"
  echo ""

  if [ "$MaxSpeed24GhzNow" != "0" ]; then
    if [ "$w24updown" == "UP" ]; then
      echo -e "${InvGreen} ${CClear}${InvDkGray} ${CWhite}Local 2.4GHz               ${CDkGray}[ ${CWhite}Enabled                                                        ${CDkGray}] ${InvDkGray}${CWhite}IFace: $ifname24    ${CClear}"
    else
      echo -e "${InvGreen} ${CClear}${InvDkGray} ${CWhite}Local 2.4GHz               ${CDkGray}[ ${CWhite}Enabled                                                        ${CDkGray}] ${InvDkGray}${CWhite}IFace: $ifname24    ${CClear}"
    fi
    attachedwificlients "$ifname24"
    echo ""
  else
    echo -e "${InvRed} ${CClear}${InvDkGray} ${CWhite}Local 2.4GHz              ${CDkGray}[ ${CRed} Disabled                                                                       ${CDkGray}]${CClear}"
    echo ""
  fi
  #Testing
  #MaxSpeed5GhzNow=0 #testing
  #w5updown="UP" #testing
  if [ "$MaxSpeed5GhzNow" != "0" ]; then
    if [ "$w5updown" == "UP" ]; then
      echo -e "${InvGreen} ${CClear}${InvDkGray} ${CWhite}Local 5.0GHz               ${CDkGray}[ ${CWhite}Enabled                                                        ${CDkGray}] ${InvDkGray}${CWhite}IFace: $ifname5    ${CClear}"
    else
      echo -e "${InvGreen} ${CClear}${InvDkGray} ${CWhite}Local 5.0GHz               ${CDkGray}[ ${CWhite}Enabled                                                        ${CDkGray}] ${InvDkGray}${CWhite}IFace: $ifname5    ${CClear}"
    fi
    attachedwificlients "$ifname5"
    echo ""
  else
    echo -e "${InvRed} ${CClear}${InvDkGray} ${CWhite}Local 5.0GHz              ${CDkGray}[ ${CRed} Disabled                                                                       ${CDkGray}]${CClear}"
    echo ""
  fi
  #Testing
  #FourBandCustom55624="True" #testing
  #MaxSpeed52GhzNow=0 #testing
  #w52updown="UP" #testing
  if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2455" == "True" ]; then
    if [ "$MaxSpeed52GhzNow" != "0" ]; then
      if [ "$w52updown" == "UP" ]; then
        echo -e "${InvGreen} ${CClear}${InvDkGray} ${CWhite}Local 5.0GHz (2)           ${CDkGray}[ ${CWhite}Enabled                                                        ${CDkGray}] ${InvDkGray}${CWhite}IFace: $ifname52    ${CClear}"
      else
        echo -e "${InvGreen} ${CClear}${InvDkGray} ${CWhite}Local 5.0GHz (2)           ${CDkGray}[ ${CWhite}Enabled                                                        ${CDkGray}] ${InvDkGray}${CWhite}IFace: $ifname52    ${CClear}"
      fi
      attachedwificlients "$ifname52"
      #attachedwificlients "$ifname5" #testing
      echo ""
    else
      echo -e "${InvRed} ${CClear}${InvDkGray} ${CWhite}Local 5.0GHz (2)          ${CDkGray}[ ${CRed} Disabled                                                                       ${CDkGray}]${CClear}"
      echo ""
    fi
  fi
  #Testing
  #ThreeBand2456="True" #testing
  #MaxSpeed6GhzNow=1 #testing
  #w6updown="UP" #testing
  if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2456" == "True" ] || [ "$FourBandCustom56624" == "True" ]; then
    if [ "$MaxSpeed6GhzNow" != "0" ]; then
      if [ "$w6updown" == "UP" ]; then
        echo -e "${InvGreen} ${CClear}${InvDkGray} ${CWhite}Local 6.0GHz               ${CDkGray}[ ${CWhite}Enabled                                                        ${CDkGray}] ${InvDkGray}${CWhite}IFace: $ifname6    ${CClear}"
      else
        echo -e "${InvGreen} ${CClear}${InvDkGray} ${CWhite}Local 6.0GHz               ${CDkGray}[ ${CWhite}Enabled                                                        ${CDkGray}] ${InvDkGray}${CWhite}IFace: $ifname6    ${CClear}"
      fi
      attachedwificlients "$ifname6"
      #attachedwificlients "$ifname5" #testing
      echo ""
    else
      echo -e "${InvRed} ${CClear}${InvDkGray} ${CWhite}Local 6.0GHz              ${CDkGray}[ ${CRed} Disabled                                                                       ${CDkGray}]${CClear}"
      echo ""
    fi
  fi
  #Testing
  #FourBandCustom56624="True" #testing
  #MaxSpeed62GhzNow=0 #testing
  #w62updown="UP" #testing
  if [ "$FourBandCustom56624" == "True" ]; then
    if [ "$MaxSpeed62GhzNow" != "0" ]; then
      if [ "$w62updown" == "UP" ]; then
        echo -e "${InvGreen} ${CClear}${InvDkGray} ${CWhite}Local 6.0GHz (2)           ${CDkGray}[ ${CWhite}Enabled                                                        ${CDkGray}] ${InvDkGray}${CWhite}IFace: $ifname62    ${CClear}"
      else
        echo -e "${InvGreen} ${CClear}${InvDkGray} ${CWhite}Local 6.0GHz (2)           ${CDkGray}[ ${CWhite}Enabled                                                        ${CDkGray}] ${InvDkGray}${CWhite}IFace: $ifname62    ${CClear}"
      fi
      attachedwificlients "$ifname62"
      #attachedwificlients "$ifname5" #testing
      echo ""
    else
      echo -e "${InvRed} ${CClear}${InvDkGray} ${CWhite}Local 6.0GHz (2)          ${CDkGray}[ ${CRed} Disabled                                                                       ${CDkGray}]${CClear}"
      echo ""
    fi
  fi

  # Guest Network Clients - Thanks to @ColinTaylor for this methodology of stepping through legit guest network interfaces
  cp -f /jffs/addons/rtrmon.d/temparp.txt /jffs/addons/rtrmon.d/temparpvlan.txt
  for guestiface in $(nvram get wl0_vifs) $(nvram get wl1_vifs) $(nvram get wl2_vifs) $(nvram get wl3_vifs)
    do
      echo -e "${InvGreen} ${CClear}${InvDkGray} ${CWhite}Local Guest Wi-Fi          ${CDkGray}[ ${CWhite}Enabled                                                        ${CDkGray}] ${InvDkGray}${CWhite}IFace: $guestiface  ${CClear}"
      attachedguestclients "$guestiface"
      echo ""
    done

  for vlanlabels in $(nvram get apg_ifnames)
    do
      echo -e "${InvGreen} ${CClear}${InvDkGray} ${CWhite}Local VLAN/AiMesh VLAN     ${CDkGray}[ ${CWhite}Enabled                                                        ${CDkGray}] ${InvDkGray}${CWhite}IFace: $vlanlabels   ${CClear}"
      attachedvlanclients "$vlanlabels"
      echo ""
    done

  echo -e "${InvGreen} ${CClear}${InvDkGray} ${CWhite}Local LAN/Non-VLAN AiMesh  ${CDkGray}[ ${CWhite}Enabled                                                        ${CDkGray}] ${InvDkGray}${CWhite}IFace: br0     ${CClear}"
  #Remove non-LAN records
  sed -i -e '/eth0/d' /jffs/addons/rtrmon.d/temparp.txt
  sed -i -e '/IP address/d' /jffs/addons/rtrmon.d/temparp.txt
  sed -i -e '/00:00:00:00:00:00/d' /jffs/addons/rtrmon.d/temparp.txt
  sed -i -e '/0x0/d' /jffs/addons/rtrmon.d/temparp.txt
  attachedlanclients
  rm -f /jffs/addons/rtrmon.d/processed_clients.txt
  rm -f /jffs/addons/rtrmon.d/processed_vlanclients.txt
  rm -f /jffs/addons/rtrmon.d/temparp.txt

  #Testing
  #FourBandCustom55624="False" #testing
  #MaxSpeed52GhzNow=0 #testing
  #w52updown="UP" #testing
  #ThreeBand2456="False" #testing
  #MaxSpeed6GhzNow=0 #testing
  #w6updown="UP" #testing
  #FourBandCustom56624="False" #testing
  #MaxSpeed62GhzNow=0 #testing
  #w62updown="UP" #testing
}

# -------------------------------------------------------------------------------------------------------------------------
# multiple DHCP lists can exist. Read through all lists and compile into a single list.

read_all_dhcp_leases() {
  # Include the merged lease file if it exists
  local lease_files="/var/lib/misc/dnsmasq-*.leases /var/lib/misc/dnsmasq.leases"
  if [ -f "/tmp/dnsmasq-merged.leases" ]; then
    lease_files="$lease_files /tmp/dnsmasq-merged.leases"
  fi
  local all_leases
  all_leases=$(cat $lease_files 2>/dev/null)
  echo "$all_leases"
}

# Unified MLD MAC retrieval logic: given the current dhcpleases and association MAC (in lowercase),
# determine the lookup MAC (which may be the MLD MAC if present).
get_lookup_mac() {
  local maclower="$1"
  local leases="$2"
  local lookup_mac="$maclower"
  local mld_line field_count mld_mac
  mld_line=$(echo "$leases" | grep -i "$maclower" | head -n1)
  if [ -n "$mld_line" ]; then
    field_count=$(echo "$mld_line" | awk '{print NF; exit}')
    if [ "$field_count" -ge 5 ]; then
      mld_mac=$(echo "$mld_line" | awk '{print $5; exit}')
      if [ -n "$mld_mac" ] && [ "$mld_mac" != "*" ]; then
        lookup_mac=$(echo "$mld_mac" | awk '{print tolower($0)}')
      fi
    fi
  fi
  echo "$lookup_mac"
}

# attachedwificlients pulls connected client info from wl, arp and nvram
attachedwificlients ()
{
    iface="$1"
    rm -f /jffs/addons/rtrmon.d/wificlients$iface.txt
    wl -i $iface assoclist > /jffs/addons/rtrmon.d/wificlients$iface.txt
    maxclientcount=$(cat /jffs/addons/rtrmon.d/wificlients$iface.txt | wc -l)
    rm -f /jffs/addons/rtrmon.d/clientlist$iface.txt
    dhcpleases="$(read_all_dhcp_leases)"
    local clients=$(nvram get custom_clientlist)
    local maxextractcount=$(echo "$clients" | awk -F'>>' '{count=0; for (i=1; i<=NF; i++) if ($i != "") count++; print count}')

    local clientcount=0
    while [ $clientcount -le $maxclientcount ]
    do
        clientname=""
        conntime=""
        clientip=""
        paddedclientip=""
        clientcount=$((clientcount+1))
        local clientmac=$(awk 'NR=='$clientcount' {print $2}' /jffs/addons/rtrmon.d/wificlients$iface.txt)

        if [ -z "$clientmac" ]; then
            continue
        fi

        networktime=$(wl -i $iface sta_info $clientmac | awk -F ' ' '/in network/ {print $3}') 2>/dev/null
        conntime=$(date -d@$networktime -u +%Hh:%Mm) 2>/dev/null
        txtotalbytes=$(wl -i $iface sta_info $clientmac | awk -F ' ' '/tx total bytes:/ {print $4}') 2>/dev/null
        rxtotalbytes=$(wl -i $iface sta_info $clientmac | awk -F ' ' '/rx data bytes:/ {print $4}') 2>/dev/null
        txratekbps=$(wl -i $iface sta_info $clientmac | awk -F ' ' '/rate of last tx pkt:/ {print $6}') 2>/dev/null
        rxratekbps=$(wl -i $iface sta_info $clientmac | awk -F ' ' '/rate of last rx pkt:/ {print $6}') 2>/dev/null
        sigstrength=$(wl -i $iface sta_info $clientmac | awk -F ' ' '/smoothed rssi:/ {print $3}') 2>/dev/null
        maclower=$(echo "$clientmac" | awk '{print tolower($0)}') 2>/dev/null

        # --- Unified MLD MAC retrieval logic ---
        lookup_mac=$(get_lookup_mac "$maclower" "$dhcpleases")

        # Find IPs for the given MAC address in the ARP table
        ips=$(grep "$maclower" "/jffs/addons/rtrmon.d/temparp.txt" | awk '{print $1}') 2>/dev/null

        # Iterate over the IPs to find the reachable one
        for ip in $ips; do
            # Check the status of the IP in the neighbor table
            arp_status=$(ip neigh show | grep -w "$ip" | awk '{print $NF}') 2>/dev/null

            # Check if the current IP is reachable
            if [ -z "$arp_status" ] || { [ "$arp_status" != "REACHABLE" ] && [ "$arp_status" != "DELAY" ]; }; then
                if [ -z "$sigstrength" ]; then
                    conntime="STALE"
                fi
                continue
            else
                # Set the clientip to the current IP if it is reachable or delay
                clientip="$ip"
                break
            fi
        done

        # Fallback to using the ARP table if no reachable IP was found
        if [ -z "$clientip" ]; then
            clientip=$(cat /proc/net/arp | grep "$maclower" | awk '{print $1}' | sort | uniq | tail -n 1) 2>/dev/null
        fi

        paddedclientip=$(echo "${clientip}" | grep -o -E '([0-9]*\.|[0-9]*)' | awk '{printf( "%03d\n", $1)}' | tr '\n' '.' | sed 's/.$//') 2>/dev/null

        #calcs
        txtotalgb=$(echo $txtotalbytes | awk -v txb=$txtotalbytes 'BEGIN{printf "%0.2f\n", txb/1024/1024/1024}') 2>/dev/null
        rxtotalgb=$(echo $rxtotalbytes | awk -v rxb=$rxtotalbytes 'BEGIN{printf "%0.2f\n", rxb/1024/1024/1024}') 2>/dev/null
        txratembps=$(echo $txratekbps | awk -v txm=$txratekbps 'BEGIN{printf "%0.1f\n", txm/1000}') 2>/dev/null
        rxratembps=$(echo $rxratekbps | awk -v rxm=$rxratekbps 'BEGIN{printf "%0.1f\n", rxm/1000}') 2>/dev/null

        local found=0
        local counter=0
        while [ $counter -le $maxextractcount ]
        do
            counter=$((counter+1))
            local clientextract="$(echo $clients | cut -d "<" -f$counter | cut -d ">" -f1,2)"

            if [ -z "$clientextract" ]; then
                break
            fi

            local client="$(echo $clientextract | awk -F ">" '{print $1}')"
            local mac="$(echo $clientextract | awk -F ">" '{print $2}')"

            if [ "$mac" == "$clientmac" ]; then
                clientname=$client
                found=1
                break
            fi
        done
        # Fallback to using dnsmasq.leases if no match found
        if [ $found -ne 1 ]; then
            clientname=$(echo "$dhcpleases" | grep -i "$lookup_mac" | awk '{print $4}') 2>/dev/null
            if [ -z "$clientname" ] || [ "$clientname" == "*" ]; then
                clientname="UNKNOWN"
            fi
        fi
        if [ -n "$paddedclientip" ] && [ "$paddedclientip" != "000.000.000.000" ]; then
            # Add the check for already processed clients
            if grep -qi "$clientmac" /jffs/addons/rtrmon.d/processed_clients.txt; then
                # Skip processing if the device was already handled
                continue
            else
                echo "$clientmac" >> /jffs/addons/rtrmon.d/processed_clients.txt
            fi
            #delete entry from temparp table
            sed -i -e '/'$maclower'/d' /jffs/addons/rtrmon.d/temparp.txt
            echo "$clientname,$paddedclientip,$clientmac,$conntime,$txtotalgb,$rxtotalgb,$txratembps,$rxratembps,$sigstrength" >> /jffs/addons/rtrmon.d/clientlist$iface.txt
        fi
    done

    if [ -f "/jffs/addons/rtrmon.d/clientlist$iface.txt" ]; then
      if [ $maxclientcount -ge 1 ]; then
          sort -f -d -o /jffs/addons/rtrmon.d/clientlist$iface.txt -k "$SortbyNum" -t , /jffs/addons/rtrmon.d/clientlist$iface.txt 2>/dev/null
          column -t -s',' -o' | ' -N Name,IP,MAC,Uptime,"TX GB","RX GB","TX Mbps","RX Mbps","Sig" /jffs/addons/rtrmon.d/clientlist$iface.txt | sed 's/^/  /'
      else
          echo -e "  No Devices Connected"
      fi
    else
      echo -e "  No Devices Connected"
    fi
}

# -------------------------------------------------------------------------------------------------------------------------
# attachedguestclients pulls connected client info from wl, arp and nvram
##------------------------------------------##
## Modified by ExtremeFiretop [2024-Aug-06] ##
##------------------------------------------##
attachedguestclients() {
  iface="$1"
  rm -f /jffs/addons/rtrmon.d/wificlients$iface.txt
  wl -i $iface assoclist > /jffs/addons/rtrmon.d/wificlients$iface.txt
  maxclientcount=$(cat /jffs/addons/rtrmon.d/wificlients$iface.txt | wc -l)
  rm -f /jffs/addons/rtrmon.d/clientlist$iface.txt
  dhcpleases="$(read_all_dhcp_leases)"
  local clients=$(nvram get custom_clientlist)
  local maxextractcount=$(echo "$clients" | awk -F'>>' '{count=0; for (i=1; i<=NF; i++) if ($i != "") count++; print count}')

  local clientcount=0
  while [ $clientcount -le $maxclientcount ]
  do
    clientname=""
    conntime=""
    clientip=""
    paddedclientip=""
    clientcount=$((clientcount+1))
    local clientmac=$(awk 'NR=='$clientcount' {print $2}' /jffs/addons/rtrmon.d/wificlients$iface.txt)

    if [ -z "$clientmac" ]; then
      continue
    fi

    networktime=$(wl -i $iface sta_info $clientmac | awk -F ' ' '/in network/ {print $3}') 2>/dev/null
    conntime=$(date -d@$networktime -u +%Hh:%Mm) 2>/dev/null
    txtotalbytes=$(wl -i $iface sta_info $clientmac | awk -F ' ' '/tx total bytes:/ {print $4}') 2>/dev/null
    rxtotalbytes=$(wl -i $iface sta_info $clientmac | awk -F ' ' '/rx data bytes:/ {print $4}') 2>/dev/null
    txratekbps=$(wl -i $iface sta_info $clientmac | awk -F ' ' '/rate of last tx pkt:/ {print $6}') 2>/dev/null
    rxratekbps=$(wl -i $iface sta_info $clientmac | awk -F ' ' '/rate of last rx pkt:/ {print $6}') 2>/dev/null
    sigstrength=$(wl -i $iface sta_info $clientmac | awk -F ' ' '/smoothed rssi:/ {print $3}') 2>/dev/null
    maclower=$(echo "$clientmac" | awk '{print tolower($0)}') 2>/dev/null
    # --- Unified MLD MAC retrieval logic ---
    lookup_mac=$(get_lookup_mac "$maclower" "$dhcpleases")

    # Find IPs for the given MAC address in the ARP table
    ips=$(grep "$maclower" "/jffs/addons/rtrmon.d/temparp.txt" | awk '{print $1}') 2>/dev/null

    # Iterate over the IPs to find the reachable one
    for ip in $ips; do
        # Check the status of the IP in the neighbor table
        arp_status=$(ip neigh show | grep -w "$ip" | awk '{print $NF}') 2>/dev/null

        # Check if the current IP is reachable
        if [ -z "$arp_status" ] || { [ "$arp_status" != "REACHABLE" ] && [ "$arp_status" != "DELAY" ]; }; then
            if [ -z "$sigstrength" ]; then
                conntime="STALE"
            fi
            continue
        else
            # Set the clientip to the current IP if it is reachable or delay
            clientip="$ip"
            break
        fi
    done

    # Fallback to using the ARP table or DHCP leases if no reachable IP was found
    if [ -z "$clientip" ]; then
        # Try to get the last IP from the ARP table
        clientip=$(cat /proc/net/arp | grep "$maclower" | awk '{print $1}' | sort | uniq | tail -n 1) 2>/dev/null
    fi

    paddedclientip=$(echo "${clientip}" | grep -o -E '([0-9]*\.|[0-9]*)' | awk '{printf( "%03d\n", $1)}' | tr '\n' '.' | sed 's/.$//') 2>/dev/null

    #calcs
    txtotalgb=$(echo $txtotalbytes | awk '{printf "%0.2f", $1/1024/1024/1024}') 2>/dev/null
    rxtotalgb=$(echo $rxtotalbytes | awk '{printf "%0.2f", $1/1024/1024/1024}') 2>/dev/null
    txratembps=$(echo $txratekbps | awk '{printf "%0.1f", $1/1000}') 2>/dev/null
    rxratembps=$(echo $rxratekbps | awk '{printf "%0.1f", $1/1000}') 2>/dev/null

    local found=0
    local counter=0
    while [ $counter -le $maxextractcount ]
    do
        counter=$((counter+1))
        local clientextract="$(echo $clients | cut -d "<" -f$counter | cut -d ">" -f1,2)"

        if [ -z "$clientextract" ]; then
            break
        fi

        local client=$(echo $clientextract | awk -F ">" '{print $1}')
        local mac=$(echo $clientextract | awk -F ">" '{print $2}')

        if [ "$mac" == "$clientmac" ]; then
            clientname=$client
            found=1
            break
        fi
    done
    # Fallback to using dnsmasq.leases if no match found
    if [ $found -ne 1 ]; then
        clientname=$(echo "$dhcpleases" | grep -i "$lookup_mac" | awk '{print $4}') 2>/dev/null
        if [ -z "$clientname" ] || [ "$clientname" == "*" ]; then
            clientname="UNKNOWN"
        fi
    fi
    if [ -n "$paddedclientip" ] && [ "$paddedclientip" != "000.000.000.000" ]; then
        # Add the check for already processed clients
        if grep -qi "$clientmac" /jffs/addons/rtrmon.d/processed_clients.txt; then
            # Skip processing if the device was already handled
            continue
        else
            echo "$clientmac" >> /jffs/addons/rtrmon.d/processed_clients.txt
        fi
        #delete entry from temparp table
        sed -i -e '/'$maclower'/d' /jffs/addons/rtrmon.d/temparp.txt
        echo "$clientname,$paddedclientip,$clientmac,$conntime,$txtotalgb,$rxtotalgb,$txratembps,$rxratembps,$sigstrength" >> /jffs/addons/rtrmon.d/clientlist$iface.txt
    fi
  done

  if [ -f "/jffs/addons/rtrmon.d/clientlist$iface.txt" ]; then
    if [ $maxclientcount -ge 1 ]; then
      sort -f -d -o /jffs/addons/rtrmon.d/clientlist$iface.txt -k "$SortbyNum" -t , /jffs/addons/rtrmon.d/clientlist$iface.txt 2>/dev/null
      column -t -s',' -o' | ' -N Name,IP,MAC,Uptime,"TX GB","RX GB","TX Mbps","RX Mbps","Sig" /jffs/addons/rtrmon.d/clientlist$iface.txt | sed 's/^/  /'
    else
      echo -e "  No Devices Connected"
    fi
  else
    echo -e "  No Devices Connected"
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# attachedvlanclients pulls connected client info from wl, arp and nvram

attachedvlanclients() {
  iface="$1"
  vlansfound=1
  maxclientcount=$(cat /jffs/addons/rtrmon.d/temparpvlan.txt | wc -l)
  rm -f /jffs/addons/rtrmon.d/vlanclients$iface.txt
  dhcpleases="$(read_all_dhcp_leases)"
  local clients=$(nvram get custom_clientlist)
  local maxextractcount=$(echo "$clients" | awk -F'>>' '{count=0; for (i=1; i<=NF; i++) if ($i != "") count++; print count}')

  local clientcount=0
  while [ $clientcount -le $maxclientcount ]
  do
    clientname=""
    conntime=""
    clientip=""
    paddedclientip=""
    interface_name=""
    clientcount=$((clientcount+1))
    local clientmac=$(awk 'NR=='$clientcount' {print $4}' /jffs/addons/rtrmon.d/temparpvlan.txt | xargs)

    if [ -z "$clientmac" ]; then
      continue
    fi

    # Convert the MAC address to uppercase and store it in a new variable
    macupper=$(echo "$clientmac" | tr 'a-f' 'A-F')
    macprefix=$(echo "$macupper" | awk -F ':' '{print $1":"$2":"$3":"$4":"$5}') 2>/dev/null
    clientbridgeid=$(awk 'NR=='$clientcount' {print $6}' /jffs/addons/rtrmon.d/temparpvlan.txt | xargs)
    if [ -z "$clientbridgeid" ] || [ "$clientbridgeid" != "$iface" ]; then
      continue
    else
      vlansfound=0
    fi

    interfaces=$(ip link show | grep -E 'wl|wlan' | awk -F: '{print $2}' | tr -d ' ')
    for wirelessface in $interfaces; do
        # Suppress both standard output and error from the wl command and check for the MAC
        if wl -i "$wirelessface" assoclist 2>/dev/null | grep -iq "$macprefix"; then
            # Save the interface name into the variable
            interface_name="$wirelessface"
            continue
        fi
    done

    networktime=$(wl -i $interface_name sta_info $clientmac | awk -F ' ' '/in network/ {print $3}') 2>/dev/null
    # Set conntime to "OFFLINE" if networktime is empty
    if [ -z "$networktime" ]; then
        conntime="AiMesh"
    else
        conntime=$(date -d@$networktime -u +%Hh:%Mm) 2>/dev/null
    fi
    txtotalbytes=$(wl -i $interface_name sta_info $clientmac | awk -F ' ' '/tx total bytes:/ {print $4}') 2>/dev/null
    rxtotalbytes=$(wl -i $interface_name sta_info $clientmac | awk -F ' ' '/rx data bytes:/ {print $4}') 2>/dev/null
    txratekbps=$(wl -i $interface_name sta_info $clientmac | awk -F ' ' '/rate of last tx pkt:/ {print $6}') 2>/dev/null
    rxratekbps=$(wl -i $interface_name sta_info $clientmac | awk -F ' ' '/rate of last rx pkt:/ {print $6}') 2>/dev/null
    sigstrength=$(wl -i $interface_name sta_info $clientmac | awk -F ' ' '/smoothed rssi:/ {print $3}') 2>/dev/null

    # --- Unified MLD MAC lookup for VLAN clients ---
    maclower=$(echo "$clientmac" | awk '{print tolower($0)}') 2>/dev/null
    lookup_mac=$(get_lookup_mac "$maclower" "$dhcpleases")

    # Find IPs for the given MAC address in the ARP table
    ips=$(grep "$clientmac" "/jffs/addons/rtrmon.d/temparp.txt" | awk '{print $1}') 2>/dev/null

    # Iterate over the IPs to find the reachable one
    for ip in $ips; do
        # Check the status of the IP in the neighbor table
        arp_status=$(ip neigh show | grep -w "$ip" | awk '{print $NF}') 2>/dev/null

        # Check if the current IP is reachable
        if [ -z "$arp_status" ] || { [ "$arp_status" != "REACHABLE" ] && [ "$arp_status" != "DELAY" ]; }; then
            if [ -z "$sigstrength" ]; then
                conntime="STALE"
            fi
            continue
        else
            # Set the clientip to the current IP if it is reachable or delay
            clientip="$ip"
            break
        fi
    done

    # Fallback to using the ARP table if no reachable IP was found
    if [ -z "$clientip" ]; then
        clientip=$(cat /proc/net/arp | grep "$clientmac" | awk '{print $1}' | sort | uniq | tail -n 1) 2>/dev/null
    fi

    paddedclientip=$(echo "$clientip" | awk -F '.' '{printf "%03d.%03d.%03d.%03d\n", $1, $2, $3, $4}') 2>/dev/null

    #calcs
    txtotalgb=$(echo $txtotalbytes | awk '{printf "%0.2f", $1/1024/1024/1024}') 2>/dev/null
    rxtotalgb=$(echo $rxtotalbytes | awk '{printf "%0.2f", $1/1024/1024/1024}') 2>/dev/null
    txratembps=$(echo $txratekbps | awk '{printf "%0.1f", $1/1000}') 2>/dev/null
    rxratembps=$(echo $rxratekbps | awk '{printf "%0.1f", $1/1000}') 2>/dev/null

    local found=0
    local counter=0
    while [ $counter -le $maxextractcount ]
    do
      counter=$((counter+1))
      local clientextract="$(echo $clients | cut -d "<" -f$counter | cut -d ">" -f1,2)"

      if [ -z "$clientextract" ]; then
          break
      fi

      local client="$(echo $clientextract | awk -F ">" '{print $1}')"
      local mac="$(echo $clientextract | awk -F ">" '{print $2}')"

      if [ "$mac" == "$macupper" ]; then
        clientname=$client
        found=1
        break
      fi

    done
    # Fallback to using dnsmasq.leases if no match found
    if [ $found -ne 1 ]; then
        clientname=$(echo "$dhcpleases" | grep -i "$lookup_mac" | awk '{print $4}') 2>/dev/null
        if [ -z "$clientname" ] || [ "$clientname" == "*" ]; then
            clientname="UNKNOWN"
        fi
    fi
    if [ -n "$paddedclientip" ] && [ "$paddedclientip" != "000.000.000.000" ]; then
        # Check if this MAC address has already been processed
        if grep -q "$macupper" /jffs/addons/rtrmon.d/processed_vlanclients.txt && [ "$conntime" = "STALE" ]; then
            continue  # Skip processing this MAC address
        else
            # Mark this MAC as processed by adding it to the processed_macs_file
            echo "$macupper" >> /jffs/addons/rtrmon.d/processed_vlanclients.txt
        fi
        #delete entry from temparp table
        sed -i -e '/'$clientmac'/d' /jffs/addons/rtrmon.d/temparp.txt
        if [ "$conntime" = "AiMesh" ]; then
            echo "$clientname,$paddedclientip,$macupper,$conntime" >> /jffs/addons/rtrmon.d/vlanclients$iface.txt
        else
            echo "$clientname,$paddedclientip,$macupper,$conntime,$txtotalgb,$rxtotalgb,$txratembps,$rxratembps,$sigstrength" >> /jffs/addons/rtrmon.d/vlanclients$iface.txt
        fi
    fi
  done

  if [ -f "/jffs/addons/rtrmon.d/vlanclients$iface.txt" ]; then
    if [ $vlansfound -eq 0 ]; then
      sort -f -d -t ',' -k "$SortbyNum" -k 4,4 /jffs/addons/rtrmon.d/vlanclients$iface.txt 2>/dev/null | \
      awk -F',' -v OFS=',' '{if ($4 ~ /AiMesh/) {a[i++]=$0} else {print $0}} END {for (j=0; j<i; j++) print a[j]}' > /tmp/vlanclients_sorted.txt
      # Move sorted file back to original
      mv /tmp/vlanclients_sorted.txt /jffs/addons/rtrmon.d/vlanclients$iface.txt
      column -t -s',' -o' | ' -N Name,IP,MAC,Uptime,"TX GB","RX GB","TX Mbps","RX Mbps","Sig" /jffs/addons/rtrmon.d/vlanclients$iface.txt | sed 's/^/  /'
    else
      echo -e "  No Devices Connected"
    fi
  else
    echo -e "  No Devices Connected"
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# attachedlanclients pulls connected client info from wl, arp and nvram

attachedlanclients ()
{
  maxclientcount=$(cat /jffs/addons/rtrmon.d/temparp.txt | wc -l)
  rm -f /jffs/addons/rtrmon.d/clientlistbr0.txt
  dhcpleases="$(read_all_dhcp_leases)"
  #find matchine client name
  local clients=$(nvram get custom_clientlist)
  local maxextractcount=$(echo "$clients" | awk -F'>>' '{count=0; for (i=1; i<=NF; i++) if ($i != "") count++; print count}')

  local clientcount=0
  while [ $clientcount -le $maxclientcount ]
  do
      clientname=""
      paddedclientip=""
      clientcount=$((clientcount+1))
      local clientmac=$(cat /jffs/addons/rtrmon.d/temparp.txt | awk 'NR=='$clientcount' {print $4}') 2>/dev/null

      if [ -z "$clientmac" ]; then
          continue
      fi

      local macupper=$(echo "$clientmac" | tr 'a-f' 'A-F')

      # Add the check for already processed clients
      if grep -qi "$clients" /jffs/addons/rtrmon.d/processed_clients.txt; then
          # Skip processing if the device was already handled
          continue
      else
          echo "$macupper" >> /jffs/addons/rtrmon.d/processed_clients.txt
      fi

      local counter=0
      local found=0
      while [ $counter -le $maxextractcount ]
      do
          counter=$((counter+1))
          local clientextract="$(echo $clients | cut -d "<" -f$counter | cut -d ">" -f1,2)"

          if [ -z "$clientextract" ]; then
              continue
          fi

          #clientip=$(cat /proc/net/arp | grep $clientmac | awk '{print $1}')
          clientip=$(cat /jffs/addons/rtrmon.d/temparp.txt | grep $clientmac | awk '{print $1; exit}') 2>/dev/null
          paddedclientip=$(echo "${clientip}" | grep -o -E '([0-9]*\.|[0-9]*)' | awk '{printf( "%03d\n", $1)}' | tr '\n' '.' | sed 's/.$//') 2>/dev/null
          if [ -z $paddedclientip ]; then paddedclientip="000.000.000.000"; fi

          local client="$(echo $clientextract | awk -F ">" '{print $1}')"
          local mac="$(echo $clientextract | awk -F ">" '{print $2}')"

          if [ "$mac" == "$macupper" ]; then
              clientname=$client
              found=1
              break
          fi
      done
      # Fallback to using dnsmasq.leases if no match found
      if [ $found -ne 1 ]; then
            clientname=$(echo "$dhcpleases" | grep -i "$clientmac" | awk '{print $4}')
            if [ -z "$clientname" ] || [ "$clientname" == "*" ]; then
                clientname="UNKNOWN"
            fi
      fi
      if [ -n "$paddedclientip" ] && [ "$paddedclientip" != "000.000.000.000" ]; then
          echo "$clientname,$paddedclientip,$macupper" >> /jffs/addons/rtrmon.d/clientlistbr0.txt
      fi
  done

  if [ -f "/jffs/addons/rtrmon.d/clientlistbr0.txt" ]; then
    if [ $maxclientcount -ge 1 ]; then
      sort -f -d -o /jffs/addons/rtrmon.d/clientlistbr0.txt -k "$SortbyNum" -t , /jffs/addons/rtrmon.d/clientlistbr0.txt 2>/dev/null
      column -t -s',' -o' | ' -N Name,IP,MAC /jffs/addons/rtrmon.d/clientlistbr0.txt | sed 's/^/  /'
    else
      echo -e "  No Devices Connected"
    fi
  else
    echo -e "  No Devices Connected"
  fi
}

# -------------------------------------------------------------------------------------------------------------------------
# VPN_GetClientState was created by @Martinski in many thanks to trying to eliminate unknown operand errors due to null
# vpn_clientX_state values

_VPN_GetClientState_()
{
    if [ $# -lt 1 ] || [ -z "$1" ] || ! echo "$1" | grep -qE "^[1-5]$"
    then echo "**ERROR**" ; return 1 ; fi

    local nvramVal="$($timeoutcmd$timeoutsec nvram get "vpn_client${1}_state")"
    if [ -z "$nvramVal" ] || ! echo "$nvramVal" | grep -qE "^[0-9]$"
    then echo "0" ; else echo "$nvramVal" ; fi
    return 0
}

# -------------------------------------------------------------------------------------------------------------------------
# WG_GetClientState is based off _VPN_GetClientState_

_WG_GetClientState_()
{
    if [ $# -lt 1 ] || [ -z "$1" ] || ! echo "$1" | grep -qE "^[1-5]$"
    then echo "**ERROR**" ; return 1 ; fi

    # Inspiration from ZebMcKayHan's WGC Watchdog Script
    last_handshake=$(wg show wgc$1 latest-handshakes | awk '{print $2}') >/dev/null 2>&1

    if [ -z $last_handshake ]
      then
        WGnvramVal=0 #disconnected
      else
        WGnvramVal=2 #connected
    fi

    #local WGnvramVal="$($timeoutcmd$timeoutsec nvram get "wgc${1}_enable")"
    if [ -z "$WGnvramVal" ] || ! echo "$WGnvramVal" | grep -qE "^[+-]?[0-9]$"
    then echo "0" ; else echo "$WGnvramVal" ; fi
    return 0
}

##-------------------------------------##
## Added by Martinski W. [2024-Nov-02] ##
##-------------------------------------##
_SetUpTimeoutCmdVars_()
{
   # If the timeout utility is available then use it #
   if [ -z "${timeoutcmd:+xSETx}" ] && [ -f "/opt/bin/timeout" ]
   then
       timeoutcmd="timeout "
       timeoutsec="10"
       timeoutlng="60"
   fi
}

##-------------------------------------##
## Added by Martinski W. [2024-Nov-02] ##
##-------------------------------------##
_SetLAN_HostName_()
{
   [ -z "${LAN_HostName:+xSETx}" ] && \
   LAN_HostName="$($timeoutcmd$timeoutsec nvram get lan_hostname)"
}

_GetLAN_HostName_()
{ _SetLAN_HostName_ ; echo "$LAN_HostName" ; }

trap '_IgnoreKeypresses_ OFF ; exit 0' EXIT INT QUIT ABRT TERM

# -------------------------------------------------------------------------------------------------------------------------
# Begin Commandline Argument Gatekeeper and Configuration Utility Functionality
# -------------------------------------------------------------------------------------------------------------------------
##----------------------------------------##
## Modified by Martinski W. [2024-Nov-02] ##
##----------------------------------------##

#DEBUG=; set -x # uncomment/comment to enable/disable debug mode
#{              # uncomment/comment to enable/disable debug mode

  _SetUpTimeoutCmdVars_
  _SetLAN_HostName_

  # Create the necessary folder/file structure for RTRMON under /jffs/addons
  if [ ! -d "/jffs/addons/rtrmon.d" ]; then
     mkdir -p "/jffs/addons/rtrmon.d"
  fi

  # Check for Updates
  updatecheck

  RouterModel="$($timeoutcmd$timeoutsec nvram get odmpid)"
  [ -z "$RouterModel" ] && RouterModel="$($timeoutcmd$timeoutsec nvram get productid)"

  FWVER="$($timeoutcmd$timeoutsec nvram get firmver | tr -d '.')"
  BUILDNO="$($timeoutcmd$timeoutsec nvram get buildno)"
  EXTENDNO="$($timeoutcmd$timeoutsec nvram get extendno)"
  if [ -z "$EXTENDNO" ]; then EXTENDNO=0; fi
  FWBUILD="${FWVER}.${BUILDNO}_${EXTENDNO}"

  # Check for advanced router Features
  FourBandCustom55624="False"
  FourBandCustom56624="False"
  ThreeBand2456="False"
  ThreeBand2455="False"

  if [ "$RouterModel" = "GT-AXE16000" ] || [ "$RouterModel" = "GT-BE98" ]; then
     FourBandCustom55624="True"
  fi
  if [ "$RouterModel" = "GT-BE98_Pro" ]; then
     FourBandCustom56624="True"
  fi
  if [ "$RouterModel" = "GT-AXE11000" ] || [ "$RouterModel" = "ZenWiFi_ET8" ] || [ "$RouterModel" = "RT-BE96U" ]; then
     ThreeBand2456="True"
  fi
  if [ "$RouterModel" = "GT-AX11000_Pro" ] || [ "$RouterModel" = "GT-AX11000" ] || [ "$RouterModel" = "ZenWiFi_Pro_XT12" ] || [ "$RouterModel" = "ZenWiFi_XT8" ]; then
     ThreeBand2455="True"
  fi

  # Check what mode the router is in: 1=Router, 2=AP, 3=iMesh Node #
  OpsMode="$($timeoutcmd$timeoutsec nvram get sw_mode)"
  #OpsMode=3

  # Check and see if any commandline option is being used
  if [ $# -eq 0 ] || [ -z "$1" ]
  then
      clear
      echo ""
      echo "RTRMON v$Version"
      echo ""
      echo "Exiting due to missing commandline options!"
      echo "(run 'rtrmon.sh -h' for help)"
      echo ""
      echo -e "${CClear}"
      exit 0
  fi

  # Check and see if an invalid commandline option is being used
  if [ "$1" = "-h" ] || [ "$1" = "-help" ] || [ "$1" = "-config" ] || [ "$1" = "-setup" ] || \
     [ "$1" = "-monitor" ] || [ "$1" = "-reset" ] || [ "$1" = "-update" ] || \
     [ "$1" = "-screen" ] || [ "$1" = "-uninstall" ] || [ "$1" = "-log" ] || \
     { [ $# -gt 1 ] && [ "$2" = "-now" ] ; } || { [ $# -gt 2 ] &&[ "$3" = "-now" ] ; }
  then
      clear
  else
      clear
      echo ""
      echo "RTRMON v$Version"
      echo ""
      echo "Exiting due to invalid commandline options!"
      echo "(run 'rtrmon.sh -h' for help)"
      echo ""
      echo -e "${CClear}"
      exit 0
  fi

  # Check to see if the help option is being called
  if [ "$1" == "-h" ] || [ "$1" == "-help" ]
  then
    clear
    echo ""
    echo "RTRMON v$Version Commandline Option Usage:"
    echo ""
    echo "rtrmon.sh -h | -help"
    echo "rtrmon.sh -log"
    echo "rtrmon.sh -config"
    echo "rtrmon.sh -update"
    echo "rtrmon.sh -setup"
    echo "rtrmon.sh -uninstall"
    echo "rtrmon.sh -screen"
    echo "rtrmon.sh -monitor"
    echo "rtrmon.sh -screen/-monitor X"
    echo "rtrmon.sh -screen (X) -now"
    echo ""
    echo " -h | -help (this output)"
    echo " -log (display the current log contents)"
    echo " -config (configuration utility)"
    echo " -update (script update utility)"
    echo " -setup (setup/dependencies utility)"
    echo " -uninstall (uninstall utility)"
    echo " -screen (normal router monitoring using the screen utility)"
    echo " -monitor (normal router monitoring operations)"
    echo " -screen/-monitor X (X = display screen 1-6 upon execution)"
    echo " -screen -now (bypass screen instructions and 5 sec timer)"
    echo ""
    echo " Examples:"
    echo " rtrmon -screen -now (bypass screen timer directly into monitor mode)"
    echo " rtrmon -screen 2 (jump to page 2 upon execution using screen)"
    echo " rtrmon -screen 3 -now (bypass timer and jump to page 3 using screen)"
    echo " rtrmon -monitor 4 (jump to page 4 in monitoring mode)"
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

  # Check to see if the configuration option is being called, and run through setup utility
  if [ "$1" == "-config" ]
  then
      vconfig
      echo -e "${CClear}"
      exit 0
  fi

  # Check to see if the update option is being called
  if [ "$1" == "-update" ]
  then
      vupdate
      echo -e "${CClear}"
      exit 0
  fi

  # Check to see if the install option is being called
  if [ "$1" = "-setup" ]
  then
      vsetup
      exit 0
  fi

  # Check to see if the uninstall option is being called
  if [ "$1" = "-uninstall" ]
  then
      vuninstall
      echo -e "${CClear}"
      exit 0
  fi

  # Check to see if the -now parameter is being called to bypass the screen timer
  if [ $# -gt 1 ] && [ "$2" = "-now" ]
  then
      bypassScreenTimer=1
  elif [ $# -gt 2 ] && [ "$3" = "-now" ]
  then
      bypassScreenTimer2=1
  fi

  # Check to see if the screen option is being called and run operations normally using the screen utility
  if [ "$1" = "-screen" ]
  then
      screen -wipe >/dev/null 2>&1 # Kill any dead screen sessions
      sleep 1
      ScreenSess="$(screen -ls | grep "rtrmon" | awk '{print $1}' | cut -d . -f 1)"
      if [ -z "$ScreenSess" ]
      then
        if [ "$bypassScreenTimer" = "1" ]
        then
          screen -dmS "rtrmon" $APPPATH -monitor
          sleep 1
          screen -r rtrmon
        elif [ "$bypassScreenTimer2" = "1" ]
        then
          if [ $# -lt 2 ] || [ -z "$2" ]; then
            screen -dmS "rtrmon" $APPPATH -monitor
          elif [ "$2" -ge 1 ] && [ "$2" -le 6 ]; then
            screen -dmS "rtrmon" $APPPATH -monitor $2
          else
            screen -dmS "rtrmon" $APPPATH -monitor
          fi
          sleep 1
          screen -r rtrmon
        else
          clear
          echo -e "${CClear}Executing ${CGreen}RTRMON v$Version ${CClear}using the SCREEN utility...${CClear}"
          echo ""
          echo -e "${CClear}IMPORTANT:${CClear}"
          echo -e "${CClear}In order to keep RTRMON running in the background,${CClear}"
          echo -e "${CClear}properly exit the SCREEN session by using: ${CGreen}CTRL-A + D${CClear}"
          echo ""
          if [ $# -lt 2 ] || [ -z "$2" ]; then
            screen -dmS "rtrmon" $APPPATH -monitor
          elif [ "$2" -ge 1 ] && [ "$2" -le 6 ]; then
            screen -dmS "rtrmon" $APPPATH -monitor $2
          else
            screen -dmS "rtrmon" $APPPATH -monitor
          fi
          sleep 2
          echo -e "${CClear}Switching to the SCREEN session in T-5 sec...${CClear}"
          echo -e "${CClear}"
          spinner 5
          screen -r rtrmon
          exit 0
        fi
      else
        if [ "$bypassScreenTimer" = "1" ]; then
          sleep 1
        else
          clear
          echo -e "${CClear}Connecting to existing ${CGreen}RTRMON v$Version ${CClear}SCREEN session...${CClear}"
          echo ""
          echo -e "${CClear}IMPORTANT:${CClear}"
          echo -e "${CClear}In order to keep RTRMON running in the background,${CClear}"
          echo -e "${CClear}properly exit the SCREEN session by using: ${CGreen}CTRL-A + D${CClear}"
          echo ""
          echo -e "${CClear}Switching to the SCREEN session in T-5 sec...${CClear}"
          echo -e "${CClear}"
          spinner 5
        fi
      fi
      screen -dr $ScreenSess
      exit 0
  fi

  # Check to see if the monitor option is being called and run operations normally
  if [ "$1" = "-monitor" ]
  then
      clear
      if [ -f "$CFGPATH" ] && [ -f "/opt/bin/column" ] && [ -f "/opt/bin/timeout" ] && [ -f "/opt/sbin/screen" ] && [ -f "/opt/bin/nmap" ] && [ -f "/opt/bin/jq" ] && [ -f "/opt/bin/iftop" ]
      then
          printf "\r\033[0K${InvYellow} ${CClear} Please wait..." ; _ConsumeKeypressBuffer_
          source "$CFGPATH"

          if [ -f /root/.config/ookla/speedtest-cli.json ] && \
             [ ! -f /jffs/addons/rtrmon.d/speedtest-cli.json ]
          then
              cp -fp /root/.config/ookla/speedtest-cli.json /jffs/addons/rtrmon.d/speedtest-cli.json 2>/dev/null
          fi

          if [ ! -d "/root/.config/ookla" ]
          then
              mkdir -p "/root/.config/ookla"
              [ -f /jffs/addons/rtrmon.d/speedtest-cli.json ] && \
              cp -fp /jffs/addons/rtrmon.d/speedtest-cli.json /root/.config/ookla/speedtest-cli.json 2>/dev/null
          fi

          NextPage="$([ $# -gt 1 ] && echo "$2" | tr -d -c 1-7 || echo)"
          if [ -z "$NextPage" ]; then NextPage=1 ; fi

          # Per @Stephen Harrington's suggestion, check NVRAM to see if WiFi is turned on, else mark them as disabled
          if [ "$FourBandCustom55624" == "True" ]; then
            if [ "$($timeoutcmd$timeoutsec nvram get wl0_radio)" -eq 0 ]; then
              MaxSpeed5GhzNow=0
            else
              MaxSpeed5GhzNow=$MaxSpeed5Ghz
            fi
            if [ "$($timeoutcmd$timeoutsec nvram get wl1_radio)" -eq 0 ]; then
              MaxSpeed52GhzNow=0
            else
              MaxSpeed52GhzNow=$MaxSpeed5Ghz
            fi
            if [ "$($timeoutcmd$timeoutsec nvram get wl2_radio)" -eq 0 ]; then
              MaxSpeed6GhzNow=0
            else
              MaxSpeed6GhzNow=$MaxSpeed6Ghz
            fi
            if [ "$($timeoutcmd$timeoutsec nvram get wl3_radio)" -eq 0 ]; then
              MaxSpeed24GhzNow=0
            else
              MaxSpeed24GhzNow=$MaxSpeed24Ghz
            fi
          elif [ "$FourBandCustom56624" == "True" ]; then
            if [ "$($timeoutcmd$timeoutsec nvram get wl0_radio)" -eq 0 ]; then
              MaxSpeed5GhzNow=0
            else
              MaxSpeed5GhzNow=$MaxSpeed5Ghz
            fi
            if [ "$($timeoutcmd$timeoutsec nvram get wl1_radio)" -eq 0 ]; then
              MaxSpeed6GhzNow=0
            else
              MaxSpeed6GhzNow=$MaxSpeed6Ghz
            fi
            if [ "$($timeoutcmd$timeoutsec nvram get wl2_radio)" -eq 0 ]; then
              MaxSpeed62GhzNow=0
            else
              MaxSpeed62GhzNow=$MaxSpeed6Ghz
            fi
            if [ "$($timeoutcmd$timeoutsec nvram get wl3_radio)" -eq 0 ]; then
              MaxSpeed24GhzNow=0
            else
              MaxSpeed24GhzNow=$MaxSpeed24Ghz
            fi
          elif [ "$ThreeBand2456" == "True" ]; then
            if [ "$($timeoutcmd$timeoutsec nvram get wl0_radio)" -eq 0 ]; then
              MaxSpeed24GhzNow=0
            else
              MaxSpeed24GhzNow=$MaxSpeed24Ghz
            fi
            if [ "$($timeoutcmd$timeoutsec nvram get wl1_radio)" -eq 0 ]; then
              MaxSpeed5GhzNow=0
            else
              MaxSpeed5GhzNow=$MaxSpeed5Ghz
            fi
            if [ "$($timeoutcmd$timeoutsec nvram get wl2_radio)" -eq 0 ]; then
              MaxSpeed6GhzNow=0
            else
              MaxSpeed6GhzNow=$MaxSpeed6Ghz
            fi
          elif [ "$ThreeBand2455" == "True" ]; then
            if [ "$($timeoutcmd$timeoutsec nvram get wl0_radio)" -eq 0 ]; then
              MaxSpeed24GhzNow=0
            else
              MaxSpeed24GhzNow=$MaxSpeed24Ghz
            fi
            if [ "$($timeoutcmd$timeoutsec nvram get wl1_radio)" -eq 0 ]; then
              MaxSpeed5GhzNow=0
            else
              MaxSpeed5GhzNow=$MaxSpeed5Ghz
            fi
            if [ "$($timeoutcmd$timeoutsec nvram get wl2_radio)" -eq 0 ]; then
              MaxSpeed52GhzNow=0
            else
              MaxSpeed52GhzNow=$MaxSpeed5Ghz
            fi
          else
            if [ "$($timeoutcmd$timeoutsec nvram get wl0_radio)" -eq 0 ]; then
              MaxSpeed24GhzNow=0
            else
              MaxSpeed24GhzNow=$MaxSpeed24Ghz
            fi
            if [ "$($timeoutcmd$timeoutsec nvram get wl1_radio)" -eq 0 ]; then
              MaxSpeed5GhzNow=0
            else
              MaxSpeed5GhzNow=$MaxSpeed5Ghz
            fi
          fi

      else
        echo -e "${CRed}Error: RTRMON is not configured or does not have all the required dependencies${CClear}"
        echo -e "${CRed}installed. Launching 'rtrmon -setup' to install dependencies/complete setup!${CClear}"
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - ERROR: RTRMON is not configured/missing dependencies. Please run the setup tool." >> $LOGFILE
        echo ""
        echo -e "${CGreen}Launching the Setup Menu in T-5 sec...${CClear}"
        spinner 5
        vsetup
        echo -e "${CClear}"
        exit 0
      fi
  fi

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-03] ##
##----------------------------------------##
# -------------------------------------------------------------------------------------------------------------------------
# Main RTRMON program initialization
# -------------------------------------------------------------------------------------------------------------------------
  _IgnoreKeypresses_ ON
  # Display the logo and indicator that stats are being gathered.

  clear
  logoNM
  echo -e "\r${CGreen}              [Initiating Boot Sequence - Gathering Initial Stats...]"
  echo ""
  INITIALBOOT=1
  trimlogs
  echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: RTRMON is initializing for the first time..." >> $LOGFILE

  # Capture initial traffic and store current WAN/WiFi bytes stats
  if [ "$WAN0AltModes" == "0" ] || [ "$OpsMode" == "1" ]; then
    if [ $WANOverride == "Auto" ]; then WANIFNAME=$(get_wan_setting ifname); else WANIFNAME=$WANOverride; fi
    if [ -z $WANIFNAME ]; then WANIFNAME="eth0"; fi
    oldwanrxbytes="$(cat /sys/class/net/$WANIFNAME/statistics/rx_bytes)"
    oldwantxbytes="$(cat /sys/class/net/$WANIFNAME/statistics/tx_bytes)"
  fi

  if [ "$FourBandCustom55624" == "True" ]; then
    ifname5=$($timeoutcmd$timeoutsec nvram get wl0_ifname)
    ifname52=$($timeoutcmd$timeoutsec nvram get wl1_ifname)
    ifname6=$($timeoutcmd$timeoutsec nvram get wl2_ifname)
    ifname24=$($timeoutcmd$timeoutsec nvram get wl3_ifname)
  elif [ "$FourBandCustom56624" == "True" ]; then
    ifname5=$($timeoutcmd$timeoutsec nvram get wl0_ifname)
    ifname6=$($timeoutcmd$timeoutsec nvram get wl1_ifname)
    ifname62=$($timeoutcmd$timeoutsec nvram get wl2_ifname)
    ifname24=$($timeoutcmd$timeoutsec nvram get wl3_ifname)
  elif [ "$ThreeBand2456" == "True" ]; then
    ifname24=$($timeoutcmd$timeoutsec nvram get wl0_ifname)
    ifname5=$($timeoutcmd$timeoutsec nvram get wl1_ifname)
    ifname6=$($timeoutcmd$timeoutsec nvram get wl2_ifname)
  elif [ "$ThreeBand2455" == "True" ]; then
    ifname24=$($timeoutcmd$timeoutsec nvram get wl0_ifname)
    ifname5=$($timeoutcmd$timeoutsec nvram get wl1_ifname)
    ifname52=$($timeoutcmd$timeoutsec nvram get wl2_ifname)
  else
    ifname24=$($timeoutcmd$timeoutsec nvram get wl0_ifname)
    ifname5=$($timeoutcmd$timeoutsec nvram get wl1_ifname)
  fi

  old24rxbytes="$(cat /sys/class/net/$ifname24/statistics/rx_bytes)"
  old24txbytes="$(cat /sys/class/net/$ifname24/statistics/tx_bytes)"
  old5rxbytes="$(cat /sys/class/net/$ifname5/statistics/rx_bytes)"
  old5txbytes="$(cat /sys/class/net/$ifname5/statistics/tx_bytes)"
  if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2455" == "True" ]; then
    old52rxbytes="$(cat /sys/class/net/$ifname52/statistics/rx_bytes)"
    old52txbytes="$(cat /sys/class/net/$ifname52/statistics/tx_bytes)"
  fi
  if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2456" == "True" ] || [ "$FourBandCustom56624" == "True" ]; then
    old6rxbytes="$(cat /sys/class/net/$ifname6/statistics/rx_bytes)"
    old6txbytes="$(cat /sys/class/net/$ifname6/statistics/tx_bytes)"
  fi
  if [ "$FourBandCustom56624" == "True" ]; then
    old62rxbytes="$(cat /sys/class/net/$ifname62/statistics/rx_bytes)"
    old62txbytes="$(cat /sys/class/net/$ifname62/statistics/tx_bytes)"
  fi
  oldlanrxbytes="$(cat /sys/class/net/br0/statistics/rx_bytes)"
  oldlantxbytes="$(cat /sys/class/net/br0/statistics/tx_bytes)"

  #Get the latest VPN stats
    vpn1slot=1
    VPNState="$(_VPN_GetClientState_ ${vpn1slot})"
    if [ -z "$VPNState" ]; then VPNState=0; fi # to catch possible wireguard interference
    if [ "$VPNState" -eq 2 ]; then
      TUN="tun1$vpn1slot"
      NVRAMVPNADDR="$($timeoutcmd$timeoutsec nvram get vpn_client"$vpn1slot"_addr)"
      NVRAMVPNIP="$(ping -c 1 -w 1 $NVRAMVPNADDR | awk -F '[()]' '/PING/ { print $2}')"

      if [ "$(echo "$NVRAMVPNIP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        oldvpnip="$NVRAMVPNIP"
        oldvpncity="Private Network"
      else
        lastvpnip="$oldvpnip"
        if [ "$VPNSite2Site" = "1" ]; then
          oldvpnip="$NVRAMVPNIP"
        else
          oldvpnip=$(curl --silent --fail --interface $TUN --request GET --url https://ipv4.icanhazip.com) # Grab the public IP of the VPN Connection
        fi
        if [ -z "$oldvpnip" ]; then oldvpnip=$NVRAMVPNIP; fi
        if [ "$lastvpnip" != "$oldvpnip" ]; then
          oldvpncity="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$oldvpnip | jq --raw-output .city"
          oldvpncity="$(eval $oldvpncity)"; if echo $oldvpncity | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then oldvpncity="Undetermined"; fi
          vpncity=$oldvpncity
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: API call made to determine geolocation of VPN$vpn1slot: $oldvpnip ($oldvpncity)" >> $LOGFILE
        fi
      fi
      vpn1on="True"
    else
      vpn1on="False"
    fi

  #Check to see if there's a secondary VPN connection
    vpn2slot=2
    VPN2State="$(_VPN_GetClientState_ ${vpn2slot})"
    if [ -z $VPN2State ]; then VPN2State=0; fi # to catch possible wireguard interference
    if [ $VPN2State -eq 2 ]; then
      TUN2="tun1"$vpn2slot
      NVRAMVPN2ADDR=$($timeoutcmd$timeoutsec nvram get vpn_client"$vpn2slot"_addr)
      NVRAMVPN2IP=$(ping -c 1 -w 1 $NVRAMVPN2ADDR | awk -F '[()]' '/PING/ { print $2}')

      if [ "$(echo $NVRAMVPN2IP | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        oldvpn2ip=$NVRAMVPN2IP
        oldvpn2city="Private Network"
      else
        lastvpn2ip=$oldvpn2ip
        oldvpn2ip=$(curl --silent --fail --interface $TUN2 --request GET --url https://ipv4.icanhazip.com) # Grab the public IP of the VPN Connection
        if [ -z $oldvpn2ip ]; then oldvpn2ip=$NVRAMVPN2IP; fi
        if [ "$lastvpn2ip" != "$oldvpn2ip" ]; then
          oldvpn2city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$oldvpn2ip | jq --raw-output .city"
          oldvpn2city="$(eval $oldvpn2city)"; if echo $oldvpn2city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then oldvpn2city="Undetermined"; fi
          vpn2city=$oldvpn2city
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: API call made to determine geolocation of VPN$vpn2slot: $oldvpn2ip ($oldvpn2city)" >> $LOGFILE
        fi
      fi
      vpn2on="True"
    else
      vpn2on="False"
    fi

  #Check to see if there's a third VPN connection
    vpn3slot=3
    VPN3State="$(_VPN_GetClientState_ ${vpn3slot})"
    if [ -z $VPN3State ]; then VPN3State=0; fi # to catch possible wireguard interference
    if [ $VPN3State -eq 2 ]; then
      TUN3="tun1"$vpn3slot
      NVRAMVPN3ADDR=$($timeoutcmd$timeoutsec nvram get vpn_client"$vpn3slot"_addr)
      NVRAMVPN3IP=$(ping -c 1 -w 1 $NVRAMVPN3ADDR | awk -F '[()]' '/PING/ { print $2}')

      if [ "$(echo $NVRAMVPN3IP | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        oldvpn3ip=$NVRAMVPN3IP
        oldvpn3city="Private Network"
      else
        lastvpn3ip=$oldvpn3ip
        oldvpn3ip=$(curl --silent --fail --interface $TUN3 --request GET --url https://ipv4.icanhazip.com) # Grab the public IP of the VPN Connection
        if [ -z $oldvpn3ip ]; then oldvpn3ip=$NVRAMVPN3IP; fi
        if [ "$lastvpn3ip" != "$oldvpn3ip" ]; then
          oldvpn3city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$oldvpn3ip | jq --raw-output .city"
          oldvpn3city="$(eval $oldvpn3city)"; if echo $oldvpn3city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then oldvpn3city="Undetermined"; fi
          vpn3city=$oldvpn3city
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: API call made to determine geolocation of VPN$vpn3slot: $oldvpn3ip ($oldvpn3city)" >> $LOGFILE
        fi
      fi
      vpn3on="True"
    else
      vpn3on="False"
    fi

  #Check to see if there's a fourth VPN connection
    vpn4slot=4
    VPN4State="$(_VPN_GetClientState_ ${vpn4slot})"
    if [ -z $VPN4State ]; then VPN4State=0; fi # to catch possible wireguard interference
    if [ $VPN4State -eq 2 ]; then
      TUN4="tun1"$vpn4slot
      NVRAMVPN4ADDR=$($timeoutcmd$timeoutsec nvram get vpn_client"$vpn4slot"_addr)
      NVRAMVPN4IP=$(ping -c 1 -w 1 $NVRAMVPN4ADDR | awk -F '[()]' '/PING/ { print $2}')

      if [ "$(echo $NVRAMVPN4IP | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        oldvpn4ip=$NVRAMVPN4IP
        oldvpn4city="Private Network"
      else
        lastvpn4ip=$oldvpn4ip
        oldvpn4ip=$(curl --silent --fail --interface $TUN4 --request GET --url https://ipv4.icanhazip.com) # Grab the public IP of the VPN Connection
        if [ -z $oldvpn4ip ]; then oldvpn4ip=$NVRAMVPN4IP; fi
        if [ "$lastvpn4ip" != "$oldvpn4ip" ]; then
          oldvpn4city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$oldvpn4ip | jq --raw-output .city"
          oldvpn4city="$(eval $oldvpn4city)"; if echo $oldvpn4city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then oldvpn4city="Undetermined"; fi
          vpn4city=$oldvpn4city
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: API call made to determine geolocation of VPN$vpn4slot: $oldvpn4ip ($oldvpn4city)" >> $LOGFILE
        fi
      fi
      vpn4on="True"
    else
      vpn4on="False"
    fi

  #Check to see if there's a fifth VPN connection
    vpn5slot=5
    VPN5State="$(_VPN_GetClientState_ ${vpn5slot})"
    if [ -z $VPN5State ]; then VPN5State=0; fi # to catch possible wireguard interference
    if [ $VPN5State -eq 2 ]; then
      TUN5="tun1"$vpn5slot
      NVRAMVPN5ADDR=$($timeoutcmd$timeoutsec nvram get vpn_client"$vpn5slot"_addr)
      NVRAMVPN5IP=$(ping -c 1 -w 1 $NVRAMVPN5ADDR | awk -F '[()]' '/PING/ { print $2}')

      if [ "$(echo $NVRAMVPN5IP | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        oldvpn5ip=$NVRAMVPN5IP
        oldvpn5city="Private Network"
      else
        lastvpn5ip=$oldvpn5ip
        oldvpn5ip=$(curl --silent --fail --interface $TUN5 --request GET --url https://ipv4.icanhazip.com) # Grab the public IP of the VPN Connection
        if [ -z $oldvpn5ip ]; then oldvpn5ip=$NVRAMVPN5IP; fi
        if [ "$lastvpn5ip" != "$oldvpn5ip" ]; then
          oldvpn5city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$oldvpn5ip | jq --raw-output .city"
          oldvpn5city="$(eval $oldvpn5city)"; if echo $oldvpn5city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then oldvpn5city="Undetermined"; fi
          vpn5city=$oldvpn5city
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: API call made to determine geolocation of VPN$vpn5slot: $oldvpn5ip ($oldvpn5city)" >> $LOGFILE
        fi
      fi
      vpn5on="True"
    else
      vpn5on="False"
    fi

    #Check to see if there's a WGC1 connection
    wg1slot=1
    WG1State="$(_WG_GetClientState_ ${wg1slot})"
    if [ -z "$WG1State" ]; then WG1State=0; fi
    if [ "$WG1State" -eq 2 ]; then
      WGTUN1="wgc$wg1slot"
      WGTUN1_IP=$($timeoutcmd$timeoutsec nvram get "$WGTUN1"_addr | cut -d '/' -f1)

      # Added based on suggestion from @ZebMcKayhan
      ip rule add from $WGTUN1_IP lookup $WGTUN1 prio 10 >/dev/null 2>&1

      icanhazwg1ip="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$WGTUN1" --request GET --url https://ipv4.icanhazip.com"
      icanhazwg1ip="$(eval $icanhazwg1ip)"
      if [ -z "$icanhazwg1ip" ] || echo "$icanhazwg1ip" | grep -qoE 'Internet|traffic|Error|error'
      then
        NVRAMWG1IP="000.000.000.000"
      else
        NVRAMWG1IP="$icanhazwg1ip"
      fi

      # Added based on suggestion from @ZebMcKayhan
      ip rule del prio 10 >/dev/null 2>&1

      if [ "$(echo "$NVRAMWG1IP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        oldwg1ip="$NVRAMWG1IP"
        oldwg1city="Private Network"
      else
        lastwg1ip="$oldwg1ip"
        oldwg1ip="$NVRAMWG1IP"
        #if [ -z "$wg1ip" ]; then wg1ip=$WGTUN1_IP; fi
        if [ "$lastwg1ip" != "$oldwg1ip" ]; then
          oldwg1city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$oldwg1ip | jq --raw-output .city"
          oldwg1city="$(eval $oldwg1city)"; if echo $oldwg1city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then oldwg1city="Undetermined"; fi
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - API call made to determine geolocation of WG$wg1slot: $oldwg1ip ($oldwg1city)" >> $LOGFILE
        fi
      fi
      wg1on="True"
    else
      wg1on="False"
    fi

    #Check to see if there's a WGC2 connection
    wg2slot=2
    WG2State="$(_WG_GetClientState_ ${wg2slot})"
    if [ -z "$WG2State" ]; then WG2State=0; fi
    if [ "$WG2State" -eq 2 ]; then
      WGTUN2="wgc$wg2slot"
      WGTUN2_IP=$($timeoutcmd$timeoutsec nvram get "$WGTUN2"_addr | cut -d '/' -f1)

      # Added based on suggestion from @ZebMcKayhan
      ip rule add from $WGTUN2_IP lookup $WGTUN2 prio 10 >/dev/null 2>&1

      icanhazwg2ip="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$WGTUN2" --request GET --url https://ipv4.icanhazip.com"
      icanhazwg2ip="$(eval $icanhazwg2ip)"
      if [ -z "$icanhazwg2ip" ] || echo "$icanhazwg2ip" | grep -qoE 'Internet|traffic|Error|error'
      then
        NVRAMWG2IP="000.000.000.000"
      else
        NVRAMWG2IP="$icanhazwg2ip"
      fi

      # Added based on suggestion from @ZebMcKayhan
      ip rule del prio 10 >/dev/null 2>&1

      if [ "$(echo "$NVRAMWG2IP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        oldwg2ip="$NVRAMWG2IP"
        oldwg2city="Private Network"
      else
        lastwg2ip="$oldwg2ip"
        oldwg2ip="$NVRAMWG2IP"
        if [ "$lastwg2ip" != "$oldwg2ip" ]; then
          oldwg2city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$oldwg2ip | jq --raw-output .city"
          oldwg2city="$(eval $oldwg2city)"; if echo $oldwg2city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then oldwg2city="Undetermined"; fi
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - API call made to determine geolocation of WG$wg2slot: $oldwg2ip ($oldwg2city)" >> $LOGFILE
        fi
      fi
      wg2on="True"
    else
      wg2on="False"
    fi

    #Check to see if there's a WGC3 connection
    wg3slot=3
    WG3State="$(_WG_GetClientState_ ${wg3slot})"
    if [ -z "$WG3State" ]; then WG3State=0; fi
    if [ "$WG3State" -eq 2 ]; then
      WGTUN3="wgc$wg3slot"
      WGTUN3_IP=$($timeoutcmd$timeoutsec nvram get "$WGTUN3"_addr | cut -d '/' -f1)

      # Added based on suggestion from @ZebMcKayhan
      ip rule add from $WGTUN3_IP lookup $WGTUN3 prio 10 >/dev/null 2>&1

      icanhazwg3ip="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$WGTUN3" --request GET --url https://ipv4.icanhazip.com"
      icanhazwg3ip="$(eval $icanhazwg3ip)"
      if [ -z "$icanhazwg3ip" ] || echo "$icanhazwg3ip" | grep -qoE 'Internet|traffic|Error|error'
      then
        NVRAMWG3IP="000.000.000.000"
      else
        NVRAMWG3IP="$icanhazwg3ip"
      fi

      # Added based on suggestion from @ZebMcKayhan
      ip rule del prio 10 >/dev/null 2>&1

      if [ "$(echo "$NVRAMWG3IP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        oldwg3ip="$NVRAMWG3IP"
        oldwg3city="Private Network"
      else
        lastwg3ip="$oldwg3ip"
        oldwg3ip="$NVRAMWG3IP"
        if [ "$lastwg3ip" != "$oldwg3ip" ]; then
          oldwg3city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$oldwg3ip | jq --raw-output .city"
          oldwg3city="$(eval $oldwg3city)"; if echo $oldwg3city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then oldwg3city="Undetermined"; fi
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - API call made to determine geolocation of WG$wg3slot: $oldwg3ip ($oldwg3city)" >> $LOGFILE
        fi
      fi
      wg3on="True"
    else
      wg3on="False"
    fi

    #Check to see if there's a WGC4 connection
    wg4slot=4
    WG4State="$(_WG_GetClientState_ ${wg4slot})"
    if [ -z "$WG4State" ]; then WG4State=0; fi
    if [ "$WG4State" -eq 2 ]; then
      WGTUN4="wgc$wg4slot"
      WGTUN4_IP=$($timeoutcmd$timeoutsec nvram get "$WGTUN4"_addr | cut -d '/' -f1)

      # Added based on suggestion from @ZebMcKayhan
      ip rule add from $WGTUN4_IP lookup $WGTUN4 prio 10 >/dev/null 2>&1

      icanhazwg4ip="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$WGTUN4" --request GET --url https://ipv4.icanhazip.com"
      icanhazwg4ip="$(eval $icanhazwg4ip)"
      if [ -z "$icanhazwg4ip" ] || echo "$icanhazwg4ip" | grep -qoE 'Internet|traffic|Error|error'
      then
        NVRAMWG4IP="000.000.000.000"
      else
        NVRAMWG4IP="$icanhazwg4ip"
      fi

      # Added based on suggestion from @ZebMcKayhan
      ip rule del prio 10 >/dev/null 2>&1

      if [ "$(echo "$NVRAMWG4IP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        oldwg4ip="$NVRAMWG4IP"
        oldwg4city="Private Network"
      else
        lastwg4ip="$oldwg4ip"
        oldwg4ip="$NVRAMWG4IP"
        if [ "$lastwg4ip" != "$oldwg4ip" ]; then
          oldwg4city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$oldwg4ip | jq --raw-output .city"
          oldwg4city="$(eval $oldwg4city)"; if echo $oldwg4city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then oldwg4city="Undetermined"; fi
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - API call made to determine geolocation of WG$wg4slot: $oldwg4ip ($oldwg4city)" >> $LOGFILE
        fi
      fi
      wg4on="True"
    else
      wg4on="False"
    fi

    #Check to see if there's a WGC5 connection
    wg5slot=5
    WG5State="$(_WG_GetClientState_ ${wg5slot})"
    if [ -z "$WG5State" ]; then WG5State=0; fi
    if [ "$WG5State" -eq 2 ]; then
      WGTUN5="wgc$wg5slot"
      WGTUN5_IP=$($timeoutcmd$timeoutsec nvram get "$WGTUN5"_addr | cut -d '/' -f1)

      # Added based on suggestion from @ZebMcKayhan
      ip rule add from $WGTUN5_IP lookup $WGTUN5 prio 10 >/dev/null 2>&1

      icanhazwg5ip="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$WGTUN5" --request GET --url https://ipv4.icanhazip.com"
      icanhazwg5ip="$(eval $icanhazwg5ip)"
      if [ -z "$icanhazwg5ip" ] || echo "$icanhazwg5ip" | grep -qoE 'Internet|traffic|Error|error'
      then
        NVRAMWG5IP="000.000.000.000"
      else
        NVRAMWG5IP="$icanhazwg5ip"
      fi

      # Added based on suggestion from @ZebMcKayhan
      ip rule del prio 10 >/dev/null 2>&1

      if [ "$(echo "$NVRAMWG5IP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        oldwg5ip="$NVRAMWG5IP"
        oldwg5city="Private Network"
      else
        lastwg5ip="$oldwg5ip"
        oldwg5ip="$NVRAMWG5IP"
        if [ "$lastwg5ip" != "$oldwg5ip" ]; then
          oldwg5city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$oldwg5ip | jq --raw-output .city"
          oldwg5city="$(eval $oldwg5city)"; if echo $oldwg5city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then oldwg5city="Undetermined"; fi
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - API call made to determine geolocation of WG$wg5slot: $oldwg5ip ($oldwg5city)" >> $LOGFILE
        fi
      fi
      wg5on="True"
    else
      wg5on="False"
    fi

  if [ "$vpn1on" == "True" ]; then
    oldvpntxrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client$vpn1slot/status 2>/dev/null)
    oldvpnrxbytes="$(echo $oldvpntxrxbytes | cut -d' ' -f1)"
    oldvpntxbytes="$(echo $oldvpntxrxbytes | cut -d' ' -f2)"
    if [ -z $oldvpnrxbytes ]; then oldvpnrxbytes=0; fi
    if [ -z $oldvpntxbytes ]; then oldvpntxbytes=0; fi

    if [ $oldvpnrxbytes -le 0 ]; then
      oldvpnrxbytes=0
    elif [ $oldvpntxbytes -le 0 ]; then
      oldvpntxbytes=0
    fi

  fi

  if [ "$vpn2on" == "True" ]; then
    oldvpn2txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client$vpn2slot/status 2>/dev/null)
    oldvpn2rxbytes="$(echo $oldvpn2txrxbytes | cut -d' ' -f1)"
    oldvpn2txbytes="$(echo $oldvpn2txrxbytes | cut -d' ' -f2)"
    if [ -z $oldvpn2rxbytes ]; then oldvpn2rxbytes=0; fi
    if [ -z $oldvpn2txbytes ]; then oldvpn2txbytes=0; fi

    if [ $oldvpn2rxbytes -le 0 ]; then
      oldvpn2rxbytes=0
    elif [ $oldvpn2txbytes -le 0 ]; then
      oldvpn2txbytes=0
    fi

  fi

  if [ "$vpn3on" == "True" ]; then
    oldvpn3txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client$vpn3slot/status 2>/dev/null)
    oldvpn3rxbytes="$(echo $oldvpn3txrxbytes | cut -d' ' -f1)"
    oldvpn3txbytes="$(echo $oldvpn3txrxbytes | cut -d' ' -f2)"
    if [ -z $oldvpn3rxbytes ]; then oldvpn3rxbytes=0; fi
    if [ -z $oldvpn3txbytes ]; then oldvpn3txbytes=0; fi

    if [ $oldvpn3rxbytes -le 0 ]; then
      oldvpn3rxbytes=0
    elif [ $oldvpn3txbytes -le 0 ]; then
      oldvpn3txbytes=0
    fi

  fi

  if [ "$vpn4on" == "True" ]; then
    oldvpn4txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client$vpn4slot/status 2>/dev/null)
    oldvpn4rxbytes="$(echo $oldvpn4txrxbytes | cut -d' ' -f1)"
    oldvpn4txbytes="$(echo $oldvpn4txrxbytes | cut -d' ' -f2)"
    if [ -z $oldvpn4rxbytes ]; then oldvpn4rxbytes=0; fi
    if [ -z $oldvpn4txbytes ]; then oldvpn4txbytes=0; fi

    if [ $oldvpn4rxbytes -le 0 ]; then
      oldvpn4rxbytes=0
    elif [ $oldvpn4txbytes -le 0 ]; then
      oldvpn4txbytes=0
    fi

  fi

  if [ "$vpn5on" == "True" ]; then
    oldvpn5txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client$vpn5slot/status 2>/dev/null)
    oldvpn5rxbytes="$(echo $oldvpn5txrxbytes | cut -d' ' -f1)"
    oldvpn5txbytes="$(echo $oldvpn5txrxbytes | cut -d' ' -f2)"
    if [ -z $oldvpn5rxbytes ]; then oldvpn5rxbytes=0; fi
    if [ -z $oldvpn5txbytes ]; then oldvpn5txbytes=0; fi

    if [ $oldvpn5rxbytes -le 0 ]; then
      oldvpn5rxbytes=0
    elif [ $oldvpn5txbytes -le 0 ]; then
      oldvpn5txbytes=0
    fi

  fi

  # Check the wireguard connections
  if [ "$wg1on" == "True" ]; then
    oldwg1txrxbytes=$(wg show wgc1 transfer)
    oldwg1rxbytes="$(echo $oldwg1txrxbytes | cut -d' ' -f3)"
    oldwg1txbytes="$(echo $oldwg1txrxbytes | cut -d' ' -f2)"
    if [ -z $oldwg1rxbytes ] || [ $oldwg1rxbytes -le 0 ]; then oldwg1rxbytes=0; fi
    if [ -z $oldwg1txbytes ] || [ $oldwg1txbytes -le 0 ]; then oldwg1txbytes=0; fi
  fi

  if [ "$wg2on" == "True" ]; then
    oldwg2txrxbytes=$(wg show wgc2 transfer)
    oldwg2rxbytes="$(echo $oldwg2txrxbytes | cut -d' ' -f3)"
    oldwg2txbytes="$(echo $oldwg2txrxbytes | cut -d' ' -f2)"
    if [ -z $oldwg2rxbytes ] || [ $oldwg2rxbytes -le 0 ]; then oldwg2rxbytes=0; fi
    if [ -z $oldwg2txbytes ] || [ $oldwg2txbytes -le 0 ]; then oldwg2txbytes=0; fi
  fi

  if [ "$wg3on" == "True" ]; then
    oldwg3txrxbytes=$(wg show wgc3 transfer)
    oldwg3rxbytes="$(echo $oldwg3txrxbytes | cut -d' ' -f3)"
    oldwg3txbytes="$(echo $oldwg3txrxbytes | cut -d' ' -f2)"
    if [ -z $oldwg3rxbytes ] || [ $oldwg3rxbytes -le 0 ]; then oldwg3rxbytes=0; fi
    if [ -z $oldwg3txbytes ] || [ $oldwg3txbytes -le 0 ]; then oldwg3txbytes=0; fi
  fi

  if [ "$wg4on" == "True" ]; then
    oldwg4txrxbytes=$(wg show wgc4 transfer)
    oldwg4rxbytes="$(echo $oldwg4txrxbytes | cut -d' ' -f3)"
    oldwg4txbytes="$(echo $oldwg4txrxbytes | cut -d' ' -f2)"
    if [ -z $oldwg4rxbytes ] || [ $oldwg4rxbytes -le 0 ]; then oldwg4rxbytes=0; fi
    if [ -z $oldwg4txbytes ] || [ $oldwg4txbytes -le 0 ]; then oldwg4txbytes=0; fi
  fi

  if [ "$wg5on" == "True" ]; then
    oldwg5txrxbytes=$(wg show wgc5 transfer)
    oldwg5rxbytes="$(echo $oldwg5txrxbytes | cut -d' ' -f3)"
    oldwg5txbytes="$(echo $oldwg5txrxbytes | cut -d' ' -f2)"
    if [ -z $oldwg5rxbytes ] || [ $oldwg5rxbytes -le 0 ]; then oldwg5rxbytes=0; fi
    if [ -z $oldwg5txbytes ] || [ $oldwg5txbytes -le 0 ]; then oldwg5txbytes=0; fi
  fi

  # Get initial TOP stats to average across the interval period
  RM_ELAPSED_TIME=0
  RM_START_TIME="$(date +%s)"

  ##----------------------------------------##
  ## Modified by Martinski W. [2024-Nov-04] ##
  ##----------------------------------------##
  timer=0
  lastTimerSec=0
  updateTimer=true
  savedInterval="$Interval"
  Interval="$bootInterval"

  # Initial Boot Sequence Loop #
  while [ "$timer" -lt "$Interval" ]
  do
      if "$updateTimer"
      then
          updateTimer=false
          timer="$((timer+1))"
          lastTimerSec="$(date +%s)"
          gettopstats "$timer"
      fi
      preparebar 53 "|"
      progressbaroverride "$timer" "$Interval" "" "s" "Standard"

      ## Prevent repeatedly fast key presses from updating the timer ##
      [ "$(date +%s)" -gt "$lastTimerSec" ] && updateTimer=true
  done

  calculatestats
  oldstats

  clear
  INITIALBOOT=0
  Interval="$savedInterval"

# -------------------------------------------------------------------------------------------------------------------------
# Main loop that calls functions to perform all necessary calculations across the interval period
# -------------------------------------------------------------------------------------------------------------------------
##----------------------------------------##
## Modified by Martinski W. [2024-Nov-03] ##
##----------------------------------------##
while true
do
  _SetUpTimeoutCmdVars_
  _SetLAN_HostName_
  _IgnoreKeypresses_ ON

  if [ "$NextPage" = "1" ]; then
     DisplayPage1
     echo ""
  elif [ "$NextPage" = "2" ]; then
     DisplayPage2
     echo ""
  elif [ "$NextPage" = "3" ]; then
     DisplayPage3
     echo ""
  elif [ "$NextPage" = "4" ]; then
     DisplayPage4
     echo ""
  elif [ "$NextPage" = "5" ]; then
     DisplayPage5
     #echo ""
  elif [ "$NextPage" = "6" ]; then
     DisplayPage6
     #echo ""
  elif [ "$NextPage" = "7" ]; then
     DisplayPage7
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
  displaycpuirq1=0

  # Get fresh WAN stats
  if [ "$WAN0AltModes" == "0" ] || [ "$OpsMode" == "1" ]; then
    oldwanrxbytes="$(cat /sys/class/net/$WANIFNAME/statistics/rx_bytes)"
    oldwantxbytes="$(cat /sys/class/net/$WANIFNAME/statistics/tx_bytes)"
  fi
  old24rxbytes="$(cat /sys/class/net/$ifname24/statistics/rx_bytes)"
  old24txbytes="$(cat /sys/class/net/$ifname24/statistics/tx_bytes)"
  old5rxbytes="$(cat /sys/class/net/$ifname5/statistics/rx_bytes)"
  old5txbytes="$(cat /sys/class/net/$ifname5/statistics/tx_bytes)"
  if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2455" == "True" ]; then
    old52rxbytes="$(cat /sys/class/net/$ifname52/statistics/rx_bytes)"
    old52txbytes="$(cat /sys/class/net/$ifname52/statistics/tx_bytes)"
  fi
  if [ "$FourBandCustom55624" == "True" ] || [ "$ThreeBand2456" == "True" ] || [ "$FourBandCustom56624" == "True" ]; then
    old6rxbytes="$(cat /sys/class/net/$ifname6/statistics/rx_bytes)"
    old6txbytes="$(cat /sys/class/net/$ifname6/statistics/tx_bytes)"
  fi
  if [ "$FourBandCustom56624" == "True" ]; then
    old62rxbytes="$(cat /sys/class/net/$ifname62/statistics/rx_bytes)"
    old62txbytes="$(cat /sys/class/net/$ifname62/statistics/tx_bytes)"
  fi
  oldlanrxbytes="$(cat /sys/class/net/br0/statistics/rx_bytes)"
  oldlantxbytes="$(cat /sys/class/net/br0/statistics/tx_bytes)"

  # Get fresh VPN stats
  echo ""
  vpn1slot=1
  VPNState="$(_VPN_GetClientState_ ${vpn1slot})"
  if [ -z $VPNState ]; then VPNState=0; fi # to catch possible wireguard interference
  if [ $VPNState -eq 2 ]; then
    TUN="tun1"$vpn1slot
    NVRAMVPNADDR=$($timeoutcmd$timeoutsec nvram get vpn_client"$vpn1slot"_addr)
    printf "${CGreen}\r[Refreshing VPN1 Stats...]"
    NVRAMVPNIP=$(ping -c 1 -w 1 $NVRAMVPNADDR | awk -F '[()]' '/PING/ { print $2}')

    if [ "$(echo $NVRAMVPNIP | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
      oldvpnip=$NVRAMVPNIP
      oldvpncity="Private Network"
    else
      lastvpnip=$oldvpnip
      if [ "$VPNSite2Site" == "1" ]; then
        oldvpnip=$NVRAMVPNIP
      else
        oldvpnip=$(curl --silent --fail --interface $TUN --request GET --url https://ipv4.icanhazip.com) # Grab the public IP of the VPN Connection
      fi
      if [ -z $oldvpnip ]; then oldvpnip=$NVRAMVPNIP; fi
      if [ "$lastvpnip" != "$oldvpnip" ]; then
        oldvpncity="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$oldvpnip | jq --raw-output .city"
        oldvpncity="$(eval $oldvpncity)"; if echo $oldvpncity | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then oldvpncity="Undetermined"; fi
        vpncity=$oldvpncity
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: API call made to determine geolocation of VPN$vpn1slot: $oldvpnip ($oldvpncity)" >> $LOGFILE
      fi
    fi
    vpn1on="True"
  else
    vpn1on="False"
  fi

  #Check to see if there's a secondary VPN connection
  vpn2slot=2
  VPN2State="$(_VPN_GetClientState_ ${vpn2slot})"
  if [ -z $VPN2State ]; then VPN2State=0; fi # to catch possible wireguard interference
  if [ $VPN2State -eq 2 ]; then
    TUN2="tun1"$vpn2slot
    NVRAMVPN2ADDR=$($timeoutcmd$timeoutsec nvram get vpn_client"$vpn2slot"_addr)
    printf "${CGreen}\r[Refreshing VPN2 Stats...]"
    NVRAMVPN2IP=$(ping -c 1 -w 1 $NVRAMVPN2ADDR | awk -F '[()]' '/PING/ { print $2}')

    if [ "$(echo $NVRAMVPN2IP | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
      oldvpn2ip=$NVRAMVPN2IP
      oldvpn2city="Private Network"
    else
      lastvpn2ip=$oldvpn2ip
      oldvpn2ip=$(curl --silent --fail --interface $TUN2 --request GET --url https://ipv4.icanhazip.com) # Grab the public IP of the VPN Connection
      if [ -z $oldvpn2ip ]; then oldvpn2ip=$NVRAMVPN2IP; fi
      if [ "$lastvpn2ip" != "$oldvpn2ip" ]; then
        oldvpn2city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$oldvpn2ip | jq --raw-output .city"
        oldvpn2city="$(eval $oldvpn2city)"; if echo $oldvpn2city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then oldvpn2city="Undetermined"; fi
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: API call made to determine geolocation of VPN$vpn2slot: $oldvpn2ip ($oldvpn2city)" >> $LOGFILE
      fi
    fi
    vpn2on="True"
  else
    vpn2on="False"
  fi

  #Check to see if there's a third VPN connection
  vpn3slot=3
  VPN3State="$(_VPN_GetClientState_ ${vpn3slot})"
  if [ -z $VPN3State ]; then VPN3State=0; fi # to catch possible wireguard interference
  if [ $VPN3State -eq 2 ]; then
    TUN3="tun1"$vpn3slot
    NVRAMVPN3ADDR=$($timeoutcmd$timeoutsec nvram get vpn_client"$vpn3slot"_addr)
    printf "${CGreen}\r[Refreshing VPN3 Stats...]"
    NVRAMVPN3IP=$(ping -c 1 -w 1 $NVRAMVPN3ADDR | awk -F '[()]' '/PING/ { print $2}')

    if [ "$(echo $NVRAMVPN3IP | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
      oldvpn3ip=$NVRAMVPN3IP
      oldvpn3city="Private Network"
    else
      lastvpn3ip=$oldvpn3ip
      oldvpn3ip=$(curl --silent --fail --interface $TUN3 --request GET --url https://ipv4.icanhazip.com) # Grab the public IP of the VPN Connection
      if [ -z $oldvpn3ip ]; then oldvpn3ip=$NVRAMVPN3IP; fi
      if [ "$lastvpn3ip" != "$oldvpn3ip" ]; then
        oldvpn3city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$oldvpn3ip | jq --raw-output .city"
        oldvpn3city="$(eval $oldvpn3city)"; if echo $oldvpn3city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then oldvpn3city="Undetermined"; fi
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: API call made to determine geolocation of VPN$vpn3slot: $oldvpn3ip ($oldvpn3city)" >> $LOGFILE
      fi
    fi
    vpn3on="True"
  else
    vpn3on="False"
  fi

  #Check to see if there's a fourth VPN connection
  vpn4slot=4
  VPN4State="$(_VPN_GetClientState_ ${vpn4slot})"
  if [ -z $VPN4State ]; then VPN4State=0; fi # to catch possible wireguard interference
  if [ $VPN4State -eq 2 ]; then
    TUN4="tun1"$vpn4slot
    NVRAMVPN4ADDR=$($timeoutcmd$timeoutsec nvram get vpn_client"$vpn4slot"_addr)
    printf "${CGreen}\r[Refreshing VPN4 Stats...]"
    NVRAMVPN4IP=$(ping -c 1 -w 1 $NVRAMVPN4ADDR | awk -F '[()]' '/PING/ { print $2}')

    if [ "$(echo $NVRAMVPN4IP | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
      oldvpn4ip=$NVRAMVPN4IP
      oldvpn4city="Private Network"
    else
      lastvpn4ip=$oldvpn4ip
      oldvpn4ip=$(curl --silent --fail --interface $TUN4 --request GET --url https://ipv4.icanhazip.com) # Grab the public IP of the VPN Connection
      if [ -z $oldvpn4ip ]; then oldvpn4ip=$NVRAMVPN4IP; fi
      if [ "$lastvpn4ip" != "$oldvpn4ip" ]; then
        oldvpn4city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$oldvpn4ip | jq --raw-output .city"
        oldvpn4city="$(eval $oldvpn4city)"; if echo $oldvpn4city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then oldvpn4city="Undetermined"; fi
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: API call made to determine geolocation of VPN$vpn4slot: $oldvpn4ip ($oldvpn4city)" >> $LOGFILE
      fi
    fi
    vpn4on="True"
  else
    vpn4on="False"
  fi

  #Check to see if there's a fifth VPN connection
  vpn5slot=5
  VPN5State="$(_VPN_GetClientState_ ${vpn5slot})"
  if [ -z $VPN5State ]; then VPN5State=0; fi # to catch possible wireguard interference
  if [ $VPN5State -eq 2 ]; then
    TUN5="tun1"$vpn5slot
    NVRAMVPN5ADDR=$($timeoutcmd$timeoutsec nvram get vpn_client"$vpn5slot"_addr)
    printf "${CGreen}\r[Refreshing VPN5 Stats...]"
    NVRAMVPN5IP=$(ping -c 1 -w 1 $NVRAMVPN5ADDR | awk -F '[()]' '/PING/ { print $2}')

    if [ "$(echo $NVRAMVPN5IP | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
      oldvpn5ip=$NVRAMVPN5IP
      oldvpn5city="Private Network"
    else
      lastvpn5ip=$oldvpn5ip
      oldvpn5ip=$(curl --silent --fail --interface $TUN5 --request GET --url https://ipv4.icanhazip.com) # Grab the public IP of the VPN Connection
      if [ -z $oldvpn5ip ]; then oldvpn5ip=$NVRAMVPN5IP; fi
      if [ "$lastvpn5ip" != "$oldvpn5ip" ]; then
        oldvpn5city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$oldvpn5ip | jq --raw-output .city"
        oldvpn5city="$(eval $oldvpn5city)"; if echo $oldvpn5city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then oldvpn5city="Undetermined"; fi
        echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - INFO: API call made to determine geolocation of VPN$vpn5slot: $oldvpn5ip ($oldvpn5city)" >> $LOGFILE
      fi
    fi
    vpn5on="True"
  else
    vpn5on="False"
  fi

    #Check to see if there's a WGC1 connection
    wg1slot=1
    WG1State="$(_WG_GetClientState_ ${wg1slot})"
    if [ -z "$WG1State" ]; then WG1State=0; fi
    if [ "$WG1State" -eq 2 ]; then
      WGTUN1="wgc$wg1slot"
      WGTUN1_IP=$($timeoutcmd$timeoutsec nvram get "$WGTUN1"_addr | cut -d '/' -f1)
      printf "${CGreen}\r[Refreshing WG1 Stats...]"

      # Added based on suggestion from @ZebMcKayhan
      ip rule add from $WGTUN1_IP lookup $WGTUN1 prio 10 >/dev/null 2>&1

      icanhazwg1ip="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$WGTUN1" --request GET --url https://ipv4.icanhazip.com"
      icanhazwg1ip="$(eval $icanhazwg1ip)"
      if [ -z "$icanhazwg1ip" ] || echo "$icanhazwg1ip" | grep -qoE 'Internet|traffic|Error|error'
      then
        NVRAMWG1IP="000.000.000.000"
      else
        NVRAMWG1IP="$icanhazwg1ip"
      fi

      # Added based on suggestion from @ZebMcKayhan
      ip rule del prio 10 >/dev/null 2>&1

      if [ "$(echo "$NVRAMWG1IP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        oldwg1ip="$NVRAMWG1IP"
        oldwg1city="Private Network"
      else
        lastwg1ip="$oldwg1ip"
        oldwg1ip="$NVRAMWG1IP"
        #if [ -z "$wg1ip" ]; then wg1ip=$WGTUN1_IP; fi
        if [ "$lastwg1ip" != "$oldwg1ip" ]; then
          oldwg1city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$oldwg1ip | jq --raw-output .city"
          oldwg1city="$(eval $oldwg1city)"; if echo $oldwg1city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then oldwg1city="Undetermined"; fi
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - API call made to determine geolocation of WG$wg1slot: $oldwg1ip ($oldwg1city)" >> $LOGFILE
        fi
      fi
      wg1on="True"
    else
      wg1on="False"
    fi

    #Check to see if there's a WGC2 connection
    wg2slot=2
    WG2State="$(_WG_GetClientState_ ${wg2slot})"
    if [ -z "$WG2State" ]; then WG2State=0; fi
    if [ "$WG2State" -eq 2 ]; then
      WGTUN2="wgc$wg2slot"
      WGTUN2_IP=$($timeoutcmd$timeoutsec nvram get "$WGTUN2"_addr | cut -d '/' -f1)
      printf "${CGreen}\r[Refreshing WG2 Stats...]"

      # Added based on suggestion from @ZebMcKayhan
      ip rule add from $WGTUN2_IP lookup $WGTUN2 prio 10 >/dev/null 2>&1

      icanhazwg2ip="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$WGTUN2" --request GET --url https://ipv4.icanhazip.com"
      icanhazwg2ip="$(eval $icanhazwg2ip)"
      if [ -z "$icanhazwg2ip" ] || echo "$icanhazwg2ip" | grep -qoE 'Internet|traffic|Error|error'
      then
        NVRAMWG2IP="000.000.000.000"
      else
        NVRAMWG2IP="$icanhazwg2ip"
      fi

      # Added based on suggestion from @ZebMcKayhan
      ip rule del prio 10 >/dev/null 2>&1

      if [ "$(echo "$NVRAMWG2IP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        oldwg2ip="$NVRAMWG2IP"
        oldwg2city="Private Network"
      else
        lastwg2ip="$oldwg2ip"
        oldwg2ip="$NVRAMWG2IP"
        if [ "$lastwg2ip" != "$oldwg2ip" ]; then
          oldwg2city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$oldwg2ip | jq --raw-output .city"
          oldwg2city="$(eval $oldwg2city)"; if echo $oldwg2city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then oldwg2city="Undetermined"; fi
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - API call made to determine geolocation of WG$wg2slot: $oldwg2ip ($oldwg2city)" >> $LOGFILE
        fi
      fi
      wg2on="True"
    else
      wg2on="False"
    fi

    #Check to see if there's a WGC3 connection
    wg3slot=3
    WG3State="$(_WG_GetClientState_ ${wg3slot})"
    if [ -z "$WG3State" ]; then WG3State=0; fi
    if [ "$WG3State" -eq 2 ]; then
      WGTUN3="wgc$wg3slot"
      WGTUN3_IP=$($timeoutcmd$timeoutsec nvram get "$WGTUN3"_addr | cut -d '/' -f1)
      printf "${CGreen}\r[Refreshing WG3 Stats...]"

      # Added based on suggestion from @ZebMcKayhan
      ip rule add from $WGTUN3_IP lookup $WGTUN3 prio 10 >/dev/null 2>&1

      icanhazwg3ip="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$WGTUN3" --request GET --url https://ipv4.icanhazip.com"
      icanhazwg3ip="$(eval $icanhazwg3ip)"
      if [ -z "$icanhazwg3ip" ] || echo "$icanhazwg3ip" | grep -qoE 'Internet|traffic|Error|error'
      then
        NVRAMWG3IP="000.000.000.000"
      else
        NVRAMWG3IP="$icanhazwg3ip"
      fi

      # Added based on suggestion from @ZebMcKayhan
      ip rule del prio 10 >/dev/null 2>&1

      if [ "$(echo "$NVRAMWG3IP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        oldwg3ip="$NVRAMWG3IP"
        oldwg3city="Private Network"
      else
        lastwg3ip="$oldwg3ip"
        oldwg3ip="$NVRAMWG3IP"
        if [ "$lastwg3ip" != "$oldwg3ip" ]; then
          oldwg3city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$oldwg3ip | jq --raw-output .city"
          oldwg3city="$(eval $oldwg3city)"; if echo $oldwg3city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then oldwg3city="Undetermined"; fi
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - API call made to determine geolocation of WG$wg3slot: $oldwg3ip ($oldwg3city)" >> $LOGFILE
        fi
      fi
      wg3on="True"
    else
      wg3on="False"
    fi

    #Check to see if there's a WGC4 connection
    wg4slot=4
    WG4State="$(_WG_GetClientState_ ${wg4slot})"
    if [ -z "$WG4State" ]; then WG4State=0; fi
    if [ "$WG4State" -eq 2 ]; then
      WGTUN4="wgc$wg4slot"
      WGTUN4_IP=$($timeoutcmd$timeoutsec nvram get "$WGTUN4"_addr | cut -d '/' -f1)
      printf "${CGreen}\r[Refreshing WG4 Stats...]"

      # Added based on suggestion from @ZebMcKayhan
      ip rule add from $WGTUN4_IP lookup $WGTUN4 prio 10 >/dev/null 2>&1

      icanhazwg4ip="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$WGTUN4" --request GET --url https://ipv4.icanhazip.com"
      icanhazwg4ip="$(eval $icanhazwg4ip)"
      if [ -z "$icanhazwg4ip" ] || echo "$icanhazwg4ip" | grep -qoE 'Internet|traffic|Error|error'
      then
        NVRAMWG4IP="000.000.000.000"
      else
        NVRAMWG4IP="$icanhazwg4ip"
      fi

      # Added based on suggestion from @ZebMcKayhan
      ip rule del prio 10 >/dev/null 2>&1

      if [ "$(echo "$NVRAMWG4IP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        oldwg4ip="$NVRAMWG4IP"
        oldwg4city="Private Network"
      else
        lastwg4ip="$oldwg4ip"
        oldwg4ip="$NVRAMWG4IP"
        if [ "$lastwg4ip" != "$oldwg4ip" ]; then
          oldwg4city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$oldwg4ip | jq --raw-output .city"
          oldwg4city="$(eval $oldwg4city)"; if echo $oldwg4city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then oldwg4city="Undetermined"; fi
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - API call made to determine geolocation of WG$wg4slot: $oldwg4ip ($oldwg4city)" >> $LOGFILE
        fi
      fi
      wg4on="True"
    else
      wg4on="False"
    fi

    #Check to see if there's a WGC5 connection
    wg5slot=5
    WG5State="$(_WG_GetClientState_ ${wg5slot})"
    if [ -z "$WG5State" ]; then WG5State=0; fi
    if [ "$WG5State" -eq 2 ]; then
      WGTUN5="wgc$wg5slot"
      WGTUN5_IP=$($timeoutcmd$timeoutsec nvram get "$WGTUN5"_addr | cut -d '/' -f1)
      printf "${CGreen}\r[Refreshing WG5 Stats...]"

      # Added based on suggestion from @ZebMcKayhan
      ip rule add from $WGTUN5_IP lookup $WGTUN5 prio 10 >/dev/null 2>&1

      icanhazwg5ip="curl --silent --retry 3 --retry-delay 2 --retry-all-errors --fail --interface "$WGTUN5" --request GET --url https://ipv4.icanhazip.com"
      icanhazwg5ip="$(eval $icanhazwg5ip)"
      if [ -z "$icanhazwg5ip" ] || echo "$icanhazwg5ip" | grep -qoE 'Internet|traffic|Error|error'
      then
        NVRAMWG5IP="000.000.000.000"
      else
        NVRAMWG5IP="$icanhazwg5ip"
      fi

      # Added based on suggestion from @ZebMcKayhan
      ip rule del prio 10 >/dev/null 2>&1

      if [ "$(echo "$NVRAMWG5IP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')" ]; then
        oldwg5ip="$NVRAMWG5IP"
        oldwg5city="Private Network"
      else
        lastwg5ip="$oldwg5ip"
        oldwg5ip="$NVRAMWG5IP"
        if [ "$lastwg5ip" != "$oldwg5ip" ]; then
          oldwg5city="curl --silent --retry 3 --request GET --url http://ip-api.com/json/$oldwg5ip | jq --raw-output .city"
          oldwg5city="$(eval $oldwg5city)"; if echo $oldwg5city | grep -qoE '\b(error.*:.*True.*|Undefined)\b'; then oldwg5city="Undetermined"; fi
          echo -e "$(date +'%b %d %Y %X') $(_GetLAN_HostName_) RTRMON[$$] - API call made to determine geolocation of WG$wg5slot: $oldwg5ip ($oldwg5city)" >> $LOGFILE
        fi
      fi
      wg5on="True"
    else
      wg5on="False"
    fi

  if [ "$vpn1on" == "True" ]; then
    oldvpntxrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client$vpn1slot/status 2>/dev/null)
    oldvpnrxbytes="$(echo $oldvpntxrxbytes | cut -d' ' -f1)"
    oldvpntxbytes="$(echo $oldvpntxrxbytes | cut -d' ' -f2)"
    if [ -z $oldvpnrxbytes ]; then oldvpnrxbytes=0; fi
    if [ -z $oldvpntxbytes ]; then oldvpntxbytes=0; fi

    if [ $oldvpnrxbytes -le 0 ]; then
      oldvpnrxbytes=0
    elif [ $oldvpntxbytes -le 0 ]; then
      oldvpntxbytes=0
    fi
  fi

  if [ "$vpn2on" == "True" ]; then
    oldvpn2txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client$vpn2slot/status 2>/dev/null)
    oldvpn2rxbytes="$(echo $oldvpn2txrxbytes | cut -d' ' -f1)"
    oldvpn2txbytes="$(echo $oldvpn2txrxbytes | cut -d' ' -f2)"
    if [ -z $oldvpn2rxbytes ]; then oldvpn2rxbytes=0; fi
    if [ -z $oldvpn2txbytes ]; then oldvpn2txbytes=0; fi

    if [ $oldvpn2rxbytes -le 0 ]; then
      oldvpn2rxbytes=0
    elif [ $oldvpn2txbytes -le 0 ]; then
      oldvpn2txbytes=0
    fi
  fi

  if [ "$vpn3on" == "True" ]; then
    oldvpn3txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client$vpn3slot/status 2>/dev/null)
    oldvpn3rxbytes="$(echo $oldvpn3txrxbytes | cut -d' ' -f1)"
    oldvpn3txbytes="$(echo $oldvpn3txrxbytes | cut -d' ' -f2)"
    if [ -z $oldvpn3rxbytes ]; then oldvpn3rxbytes=0; fi
    if [ -z $oldvpn3txbytes ]; then oldvpn3txbytes=0; fi

    if [ $oldvpn3rxbytes -le 0 ]; then
      oldvpn3rxbytes=0
    elif [ $oldvpn3txbytes -le 0 ]; then
      oldvpn3txbytes=0
    fi
  fi

  if [ "$vpn4on" == "True" ]; then
    oldvpn4txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client$vpn4slot/status 2>/dev/null)
    oldvpn4rxbytes="$(echo $oldvpn4txrxbytes | cut -d' ' -f1)"
    oldvpn4txbytes="$(echo $oldvpn4txrxbytes | cut -d' ' -f2)"
    if [ -z $oldvpn4rxbytes ]; then oldvpn4rxbytes=0; fi
    if [ -z $oldvpn4txbytes ]; then oldvpn4txbytes=0; fi

    if [ $oldvpn4rxbytes -le 0 ]; then
      oldvpn4rxbytes=0
    elif [ $oldvpn4txbytes -le 0 ]; then
      oldvpn4txbytes=0
    fi
  fi

  if [ "$vpn5on" == "True" ]; then
    oldvpn5txrxbytes=$(awk -F',' '1 == /TUN\/TAP read bytes/ {print $2} 1 == /TUN\/TAP write bytes/ {print $2}' /tmp/etc/openvpn/client$vpn5slot/status 2>/dev/null)
    oldvpn5rxbytes="$(echo $oldvpn5txrxbytes | cut -d' ' -f1)"
    oldvpn5txbytes="$(echo $oldvpn5txrxbytes | cut -d' ' -f2)"
    if [ -z $oldvpn5rxbytes ]; then oldvpn5rxbytes=0; fi
    if [ -z $oldvpn5txbytes ]; then oldvpn5txbytes=0; fi

    if [ $oldvpn5rxbytes -le 0 ]; then
      oldvpn5rxbytes=0
    elif [ $oldvpn5txbytes -le 0 ]; then
      oldvpn5txbytes=0
    fi
  fi

  # Check the wireguard connections
  if [ "$wg1on" == "True" ]; then
    oldwg1txrxbytes=$(wg show wgc1 transfer)
    oldwg1rxbytes="$(echo $oldwg1txrxbytes | cut -d' ' -f3)"
    oldwg1txbytes="$(echo $oldwg1txrxbytes | cut -d' ' -f2)"
    if [ -z $oldwg1rxbytes ] || [ $oldwg1rxbytes -le 0 ]; then oldwg1rxbytes=0; fi
    if [ -z $oldwg1txbytes ] || [ $oldwg1txbytes -le 0 ]; then oldwg1txbytes=0; fi
  fi

  if [ "$wg2on" == "True" ]; then
    oldwg2txrxbytes=$(wg show wgc2 transfer)
    oldwg2rxbytes="$(echo $oldwg2txrxbytes | cut -d' ' -f3)"
    oldwg2txbytes="$(echo $oldwg2txrxbytes | cut -d' ' -f2)"
    if [ -z $oldwg2rxbytes ] || [ $oldwg2rxbytes -le 0 ]; then oldwg2rxbytes=0; fi
    if [ -z $oldwg2txbytes ] || [ $oldwg2txbytes -le 0 ]; then oldwg2txbytes=0; fi
  fi

  if [ "$wg3on" == "True" ]; then
    oldwg3txrxbytes=$(wg show wgc3 transfer)
    oldwg3rxbytes="$(echo $oldwg3txrxbytes | cut -d' ' -f3)"
    oldwg3txbytes="$(echo $oldwg3txrxbytes | cut -d' ' -f2)"
    if [ -z $oldwg3rxbytes ] || [ $oldwg3rxbytes -le 0 ]; then oldwg3rxbytes=0; fi
    if [ -z $oldwg3txbytes ] || [ $oldwg3txbytes -le 0 ]; then oldwg3txbytes=0; fi
  fi

  if [ "$wg4on" == "True" ]; then
    oldwg4txrxbytes=$(wg show wgc4 transfer)
    oldwg4rxbytes="$(echo $oldwg4txrxbytes | cut -d' ' -f3)"
    oldwg4txbytes="$(echo $oldwg4txrxbytes | cut -d' ' -f2)"
    if [ -z $oldwg4rxbytes ] || [ $oldwg4rxbytes -le 0 ]; then oldwg4rxbytes=0; fi
    if [ -z $oldwg4txbytes ] || [ $oldwg4txbytes -le 0 ]; then oldwg4txbytes=0; fi
  fi

  if [ "$wg5on" == "True" ]; then
    oldwg5txrxbytes=$(wg show wgc5 transfer)
    oldwg5rxbytes="$(echo $oldwg5txrxbytes | cut -d' ' -f3)"
    oldwg5txbytes="$(echo $oldwg5txrxbytes | cut -d' ' -f2)"
    if [ -z $oldwg5rxbytes ] || [ $oldwg5rxbytes -le 0 ]; then oldwg5rxbytes=0; fi
    if [ -z $oldwg5txbytes ] || [ $oldwg5txbytes -le 0 ]; then oldwg5txbytes=0; fi
  fi


  printf "${CGreen}\r                                         "
  printf "${CGreen}\r"

  # Run through the stats gathering loop based on the current interval
  RM_ELAPSED_TIME=0
  RM_START_TIME="$(date +%s)"

  ##----------------------------------------##
  ## Modified by Martinski W. [2024-Nov-05] ##
  ##----------------------------------------##
  timer=0
  lastTimerSec=0
  updateTimer=true
  pausedTimerEnabled=false
  pausedTimerDispStr=""

  # Main Loop #
  while [ "$timer" -lt "$Interval" ]
  do
      if "$updateTimer"
      then
          updateTimer=false
          timer="$((timer+1))"
          lastTimerSec="$(date +%s)"
          gettopstats "$timer"
      fi
      preparebar 46 "|"
      progressbaroverride "$timer" "$Interval" "" "s" "Standard"
      if [ "$timerReset" = "1" ] ; then timer="$Interval" ; fi

      ## Prevent repeatedly fast key presses from updating the timer ##
      [ "$(date +%s)" -gt "$lastTimerSec" ] && updateTimer=true
  done

  # Do a fresh round of stats and save them to the old stats for display purposes
  calculatestats
  oldstats
  clear

  if [ "$autorotate" = "1" ] && [ "$timer" -ge "$Interval" ]
  then
       if [ "$NextPage" = "1" ]; then NextPage=2 #DisplayPage2#
     elif [ "$NextPage" = "2" ]; then NextPage=3 #DisplayPage3#
     elif [ "$NextPage" = "3" ]; then NextPage=4 #DisplayPage4#
     elif [ "$NextPage" = "4" ]; then NextPage=5 #DisplayPage5#
     elif [ "$NextPage" = "5" ]; then NextPage=6 #DisplayPage6#
     elif [ "$NextPage" = "6" ]; then NextPage=7 #DisplayPage7#
     elif [ "$NextPage" = "7" ]; then NextPage=1 #DisplayPage1#
     fi
  fi

  prevHideOpts=X
  prevSortByOpt=X
done

_IgnoreKeypresses_ OFF

exit 0

#} #2>&1 | tee $LOG | logger -t $(basename $0)[$$]  # uncomment/comment to enable/disable debug mode
