#!/bin/sh

# RTRMON v1.21b3 - Asus-Merlin Router Monitor by Viktor Jaep, 2022
#
# RTRMON is a shell script that provides near-realtime stats about your Asus-Merlin firmware router. Instead of having to
# find this information on various different screens or apps, this tool was built to bring all this info together in one
# stat dashboard.  Having a 'system' dashboard showing current CPU, Memory, Disk and Network stats would compiment other
# dashboard-like scripts greatly (like RTRMON), sitting side-by-side in their own SSH windows to give you everything
# you need to know with a glance at your screen.
#
# Capabilities have been added to give a full view of your router's CPU, Memory, Disk, NVRAM, Swap file, WAN, LAN, W0, W1,
# IP4/6 addresses, CPU/Antenna Temps, with the latest addition having incorporated the Ookla Speedtest Binaries for you to
# run an on-demand Speedtest with the press of a button.
#
# Please use the 'rtrmon.sh -setup' to configure the necessary parameters that match your environment the best!
#
# -------------------------------------------------------------------------------------------------------------------------
# Shellcheck exclusions
# -------------------------------------------------------------------------------------------------------------------------
# shellcheck disable=SC2034
# shellcheck disable=SC3037
# shellcheck disable=SC2162
# shellcheck disable=SC3045
# shellcheck disable=SC2183
# shellcheck disable=SC2086
# shellcheck disable=SC3014
# shellcheck disable=SC2059
# shellcheck disable=SC2002
# shellcheck disable=SC2004
# shellcheck disable=SC3028
# shellcheck disable=SC2140
# shellcheck disable=SC3046
# shellcheck disable=SC1090
#
# -------------------------------------------------------------------------------------------------------------------------
# System Variables (Do not change beyond this point or this may change the programs ability to function correctly)
# -------------------------------------------------------------------------------------------------------------------------
Version="1.21b3"
Beta=1
LOGFILE="/jffs/addons/rtrmon.d/rtrmon.log"          # Logfile path/name that captures important date/time events - change
APPPATH="/jffs/scripts/rtrmon.sh"                   # Path to the location of rtrmon.sh
CFGPATH="/jffs/addons/rtrmon.d/rtrmon.cfg"          # Path to the location of rtrmon.cfg
DLVERPATH="/jffs/addons/rtrmon.d/version.txt"       # Path to downloaded version from the source repository
OOKLAPATH="/jffs/addons/rtrmon.d/speedtest"         # Path to Ookla speedtest binary
SPDRESPATH="/jffs/addons/rtrmon.d/results.txt"      # Path to latest speedtest results
IFLIST="/jffs/addons/rtrmon.d/interfaces.txt"       # Path to the Interface List
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

# Logo is a function that displays the RTRMON script name in a cool ASCII font
logo () {
  echo -e "${CYellow}      ____  __________  __  _______  _   __"
  echo -e "     / __ \/_  __/ __ \/  |/  / __ \/ | / /  ${CGreen}v$Version - ${CCyan}$RouterModel${CYellow}"
  echo -e "    / /_/ / / / / /_/ / /|_/ / / / /  |/ /  ${CRed}(S)${CGreen}etup${CYellow}"
  echo -e "   / _, _/ / / / _, _/ /  / / /_/ / /|  /   ${CRed}(N)${CGreen}ext Page ($NextPage/4)${CYellow}"
  echo -e "  /_/ |_| /_/ /_/ |_/_/  /_/\____/_/ |_/    ${CRed}(E)${CGreen}xit${CClear}"
}

# -------------------------------------------------------------------------------------------------------------------------

# LogoNM is a function that displays the RTRMON script name in a cool ASCII font without menu options
logoNM () {
  echo -e "${CYellow}      ____  __________  __  _______  _   __"
  echo -e "     / __ \/_  __/ __ \/  |/  / __ \/ | / /  ${CGreen}v$Version${CYellow}"
  echo -e "    / /_/ / / / / /_/ / /|_/ / / / /  |/ /"
  echo -e "   / _, _/ / / / _, _/ /  / / /_/ / /|  /"
  echo -e "  /_/ |_| /_/ /_/ |_/_/  /_/\____/_/ |_/${CClear}"
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
  # $6 - alternate display values
  # $7 - alternate value for progressbar exceeding 100%

  insertspc=" "

  if [ $1 -eq -1 ]; then
    printf "\r  $barspaces\r"
  else
    if [ ! -z $7 ] && [ $1 -ge $7 ]; then
      barch=$(($7*barlen/$2))
      barsp=$((barlen-barch))
      progr=$((100*$1/$2))
    else
      barch=$(($1*barlen/$2))
      barsp=$((barlen-barch))
      progr=$((100*$1/$2))
    fi

    if [ ! -z $6 ]; then AltNum=$6; else AltNum=$1; fi

    if [ "$5" == "Standard" ]; then
      if [ $progr -le 60 ]; then
        printf "${InvGreen}${CWhite}$insertspc${CClear}${CGreen}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      elif [ $progr -gt 60 ] && [ $progr -le 85 ]; then
        printf "${InvYellow}${CBlack}$insertspc${CClear}${CYellow}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      else
        printf "${InvRed}${CWhite}$insertspc${CClear}${CRed}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      fi
    elif [ "$5" == "Reverse" ]; then
      if [ $progr -le 35 ]; then
        printf "${InvRed}${CWhite}$insertspc${CClear}${CRed}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      elif [ $progr -gt 35 ] && [ $progr -le 85 ]; then
        printf "${InvYellow}${CBlack}$insertspc${CClear}${CYellow}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      else
        printf "${InvGreen}${CWhite}$insertspc${CClear}${CGreen}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      fi
    fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# converttemps is a function that converts temp readouts from C to F or K
converttemps () {
# $1 is the incoming C Temp

  if [ "$TempUnits" == "F" ]; then
    currenttemp=$(awk -v v1=$1 'BEGIN{printf "%0.2f\n", (v1*9)/5+32}' | cut -d . -f 1)
    currentrange=266
  elif [ "$TempUnits" == "K" ]; then
    currenttemp=$(awk -v v1=$1 'BEGIN{printf "%0.2f\n", v1+273}' | cut -d . -f 1)
    currentrange=403
  elif [ "$TempUnits" == "C" ]; then
    currenttemp=$1
    currentrange=130
  else
    # Default to C if someone entered something other than C, F or K
    TempUnits="C"
    currenttemp=$1
    currentrange=130
  fi

}

# -------------------------------------------------------------------------------------------------------------------------

# updatecheck is a function that downloads the latest update version file, and compares it with what's currently installed
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
        UpdateNotify="Update available: v$Version -> v$DLVersion"
        echo -e "$(date) - RTRMON - A new update (v$DLVersion) is available to download" >> $LOGFILE
      else
        UpdateNotify=0
      fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# vlogs is a function that calls the nano text editor to view the RTRMON log file
vlogs() {

export TERM=linux
nano $LOGFILE

}

# -------------------------------------------------------------------------------------------------------------------------

# vconfig is a function that guides you through the various configuration options for RTRMON
vconfig () {

  if [ -f $CFGPATH ]; then #Making sure file exists before proceeding
    source $CFGPATH

    while true; do
      clear
      logoNM
      echo ""
      echo -e "${CGreen}----------------------------------------------------------------"
      echo -e "${CGreen}Configuration Utility Options"
      echo -e "${CGreen}----------------------------------------------------------------"
      echo -e "${InvDkGray}${CWhite}  1 ${CClear}${CCyan}: Timer Interval (seconds)      :"${CGreen}$Interval
      echo -e "${InvDkGray}${CWhite}  2 ${CClear}${CCyan}: Max Internet D/L Speed (Mbps) :"${CGreen}$MaxSpeedInet
      echo -e "${InvDkGray}${CWhite}  3 ${CClear}${CCyan}: Max Internet U/L Speed (Mbps) :"${CGreen}$MaxSpeedInetUL
      echo -e "${InvDkGray}${CWhite}  4 ${CClear}${CCyan}: Max LAN Speed (Mbps)          :"${CGreen}$MaxSpeedLAN
      echo -e "${InvDkGray}${CWhite}  5 ${CClear}${CCyan}: Max 2.4Ghz Speed (Mbps)       :"${CGreen}$MaxSpeed24Ghz
      echo -e "${InvDkGray}${CWhite}  6 ${CClear}${CCyan}: Max 5Ghz Speed (Mbps)         :"${CGreen}$MaxSpeed5Ghz
      if [ "$AdvRouter" == "True" ]; then
        echo -e "${InvDkGray}${CWhite}  7 ${CClear}${CCyan}: Max 6Ghz Speed (Mbps)         :"${CGreen}$MaxSpeed6Ghz
      else
        echo -e "${InvDkGray}${CWhite}  7 ${CClear}${CDkGray}: Max 6Ghz Speed (Mbps)         :${CDkGray}N/A"
      fi
      echo -e "${InvDkGray}${CWhite}  8 ${CClear}${CCyan}: Temperature Units (C/F/K)     :"${CGreen}$TempUnits
      echo -en "${InvDkGray}${CWhite}  9 ${CClear}${CCyan}: Enable Ookla Speedtest? (Y/N) :"${CGreen}
      if [ "$Speedtst" == "0" ]; then
        printf "No"; printf "%s\n";
      else printf "Yes"; printf "%s\n"; fi
      echo -e "${InvDkGray}${CWhite} 10 ${CClear}${CCyan}: WAN0 Interface Override?      :"${CGreen}$WANOverride
      echo -e "${InvDkGray}${CWhite}  | ${CClear}"
      echo -e "${InvDkGray}${CWhite}  s ${CClear}${CCyan}: Save & Exit"
      echo -e "${InvDkGray}${CWhite}  e ${CClear}${CCyan}: Exit & Discard Changes"
      echo -e "${CGreen}----------------------------------------------------------------"
      echo ""
      printf "Selection: "
      read -r ConfigSelection

      # Execute chosen selections
          case "$ConfigSelection" in

            1) # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan}1. How many seconds would you like to use to refresh your stats?"
              echo -e "${CYellow}(Default = 10)${CClear}"
              read -p 'Interval (seconds): ' Interval1
              if [ -z "$Interval1" ]; then Interval=10; else Interval=$Interval1; fi
            ;;

            2) # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan}2. What is your maximum internet D/L bandwidth/speed in Mbps?"
              echo -e "${CYellow}(Default = 1000)${CClear}"
              read -p 'Max Internet D/L Speed (Mbps): ' MaxSpeedInet1
              if [ -z "$MaxSpeedInet1" ]; then MaxSpeedInet=50; else MaxSpeedInet=$MaxSpeedInet1; fi
            ;;

            3) # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan}3. What is your maximum internet U/L bandwidth/speed in Mbps?"
              echo -e "${CYellow}(Default = 50)${CClear}"
              read -p 'Max Internet U/L Speed (Mbps): ' MaxSpeedInetUL1
              if [ -z "$MaxSpeedInetUL1" ]; then MaxSpeedInetUL=50; else MaxSpeedInetUL=$MaxSpeedInetUL1; fi
            ;;

            4) # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan}4. What is your maximum LAN switch bandwidth/speed in Mbps?"
              echo -e "${CYellow}(Default = 1000)${CClear}"
              read -p 'Max LAN Speed (Mbps): ' MaxSpeedLAN1
              if [ -z "$MaxSpeedLAN1" ]; then MaxSpeedLAN=1000; else MaxSpeedLAN=$MaxSpeedLAN1; fi
            ;;

            5) # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan}5. What is your maximum realistic 2.4Ghz speed in Mbps?"
              echo -e "${CYellow}(Default = 450)${CClear}"
              read -p 'Max 2.4Ghz Speed (Mbps): ' MaxSpeed24Ghz1
              if [ -z "$MaxSpeed24Ghz1" ]; then MaxSpeed24Ghz=450; else MaxSpeed24Ghz=$MaxSpeed24Ghz1; fi
            ;;

            6) # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan}6. What is your maximum realistic 5Ghz speed in Mbps?"
              echo -e "${CYellow}(Default = 780)${CClear}"
              read -p 'Max 5Ghz Speed (Mbps): ' MaxSpeed5Ghz1
              if [ -z "$MaxSpeed5Ghz1" ]; then MaxSpeed5Ghz=780; else MaxSpeed5Ghz=$MaxSpeed5Ghz1; fi
            ;;

            7) # -----------------------------------------------------------------------------------------
              echo ""
              if [ $AdvRouter == "True" ]; then
                echo -e "${CCyan}7. What is your maximum realistic 6Ghz speed in Mbps?"
                echo -e "${CYellow}(Default = 920)${CClear}"
                read -p 'Max 6Ghz Speed (Mbps): ' MaxSpeed6Ghz1
                if [ -z "$MaxSpeed6Ghz1" ]; then MaxSpeed6Ghz=920; else MaxSpeed6Ghz=$MaxSpeed6Ghz1; fi
              else
                echo -e "${CRed}This item is currently only available for router"
                echo -e "${CRed}models: GT-AXE11000 and GT-AXE16000.  Exiting..."
                echo ""
                sleep 3
              fi
            ;;

            8) # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan}8. Which Temperature Units would you prefer? (C)elcius,"
              echo -e "${CCyan}(Fahrenheit) or (K)elvin?"
              echo -e "${CYellow}(Default = C)${CClear}"
              read -p 'Temp Units (C/F/K): ' TempUnits1
              TempUnits2=$(echo $TempUnits1 | tr '[a-z]' '[A-Z]')
              if [ -z "$TempUnits1" ]; then TempUnits="C"; else TempUnits=$TempUnits2; fi
            ;;

            9) # -----------------------------------------------------------------------------------------
              echo ""
              if [ -f $OOKLAPATH ]; then
                echo -e "${CCyan}9. Would you like to disable and uninstall the Ookla"
                echo -e "${CCyan}Speedtest binaries from RTRMON? (y/n)${CClear}"
                if promptyn "(y/n): "; then
                  echo ""
                  echo ""
                  echo -e "${CGreen}Removing Ookla Speedtest binaries...${CClear}"
                  rm "/jffs/addons/rtrmon.d/speedtest"
                  rm "/jffs/addons/rtrmon.d/speedtest.5"
                  rm "/jffs/addons/rtrmon.d/speedtest.md"
                  sleep 1
                  if [ ! -f $OOKLAPATH ]; then
                    echo ""
                    echo -e "${CGreen}Completed removing Ookla Speedtest binaries...${CClear}"
                    Speedtst=0
                    echo ""
                    read -rsp $'Press any key to continue...\n' -n1 key
                  else
                    echo ""
                    echo -e "${CRed}ERROR: Ookla Speedtest binaries were not removed...${CClear}"
                    echo -e "${CRed}Please manually resolve issue under /jffs/addons/rtrmon.d...${CClear}"
                    Speedtst=1
                    echo ""
                    read -rsp $'Press any key to continue...\n' -n1 key
                  fi
                else
                  echo ""
                  echo ""
                  echo -e "${CGreen}Canceling removing Ookla Speedtest binaries...${CClear}"
                  sleep 2
                fi

              else
                echo -e "${CCyan}9. Would you like to install and enable the Ookla"
                echo -e "${CCyan}Speedtest binaries for use with RTRMON? (y/n)${CClear}"
                echo -e ""
                echo -e "${CCyan}You may only use this Speedtest software and information"
                echo -e "${CCyan}generated from it for personal, non-commercial use,"
                echo -e "${CCyan}through a command line interface on a personal computer."
                echo -e "${CCyan}Your use of this software is subject to the End User"
                echo -e "${CCyan}License Agreement, Terms of Use and Privacy Policy at"
                echo -e "${CCyan}these URLs:"
                echo ""
                echo -e "${CCyan}  https://www.speedtest.net/about/eula"
                echo -e "${CCyan}  https://www.speedtest.net/about/terms"
                echo -e "${CCyan}  https://www.speedtest.net/about/privacy"
                echo ""
                echo -e "${CCyan}By typing 'y' below, you agree to these terms.${CClear}"
                if promptyn "(y/n): "; then
                  echo ""
                  echo ""
                  echo -e "${CGreen}Installing Ookla Speedtest binaries...${CClear}"
                  echo ""
                  if [ "$(uname -m)" = "aarch64" ]; then
                    curl --silent --retry 3 "https://install.speedtest.net/app/cli/ookla-speedtest-1.1.1-linux-aarch64.tgz" -o "/jffs/addons/rtrmon.d/spdtst64.tgz"
                    tar -zxf /jffs/addons/rtrmon.d/spdtst64.tgz -C /jffs/addons/rtrmon.d 2>/dev/null
                    chmod 0755 "/jffs/addons/rtrmon.d/speedtest"
                    rm /jffs/addons/rtrmon.d/spdtst64.tgz
                  else
                    curl --silent --retry 3 "https://install.speedtest.net/app/cli/ookla-speedtest-1.1.1-linux-armel.tgz" -o "/jffs/addons/rtrmon.d/spdtstel.tgz"
                    tar -zxf /jffs/addons/rtrmon.d/spdtstel.tgz -C /jffs/addons/rtrmon.d 2>/dev/null
                    chmod 0755 "/jffs/addons/rtrmon.d/speedtest"
                    rm /jffs/addons/rtrmon.d/spdtstel.tgz
                  fi
                  if [ -f /jffs/addons/rtrmon.d/speedtest ]; then
                    echo -e "${CGreen}Ookla Speedtest binaries installed successfully...${CClear}"
                    Speedtst=1
                    echo ""
                    read -rsp $'Press any key to continue...\n' -n1 key
                  else
                    echo -e "${CRed}ERROR: Ookla Speedtest binaries install failed...${CClear}"
                    Speedtst=0
                    echo ""
                    read -rsp $'Press any key to continue...\n' -n1 key
                  fi
                else
                  echo ""
                  echo ""
                  echo -e "${CGreen}Canceling install of Ookla Speedtest binaries...${CClear}"
                  Speedtst=0
                  sleep 2
                fi
              fi
            ;;

            10) # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan}10. Would you like to override the default interface assigned${CClear}"
              echo -e "${CCyan}to your local WAN0? Typically, 'eth0' is assigned to WAN0, but${CClear}"
              echo -e "${CCyan}based on how you've rigged your router, it might be something${CClear}"
              echo -e "${CCyan}else. By default, RTRMON will automatically try to determine${CClear}"
              echo -e "${CCyan}the correct interface, however this will give you the option${CClear}"
              echo -e "${CCyan}to override it should you be using something else.${CClear}"
              echo ""
              echo -e "${CGreen}Valid interface choices:"

              ip -br link | LC_ALL=C awk '$2 == "UP" {print $1}' > $IFLIST # Extract all valid interfaces to a text file

              LINES=$(cat $IFLIST | wc -l) #Check to see how many lines are in this file

              echo -e "${CGreen}0) Auto"

              i=0 # Populate all other numbered choices
              while [ $i -ne $LINES ]
                do
                  i=$(($i+1))
                  InterfaceName=$(sed -n "${i}p" $IFLIST)
                  echo -e "$i) $InterfaceName"
                done

              echo -e "${CClear}"
              echo -e "${CYellow}(Default = 0 (Auto), or choose one of the above)${CClear}"

              while true
                do
                  read -p 'Choose Interface #: ' ChooseInterface

                  case ${ChooseInterface#[-+]} in # Make sure we're only picking an item from the list
                    *[!0-9]* | '') echo ""; echo -e "${CRed}ERROR: Please make a valid selection${CClear}"; echo "" ;;
                    * ) if [ $ChooseInterface -lt 0 ] || [ $ChooseInterface -gt $LINES ]; then echo ""; echo -e "${CRed}Please make a valid selection${CClear}"; echo ""; else break; fi ;;
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
                echo 'WANOverride="'"$WANOverride"'"'
              } > $CFGPATH
              echo ""
              echo -e "${CGreen}Please restart RTRMON to apply your changes..."
              echo -e "$(date) - RTRMON - Successfully wrote a new config file" >> $LOGFILE
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
        echo 'WANOverride="Auto"'
      } > $CFGPATH

      #Re-run rtrmon -config to restart setup process
      vconfig

  fi

}

# -------------------------------------------------------------------------------------------------------------------------

# vuninstall is a function that uninstalls and removes all traces of RTRMON from your router...
vuninstall () {
  clear
  logoNM
  echo ""
  echo -e "${CYellow}Uninstall Utility${CClear}"
  echo ""
  echo -e "${CCyan}You are about to uninstall RTRMON!  This action is irreversible."
  echo -e "${CCyan}Do you wish to proceed?${CClear}"
  if promptyn "(y/n): "; then
    echo ""
    echo -e "\n${CCyan}Are you sure? Please type 'Y' to validate you want to proceed.${CClear}"
      if promptyn "(y/n): "; then
        clear
        rm -r /jffs/addons/rtrmon.d
        rm /jffs/scripts/rtrmon.sh
        echo ""
        echo -e "\n${CGreen}RTRMON has been uninstalled...${CClear}"
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
      echo -e "${CGreen}No update available.  You are on the latest version!${CClear}"
      echo ""
      read -rsp $'Press any key to continue...\n' -n1 key
      return
    else
      echo -e "${CCyan}Would you like to update to the latest version?${CClear}"
      if promptyn "(y/n): "; then
        echo ""
        echo -e "${CCyan}Updating RTRMON to ${CYellow}v$DLVersion${CClear}"
        curl --silent --retry 3 "https://raw.githubusercontent.com/ViktorJp/RTRMON/master/rtrmon-$DLVersion.sh" -o "/jffs/scripts/rtrmon.sh" && chmod a+rx "/jffs/scripts/rtrmon.sh"
        echo ""
        echo -e "${CCyan}Update successful!${CClear}"
        echo -e "$(date) - RTRMON - Successfully updated RTRMON from v$Version to v$DLVersion" >> $LOGFILE
        echo ""
        echo -e "${CYellow}Please exit, restart and configure new options using: 'rtrmon.sh -config'.${CClear}"
        echo -e "${CYellow}NOTE: New features may have been added that require your input to take${CClear}"
        echo -e "${CYellow}advantage of its full functionality.${CClear}"
        echo ""
        read -rsp $'Press any key to continue...\n' -n1 key
        return
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

# vsetup is a function that sets up, confiures and allows you to launch RTRMON on your router...
vsetup () {

  # Check for and add an alias for RTRMON
  if ! grep -F "sh /jffs/scripts/rtrmon.sh" /jffs/configs/profile.add; then
		echo "alias rtrmon=\"sh /jffs/scripts/rtrmon.sh\" # RTRMON" >> /jffs/configs/profile.add
  fi

  while true; do
    clear
    logoNM
    echo ""
    echo -e "${CYellow}Setup Utility${CClear}" # Provide main setup menu
    echo ""
    echo -e "${CGreen}----------------------------------------------------------------"
    echo -e "${CGreen}Operations"
    echo -e "${CGreen}----------------------------------------------------------------"
    echo -e "${InvDkGray}${CWhite} sc ${CClear}${CCyan}: Setup and Configure RTRMON"
    echo -e "${InvDkGray}${CWhite} fr ${CClear}${CCyan}: Force Re-install Entware Dependencies"
    echo -e "${InvDkGray}${CWhite} up ${CClear}${CCyan}: Check for latest updates"
    echo -e "${InvDkGray}${CWhite} vl ${CClear}${CCyan}: View logs"
    echo -e "${InvDkGray}${CWhite} un ${CClear}${CCyan}: Uninstall"
    echo -e "${InvDkGray}${CWhite}  e ${CClear}${CCyan}: Exit"
    echo -e "${CGreen}----------------------------------------------------------------"
    if [ "$FromUI" == "0" ]; then
      echo -e "${CGreen}Launch"
      echo -e "${CGreen}----------------------------------------------------------------"
      echo -e "${InvDkGray}${CWhite} m1 ${CClear}${CCyan}: Launch RTRMON into Normal Monitoring Mode"
      echo -e "${InvDkGray}${CWhite} m2 ${CClear}${CCyan}: Launch RTRMON into Normal Monitoring Mode w/ Screen"
      echo -e "${CGreen}----------------------------------------------------------------"
    fi
    echo ""
    printf "Selection: "
    read -r InstallSelection

    # Execute chosen selections
        case "$InstallSelection" in

          sc) # Check for existence of entware, and if so proceed and install the timeout package, then run RTRMON -config
            clear
            if [ -f "/opt/bin/timeout" ] && [ -f "/opt/sbin/screen" ]; then
              vconfig
            else
              logoNM
              echo -e "${CYellow}Installing RTRMON...${CClear}"
              echo ""
              echo -e "${CCyan}Would you like to optionally install the CoreUtils-Timeout${CClear}"
              echo -e "${CCyan}and Screen utility? These utilities require you to have Entware${CClear}"
              echo -e "${CCyan}already installed using the AMTM tool. If Entware is present, the ${CClear}"
              echo -e "${CCyan}Timeout and Screen utilities will be downloaded and installed during${CClear}"
              echo -e "${CCyan}this setup process, and used by RTRMON.${CClear}"
              echo ""
              echo -e "${CGreen}CoreUtils-Timeout${CCyan} is a utility that provides more stability for${CClear}"
              echo -e "${CCyan}certain routers (like the RT-AC86U) which has a tendency to randomly${CClear}"
              echo -e "${CCyan}hang scripts running on this router model.${CClear}"
              echo ""
              echo -e "${CGreen}Screen${CCyan} is a utility that allows you to run SSH scripts in a standalone"
              echo -e "${CCyan}environment directly on the router itself, instead of running your"
              echo -e "${CCyan}commands or a script from a network-attached SSH client. This can"
              echo -e "${CCyan}provide greater stability due to it running from the router itself."
              echo ""
              [ -z "$(nvram get odmpid)" ] && RouterModel="$(nvram get productid)" || RouterModel="$(nvram get odmpid)" # Thanks @thelonelycoder for this logic
              echo -e "${CCyan}Your router model is: ${CYellow}$RouterModel"
              echo ""
              echo -e "${CCyan}Install?${CClear}"
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
                    echo -e "${CGreen}Installing Entware Screen Package...${CClear}"
                    echo ""
                    opkg install screen
                    echo ""
                    sleep 1
                    echo -e "${CGreen}Executing RTRMON Configuration Utility...${CClear}"
                    sleep 2
                    vconfig
                  else
                    clear
                    echo -e "${CGreen}ERROR: Entware was not found on this router...${CClear}"
                    echo -e "${CGreen}Please install Entware using the AMTM utility before proceeding...${CClear}"
                    echo ""
                    sleep 3
                  fi
                else
                  echo ""
                  echo -e "\n${CGreen}Executing RTRMON Configuration Utility...${CClear}"
                  sleep 2
                  vconfig
              fi
            fi
          ;;


          fr) # Force re-install the CoreUtils timeout/screen package
            clear
            logoNM
            echo ""
            echo -e "${CYellow}Force Re-installing CoreUtils-Timeout/Screen Packages...${CClear}"
            echo ""
            echo -e "${CCyan}Would you like to optionally re-install the CoreUtils-Timeout${CClear}"
            echo -e "${CCyan}and Screen utility? These utilities require you to have Entware${CClear}"
            echo -e "${CCyan}already installed using the AMTM tool. If Entware is present, the ${CClear}"
            echo -e "${CCyan}Timeout and Screen utilities will be downloaded and installed during${CClear}"
            echo -e "${CCyan}this setup process, and used by RTRMON.${CClear}"
            echo ""
            echo -e "${CGreen}CoreUtils-Timeout${CCyan} is a utility that provides more stability for${CClear}"
            echo -e "${CCyan}certain routers (like the RT-AC86U) which has a tendency to randomly${CClear}"
            echo -e "${CCyan}hang scripts running on this router model.${CClear}"
            echo ""
            echo -e "${CGreen}Screen${CCyan} is a utility that allows you to run SSH scripts in a standalone"
            echo -e "${CCyan}environment directly on the router itself, instead of running your"
            echo -e "${CCyan}commands or a script from a network-attached SSH client. This can"
            echo -e "${CCyan}provide greater stability due to it running from the router itself."
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
                  echo -e "${CGreen}Force Re-installing Entware Screen Package...${CClear}"
                  echo ""
                  opkg install --force-reinstall screen
                  echo ""
                  echo -e "${CGreen}Re-install completed...${CClear}"
                  sleep 2
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

          m1)
            echo ""
            echo -e "\n${CGreen}Launching RTRMON into Monitor Mode...${CClear}"
            sleep 2
            sh $APPPATH -monitor
          ;;

          m2)
            echo ""
            echo -e "\n${CGreen}Launching RTRMON into Monitor Mode with Screen Utility...${CClear}"
            sleep 2
            sh $APPPATH -screen
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

if [ "$INITIALBOOT" == "0" ]; then
  # Borrowed this wonderful keypress capturing mechanism from @Eibgrad... thank you! :)
  key_press=''; read -rsn1 -t 1 key_press < "$(tty 0>&2)"

  if [ $key_press ]; then
      case $key_press in
          [Ss]) FromUI=1; (vsetup); echo -e "${CGreen}  [Returning to the Main UI momentarily]                                   "; FromUI=0;;
          [Ii]) QueueSpdtst=1; echo -e "${CGreen}  [Queuing Speedtest]                                                      ";;
          [Nn]) if [ "$NextPage" == "1" ]; then NextPage=2; clear; DisplayPage2; echo -e "\n"; elif [ "$NextPage" == "2" ]; then NextPage=3; clear; DisplayPage3; echo -e "\n"; elif [ "$NextPage" == "3" ]; then NextPage=4; clear; DisplayPage4; echo -e "\n"; elif [ "$NextPage" == "4" ]; then NextPage=1; clear; DisplayPage1; echo -e "\n"; fi;;
          [Ee]) echo -e "${CClear}"; exit 0;;
      esac
  fi
else
  sleep 1
fi
}

# -------------------------------------------------------------------------------------------------------------------------

# oldstats holds the old (current) stats that are being used to display stats on-screen
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
  oldwan0ip=$wan0ip
  oldwan1ip=$wan1ip
  olddns1ip=$dns1ip
  olddns2ip=$dns2ip
  oldwanip6=$wanip6
  oldlanip6=$lanip6
  oldwanrxmbrate=$wanrxmbrate
  oldwantxmbrate=$wantxmbrate
  oldw24rxmbrate=$w24rxmbrate
  oldw24txmbrate=$w24txmbrate
  oldw5rxmbrate=$w5rxmbrate
  oldw5txmbrate=$w5txmbrate
  oldw24temp=$w24temp
  oldw5temp=$w5temp
  if [ $AdvRouter == "True" ]; then
    oldw52rxmbrate=$w52rxmbrate
    oldw52txmbrate=$w52txmbrate
    oldw6rxmbrate=$w6rxmbrate
    oldw6txmbrate=$w6txmbrate
    oldw52temp=$w52temp
    oldw6temp=$w6temp
  fi
  oldlanip=$lanip
  oldlanrxmbrate=$lanrxmbrate
  oldlantxmbrate=$lantxmbrate
  oldwanrxmbratedisplay=$wanrxmbratedisplay
  oldwantxmbratedisplay=$wantxmbratedisplay
  oldw24rxmbratedisplay=$w24rxmbratedisplay
  oldw24txmbratedisplay=$w24txmbratedisplay
  oldw5rxmbratedisplay=$w5rxmbratedisplay
  oldw5txmbratedisplay=$w5txmbratedisplay
  if [ $AdvRouter == "True" ]; then
    oldw52rxmbratedisplay=$w52rxmbratedisplay
    oldw52txmbratedisplay=$w52txmbratedisplay
    oldw6rxmbratedisplay=$w6rxmbratedisplay
    oldw6txmbratedisplay=$w6txmbratedisplay
  fi
  oldlanrxmbratedisplay=$lanrxmbratedisplay
  oldlantxmbratedisplay=$lantxmbratedisplay
}

# -------------------------------------------------------------------------------------------------------------------------

# calculatestats calculates and captures, well, all the current stats from their sources  ;)
calculatestats () {

  RM_END_TIME=$(date +%s)
  RM_ELAPSED_TIME=$(( RM_END_TIME - RM_START_TIME ))

  # Router Model
  if [ $AdvRouter == "True" ]; then
    ifname24=$($timeoutcmd$timeoutsec nvram get wl3_ifname)
    ifname5=$($timeoutcmd$timeoutsec nvram get wl0_ifname)
    ifname52=$($timeoutcmd$timeoutsec nvram get wl1_ifname)
    ifname6=$($timeoutcmd$timeoutsec nvram get wl2_ifname)
  else
    ifname24=$($timeoutcmd$timeoutsec nvram get wl0_ifname)
    ifname5=$($timeoutcmd$timeoutsec nvram get wl1_ifname)
  fi

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
   if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
     F_cputemp=$($timeoutcmd$timeoutsec cat /sys/class/thermal/thermal_zone0/temp | cut -c -2)
   elif [ -f /proc/dmu/temperature ]; then # Thanks to PeterR for the bug report on AC68U's - hopefully this will fix that
     F_cputemp=$($timeoutcmd$timeoutsec cat /proc/dmu/temperature | cut -c19-20)
   fi

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
    eval "$($timeoutcmd$timeoutsec nvram show >/tmp/output.txt 2> /tmp/size.txt)"
    chmod 755 /tmp/size.txt
    nvramtotals=$(awk '{print $2, $4}' /tmp/size.txt 2>/dev/null)
    nvramused="$(echo $nvramtotals | awk '{print $1}')"
    nvramfree="$(echo $nvramtotals | awk '{print $2}' | sed 's/[)(]//g')"
    if [ -z $nvramused ] || [ -z $nvramfree ]; then
      nvramused=10000 # incase the values coming back from this file are blank, use temporary fillers
      totalnvram=20000
    else
      totalnvram=$(($nvramused + $nvramfree))
    fi

  # Disk - JFFS
    disk_use=$($timeoutcmd$timeoutsec df -P | grep -E '/jffs' | awk '{print $2, $3}')
    jffstotal="$(echo $disk_use | awk '{print $1}')"
    jffsused="$(echo $disk_use | awk '{print $2}')"
    jffstotal="$(($jffstotal / 1024))"
    jffsused="$(($jffsused / 1024))"

  # Disk - Swap file
    swap_use=$($timeoutcmd$timeoutsec free | awk 'NR==4 {print $2, $3}' 2>/dev/null)
    swaptotal="$(echo $swap_use | awk '{print $1}')"
    swapused="$(echo $swap_use | awk '{print $2}')"
    swaptotal="$(($swaptotal / 1024))"
    swapused="$(($swapused / 1024))"
    if [ $swaptotal == "0" ]; then swaptotal=100; fi

  # Network - WAN/LAN/DNS IP Addresses
    wan0ip=$($timeoutcmd$timeoutsec nvram get wan0_ipaddr)
    wan1ip=$($timeoutcmd$timeoutsec nvram get wan1_ipaddr)
    lanip=$($timeoutcmd$timeoutsec nvram get lan_ipaddr)
    dns1ip="$($timeoutcmd$timeoutsec nvram get wan0_dns | awk '{print $1}')"
    dns2ip="$($timeoutcmd$timeoutsec nvram get wan0_dns | awk '{print $2}')"
    dns3ip="$($timeoutcmd$timeoutsec nvram get wan1_dns | awk '{print $1}')"
    dns4ip="$($timeoutcmd$timeoutsec nvram get wan1_dns | awk '{print $2}')"

    if [ -z $wan0ip ]; then dns1ip="0.0.0.0"; fi
    if [ -z $wan1ip ]; then dns1ip="0.0.0.0"; fi
    if [ -z $lanip ]; then dns1ip="0.0.0.0"; fi
    if [ -z $dns1ip ]; then dns1ip="0.0.0.0"; fi
    if [ -z $dns2ip ]; then dns2ip="0.0.0.0"; fi
    if [ $dns1ip == "0.0.0.0" ] && [ ! -z $dns3ip ]; then dns1ip=$dns3ip; fi
    if [ $dns2ip == "0.0.0.0" ] && [ ! -z $dns4ip ]; then dns2ip=$dns4ip; fi

    # Many thanks to @SomewhereOverTheRainbow for his help and suggestions on getting IP6 info!
    wanip6="$(ip -o -6 addr list "$WANIFNAME" scope global | awk 'NR==1{ split($4, ip_addr, "/"); print ip_addr[1] }')"
    lanip6="$(ip -o -6 addr list br0 scope global | awk 'NR==1{ split($4, ip_addr, "/"); print ip_addr[1] }')"

  # Network - Wifi - Temp
    if [ $AdvRouter = "True" ]; then
      w24tempraw=$($timeoutcmd$timeoutsec wl -i $ifname24 phy_tempsense | awk '{print $1}' )
      w5tempraw=$($timeoutcmd$timeoutsec wl -i $ifname5 phy_tempsense | awk '{print $1}' )
      w52tempraw=$($timeoutcmd$timeoutsec wl -i $ifname52 phy_tempsense | awk '{print $1}' )
      w6tempraw=$($timeoutcmd$timeoutsec wl -i $ifname6 phy_tempsense | awk '{print $1}' )
      if [ -z $w24tempraw ] || [ $w24tempraw -eq 0 ]; then w24tempraw=4; fi  #in case it does not return a valid number
      if [ -z $w5tempraw ] || [ $w5tempraw -eq 0 ]; then w5tempraw=4; fi
      if [ -z $w52tempraw ] || [ $w52tempraw -eq 0 ]; then w52tempraw=4; fi
      if [ -z $w6tempraw ] || [ $w6tempraw -eq 0 ]; then w6tempraw=4; fi
      w24temp=$(awk -v v1=$w24tempraw 'BEGIN{printf "\n" (v1/2)+20}' | cut -d . -f 1)
      w5temp=$(awk -v v1=$w5tempraw 'BEGIN{printf "\n" (v1/2)+20}' | cut -d . -f 1)
      w52temp=$(awk -v v1=$w52tempraw 'BEGIN{printf "\n" (v1/2)+20}' | cut -d . -f 1)
      w6temp=$(awk -v v1=$w6tempraw 'BEGIN{printf "\n" (v1/2)+20}' | cut -d . -f 1)
    else
      w24tempraw=$($timeoutcmd$timeoutsec wl -i $ifname24 phy_tempsense | awk '{print $1}' )
      w5tempraw=$($timeoutcmd$timeoutsec wl -i $ifname5 phy_tempsense | awk '{print $1}' )
      if [ -z $w24tempraw ] || [ $w24tempraw -eq 0 ]; then w24tempraw=4; fi  #in case it does not return a valid number
      if [ -z $w5tempraw ] || [ $w5tempraw -eq 0 ]; then w5tempraw=4; fi
      w24temp=$(awk -v v1=$w24tempraw 'BEGIN{printf "\n" (v1/2)+20}' | cut -d . -f 1)
      w5temp=$(awk -v v1=$w5tempraw 'BEGIN{printf "\n" (v1/2)+20}' | cut -d . -f 1)
    fi

  # Network - Wifi - Traffic
    if [ $AdvRouter = "True" ]; then
      new24rxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname24/statistics/rx_bytes)"
      new24txbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname24/statistics/tx_bytes)"
      new5rxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname5/statistics/rx_bytes)"
      new5txbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname5/statistics/tx_bytes)"
      new52rxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname52/statistics/rx_bytes)"
      new52txbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname52/statistics/tx_bytes)"
      new6rxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname6/statistics/rx_bytes)"
      new6txbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname6/statistics/tx_bytes)"
    else
      new24rxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname24/statistics/rx_bytes)"
      new24txbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname24/statistics/tx_bytes)"
      new5rxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname5/statistics/rx_bytes)"
      new5txbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname5/statistics/tx_bytes)"
    fi

  # Network - LAN - Traffic
    newlanrxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/br0/statistics/rx_bytes)"
    newlantxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/br0/statistics/tx_bytes)"

  # Network - WAN - Traffic
    if [ $WANOverride == "Auto" ]; then WANIFNAME=$(get_wan_setting ifname); else WANIFNAME=$WANOverride; fi
    newwanrxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$WANIFNAME/statistics/rx_bytes)"
    newwantxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$WANIFNAME/statistics/tx_bytes)"

  # Network - Traffic - Calculations to find the difference between old and new total bytes send/received and divided to give Megabits
    diffwanrxbytes=$(awk -v new=$newwanrxbytes -v old=$oldwanrxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    diffwantxbytes=$(awk -v new=$newwantxbytes -v old=$oldwantxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    diff24rxbytes=$(awk -v new=$new24rxbytes -v old=$old24rxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    diff24txbytes=$(awk -v new=$new24txbytes -v old=$old24txbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    diff5rxbytes=$(awk -v new=$new5rxbytes -v old=$old5rxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    diff5txbytes=$(awk -v new=$new5txbytes -v old=$old5txbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    difflanrxbytes=$(awk -v new=$newlanrxbytes -v old=$oldlanrxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    difflantxbytes=$(awk -v new=$newlantxbytes -v old=$oldlantxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    if [ $AdvRouter = "True" ]; then
      diff52rxbytes=$(awk -v new=$new52rxbytes -v old=$old52rxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
      diff52txbytes=$(awk -v new=$new52txbytes -v old=$old52txbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
      diff6rxbytes=$(awk -v new=$new6rxbytes -v old=$old6rxbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
      diff6txbytes=$(awk -v new=$new6txbytes -v old=$old6txbytes -v mb=125000 'BEGIN{printf "%.4f\n", (new-old)/mb}')
    fi

  # Network - Traffic - Results are further divided by the timer/interval to give Megabits/sec
    wanrxmbrate=$(awk -v rb=$diffwanrxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
    wantxmbrate=$(awk -v tb=$diffwantxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    w24rxmbrate=$(awk -v rb=$diff24rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
    w24txmbrate=$(awk -v tb=$diff24txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    w5rxmbrate=$(awk -v rb=$diff5rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
    w5txmbrate=$(awk -v tb=$diff5txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    lanrxmbrate=$(awk -v rb=$difflanrxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
    lantxmbrate=$(awk -v tb=$difflantxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    if [ $AdvRouter = "True" ]; then
      w52rxmbrate=$(awk -v rb=$diff52rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
      w52txmbrate=$(awk -v tb=$diff52txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
      w6rxmbrate=$(awk -v rb=$diff6rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
      w6txmbrate=$(awk -v tb=$diff6txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    fi

    wanrxmbratedisplay=$(awk -v rb=$diffwanrxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
    wantxmbratedisplay=$(awk -v tb=$diffwantxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
    w24rxmbratedisplay=$(awk -v rb=$diff24rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
    w24txmbratedisplay=$(awk -v tb=$diff24txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
    w5rxmbratedisplay=$(awk -v rb=$diff5rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
    w5txmbratedisplay=$(awk -v tb=$diff5txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
    lanrxmbratedisplay=$(awk -v rb=$difflanrxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
    lantxmbratedisplay=$(awk -v tb=$difflantxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
    if [ $AdvRouter = "True" ]; then
      w52rxmbratedisplay=$(awk -v rb=$diff52rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
      w52txmbratedisplay=$(awk -v tb=$diff52txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
      w6rxmbratedisplay=$(awk -v rb=$diff6rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", rb/intv}')
      w6txmbratedisplay=$(awk -v tb=$diff6txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.1f\n", tb/intv}')
    fi

  # Uptime calc
    uptime=$(awk '{printf("%03dd %02dh %02dm %02ds\n",($1/60/60/24),($1/60/60%24),($1/60%60),($1%60))}' /proc/uptime)
}

# -------------------------------------------------------------------------------------------------------------------------

# This function displays speedtest results and runs new speedtest
DisplaySpdtst () {

  if [ "$Speedtst" == "0" ] || [ ! -f $OOKLAPATH ]; then
    echo -e "${CRed}  [Ookla Speedtest is not installed/configured]${CClear}"
    return
  fi

  # Check to see if previous results are available to display
  if [ -f $SPDRESPATH ]; then
    source $SPDRESPATH
  else
    SpdDate="No previous results found"
    SpdServer="Press 'I' to Initiate a Speedtest"
    SpdLatency=0
    SpdJitter=0
    SpdPacketLoss=0
    SpdDownload=0
    SpdUpload=0
  fi

  if [ "$QueueSpdtst" == "1" ]; then
  #run speedtest and save Results
    printf "${CGreen}\r  [Initializing Speedtest]"
    speed="$(/jffs/addons/rtrmon.d/speedtest --format=csv --interface=$WANIFNAME --accept-license --accept-gdpr)"
    SpdDate=$(date)
    SpdServer=$(echo $speed | awk -F '","' 'NR==1 {print $1}' | sed -e 's/^"//' -e 's/"$//')
    SpdLatency=$(echo $speed | awk -F '","' 'NR==1 {print $3}' | sed -e 's/^"//' -e 's/"$//')
    SpdJitter=$(echo $speed | awk -F '","' 'NR==1 {print $4}' | sed -e 's/^"//' -e 's/"$//')
    SpdPacketLoss=$(echo $speed | awk -F '","' 'NR==1 {print $5}' | sed -e 's/^"//' -e 's/"$//')
    SpdDownload=$(echo $speed | awk -F '","' 'NR==1 {print $6}' | sed -e 's/^"//' -e 's/"$//')
    SpdUpload=$(echo $speed | awk -F '","' 'NR==1 {print $7}' | sed -e 's/^"//' -e 's/"$//')

    { echo 'SpdDate="'"$SpdDate"'"'
      echo 'SpdServer="'"$SpdServer"'"'
      echo 'SpdLatency='$SpdLatency
      echo 'SpdJitter='$SpdJitter
      echo 'SpdPacketLoss='$SpdPacketLoss
      echo 'SpdDownload='$SpdDownload
      echo 'SpdUpload='$SpdUpload
    } > $SPDRESPATH
    printf "${CGreen}\r"
    QueueSpdtst=0
  fi

  # Display previous results
  if [ $SpdDownload -eq 0 ]; then SpdDownload=1; fi
  if [ $SpdUpload -eq 0 ]; then SpdUpload=1; fi

  SpdDownload=$(awk -v down=$SpdDownload -v mb=125000 'BEGIN{printf "%.0f\n", down/mb}')
  SpdUpload=$(awk -v up=$SpdUpload -v mb=125000 'BEGIN{printf "%.0f\n", up/mb}')

  #if [ $SpdDownload -gt $MaxSpeedInet ]; then SpdDownload=$MaxSpeedInet; fi
  #if [ $SpdUpload -gt $MaxSpeedInetUL ]; then SpdUpload=$MaxSpeedInetUL; fi

  #SpdServer="Your Local Test Server name/location"
  echo -e "${InvGreen} ${CClear} ${CRed}(I)${CGreen}nitiate Speedtest${CClear}"
  echo ""
  echo -e "${InvCyan} ${CClear} ${CCyan}Date       ${CGreen}[ ${CCyan}$SpdDate${CClear}"
  echo -e "${InvCyan} ${CClear} ${CCyan}Server     ${CGreen}[ ${CCyan}$SpdServer${CClear}"
  echo ""
  echo -e "${InvCyan} ${CClear} ${CCyan}Latency    ${CGreen}[ ${CCyan}$SpdLatency (ms)${CClear}"
  echo -e "${InvCyan} ${CClear} ${CCyan}Jitter     ${CGreen}[ ${CCyan}$SpdJitter (ms)${CClear}"
  echo -e "${InvCyan} ${CClear} ${CCyan}PacketLoss ${CGreen}[ ${CCyan}$SpdPacketLoss (%)${CClear}"
  echo ""
  echo -e "${InvCyan} ${CClear} ${CCyan}Download   ${CGreen}[ ${CCyan}$SpdDownload (Mbps)${CClear}"
  echo -e "${InvCyan} ${CClear} ${CCyan}Upload     ${CGreen}[ ${CCyan}$SpdUpload (Mbps)${CClear}"
  echo ""
  preparebar 35 "|"
  progressbar $SpdDownload $MaxSpeedInet " DL vs WAN " "Mbps" "Reverse" $SpdDownload $MaxSpeedInet
  echo ""
  preparebar 35 "|"
  progressbar $SpdUpload $MaxSpeedInetUL " UL vs WAN " "Mbps" "Reverse" $SpdUpload $MaxSpeedInetUL
}

# -------------------------------------------------------------------------------------------------------------------------

# This function displays the stats UI for page 1
DisplayPage1 () {
  logo
    if [ "$UpdateNotify" != "0" ]; then
      echo -e "${CRed}  $UpdateNotify${CClear}"
      echo -e "${CGreen} ___${CClear}"
    else
      echo -e "${CGreen} ___${CClear}"
    fi
  echo -e "${CGreen}/${CRed}CPU${CClear}${CGreen}\______________________________________________________________${CClear}"
  echo ""
  echo -e "${InvCyan} ${CClear} ${CCyan}Uptime     ${CGreen}[         ${CCyan}$uptime${CGreen}          ]${CClear}"
  echo -e "${InvCyan} ${CClear} ${CCyan}CPU Load   ${CGreen}[   1m: ${CCyan}$cpuload1m  ${CGreen}5m: ${CCyan}$cpuload5m  ${CGreen}15m: ${CCyan}$cpuload15m${CGreen}   ]"
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
  converttemps $oldF_cputemp
  progressbar $currenttemp $currentrange " CPU Temp  " $TempUnits "Standard" $currenttemp $currentrange
  echo ""
  echo -e "${CGreen} ______"
  echo -e "${CGreen}/${CRed}Memory${CClear}${CGreen}\___________________________________________________________${CClear}"
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
  echo -e "${CGreen}/${CRed}Disk${CClear}${CGreen}\_____________________________________________________________${CClear}"
  echo ""
  preparebar 35 "|"
  progressbar $oldjffsused $oldjffstotal " JFFS Used " "MB" "Standard"
  echo ""
  preparebar 35 "|"
  progressbar $oldswapused $oldswaptotal " Swap Used " "MB" "Standard"
}

# -------------------------------------------------------------------------------------------------------------------------

# This function displays the stats UI for page 2
DisplayPage2 () {
  logo
  if [ "$UpdateNotify" != "0" ]; then
    echo -e "${CRed}  $UpdateNotify${CClear}"
    echo -e "${CGreen} ___${CClear}"
  else
    echo -e "${CGreen} ___${CClear}"
  fi
  echo -e "${CGreen}/${CRed}WAN${CClear}${CGreen}\______________________________________________________________${CClear}"
  echo ""
  #dwan0ip="1.2.3.4"
  #oldwanip6="abc1:23de::f456:ghi7:89jk:l0mn:opqr"
  echo -en "${InvCyan} ${CClear} ${CCyan}WAN 0/1 IP ${CGreen}[ ${CCyan}"
  printf '%03d.%03d.%03d.%03d'  ${oldwan0ip//./ }
  echo -en " / "
  printf '%03d.%03d.%03d.%03d'  ${oldwan1ip//./ }
  echo -e "${CGreen} ] ${InvDkGray}${CWhite}IFace: $WANIFNAME${CClear}"
  if [ ! -z $oldwanip6 ]; then echo -e "${InvCyan} ${CClear} ${CCyan}WAN 0/1 I6 ${CGreen}[ ${CCyan}$oldwanip6${CClear}"; fi
  echo -en "${InvCyan} ${CClear} ${CCyan}WAN DNS IP ${CGreen}[ ${CCyan}"
  if [ $olddns1ip = "0.0.0.0" ]; then printf "000.000.000.000"; else printf '%03d.%03d.%03d.%03d'  ${olddns1ip//./ }; fi
  echo -en " / "
  if [ $olddns2ip = "0.0.0.0" ]; then printf "000.000.000.000"; else printf '%03d.%03d.%03d.%03d'  ${olddns2ip//./ }; fi
  echo -e "${CClear}"
  preparebar 35 "|"
  progressbar $oldwanrxmbrate $MaxSpeedInet " Avg WAN RX" "Mbps" "Standard" $oldwanrxmbratedisplay $MaxSpeedInet
  echo ""
  preparebar 35 "|"
  progressbar $oldwantxmbrate $MaxSpeedInetUL " Avg WAN TX" "Mbps" "Standard" $oldwantxmbratedisplay $MaxSpeedInetUL
  echo ""
  echo -e "${CGreen} ___"
  echo -e "${CGreen}/${CRed}LAN${CClear}${CGreen}\______________________________________________________________${CClear}"
  echo ""
  echo -en "${InvCyan} ${CClear}${CCyan} BR0 LAN IP ${CGreen}[ ${CCyan}"
  printf '%03d.%03d.%03d.%03d'  ${oldlanip//./ }
  echo -e "${CClear}"
  if [ ! -z $oldlanip6 ]; then echo -e "${InvCyan} ${CClear} ${CCyan}BR0 LAN I6 ${CGreen}[ ${CCyan}$oldlanip6${CClear}"; fi
  preparebar 35 "|"
  progressbar $oldlanrxmbrate $MaxSpeedLAN " Avg LAN RX" "Mbps" "Standard" $oldlanrxmbratedisplay $MaxSpeedLAN
  echo ""
  preparebar 35 "|"
  progressbar $oldlantxmbrate $MaxSpeedLAN " Avg LAN TX" "Mbps" "Standard" $oldlantxmbratedisplay $MaxSpeedLAN
}

# -------------------------------------------------------------------------------------------------------------------------

# This function displays the stats UI for page 3
DisplayPage3 () {
  logo
  if [ "$UpdateNotify" != "0" ]; then
    echo -e "${CRed}  $UpdateNotify${CClear}"
    echo -e "${CGreen} ____${CClear}"
  else
    echo -e "${CGreen} ____${CClear}"
  fi
  echo -e "${CGreen}/${CRed}WiFi${CClear}${CGreen}\_____________________________________________________________${CClear}"
  echo ""
  if [ "$MaxSpeed24Ghz" != "0" ]; then
    preparebar 35 "|"
    progressbar $oldw24rxmbrate $MaxSpeed24Ghz " Avg 24G RX" "Mbps" "Standard" $oldw24rxmbratedisplay $MaxSpeed24Ghz
    echo ""
    preparebar 35 "|"
    progressbar $oldw24txmbrate $MaxSpeed24Ghz " Avg 24G TX" "Mbps" "Standard" $oldw24txmbratedisplay $MaxSpeed24Ghz
    echo ""
    preparebar 35 "|"
    converttemps $oldw24temp
    progressbar $currenttemp $currentrange " 2.4G Temp " $TempUnits "Standard" $currenttemp $currentrange
  else
    echo -e "${InvCyan} ${CClear}${CCyan} 2.4G Disabled"
    echo ""
  fi
  if [ "$MaxSpeed5Ghz" != "0" ]; then
    echo ""
    echo ""
    preparebar 35 "|"
    progressbar $oldw5rxmbrate $MaxSpeed5Ghz " Avg 5G1 RX" "Mbps" "Standard" $oldw5rxmbratedisplay $MaxSpeed5Ghz
    echo ""
    preparebar 35 "|"
    progressbar $oldw5txmbrate $MaxSpeed5Ghz " Avg 5G1 TX" "Mbps" "Standard" $oldw5txmbratedisplay $MaxSpeed5Ghz
    echo ""
    preparebar 35 "|"
    converttemps $oldw5temp
    progressbar $currenttemp $currentrange " 5G-1 Temp " $TempUnits "Standard" $currenttemp $currentrange
  else
    echo -e "${InvCyan} ${CClear}${CCyan} 5G-1 Disabled"
  fi
  if [ $AdvRouter == "True" ]; then
    if [ "$MaxSpeed5Ghz" != "0" ]; then
      echo ""
      echo ""
      preparebar 35 "|"
      progressbar $oldw52rxmbrate $MaxSpeed5Ghz " Avg 5G2 RX" "Mbps" "Standard" $oldw52rxmbratedisplay $MaxSpeed5Ghz
      echo ""
      preparebar 35 "|"
      progressbar $oldw52txmbrate $MaxSpeed5Ghz " Avg 5G2 TX" "Mbps" "Standard" $oldw52txmbratedisplay $MaxSpeed5Ghz
      echo ""
      preparebar 35 "|"
      converttemps $oldw52temp
      progressbar $currenttemp $currentrange " 5G-2 Temp " $TempUnits "Standard" $currenttemp $currentrange
    else
      echo -e "${InvCyan} ${CClear}${CCyan} 5G-2 Disabled"
    fi
    if [ "$MaxSpeed6Ghz" != "0" ]; then
      echo ""
      echo ""
      preparebar 35 "|"
      progressbar $oldw6rxmbrate $MaxSpeed6Ghz " Avg 60G RX" "Mbps" "Standard" $oldw6rxmbratedisplay $MaxSpeed6Ghz
      echo ""
      preparebar 35 "|"
      progressbar $oldw6txmbrate $MaxSpeed6Ghz " Avg 60G TX" "Mbps" "Standard" $oldw6txmbratedisplay $MaxSpeed6Ghz
      echo ""
      preparebar 35 "|"
      converttemps $oldw6temp
      progressbar $currenttemp $currentrange " 6.0G Temp " $TempUnits "Standard" $currenttemp $currentrange
    else
      echo -e "${InvCyan} ${CClear}${CCyan} 6.0G Disabled"
    fi
  fi
}

# -------------------------------------------------------------------------------------------------------------------------

# This function displays the stats UI for page 3
DisplayPage4 () {
  logo
  if [ "$UpdateNotify" != "0" ]; then
    echo -e "${CRed}  $UpdateNotify${CClear}"
    echo -e "${CGreen} _________${CClear}"
  else
    echo -e "${CGreen} _________${CClear}"
  fi
  echo -e "${CGreen}/${CRed}Speedtest${CClear}${CGreen}\________________________________________________________${CClear}"
  echo ""
  DisplaySpdtst
}

# -------------------------------------------------------------------------------------------------------------------------
# Begin Commandline Argument Gatekeeper and Configuration Utility Functionality
# -------------------------------------------------------------------------------------------------------------------------

#DEBUG=; set -x # uncomment/comment to enable/disable debug mode
#{              # uncomment/comment to enable/disable debug mode

  # Create the necessary folder/file structure for RTRMON under /jffs/addons
  if [ ! -d "/jffs/addons/rtrmon.d" ]; then
		mkdir -p "/jffs/addons/rtrmon.d"
  fi

  # Check for Updates
  updatecheck

  # Check for advanced router Features
  AdvRouter="False"
  [ -z "$($timeoutcmd$timeoutsec nvram get odmpid)" ] && RouterModel="$($timeoutcmd$timeoutsec nvram get productid)" || RouterModel="$($timeoutcmd$timeoutsec nvram get odmpid)" # Thanks @thelonelycoder for this logic
  if [ $RouterModel == "GT-AXE16000" ] || [ $RouterModel == "GT-AXE11000"]; then
    AdvRouter="True"
  fi

  # Check and see if any commandline option is being used
  if [ $# -eq 0 ]
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
  if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "-config" ] || [ "$1" == "-monitor" ] || [ "$1" == "-log" ] || [ "$1" == "-update" ] || [ "$1" == "-setup" ] || [ "$1" == "-uninstall" ] || [ "$1" == "-screen" ] || [ "$1" == "-reset" ]
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
    echo ""
    echo " -h | -help (this output)"
    echo " -log (display the current log contents)"
    echo " -config (configuration utility)"
    echo " -update (script update utility)"
    echo " -setup (setup/dependencies utility)"
    echo " -uninstall (uninstall utility)"
    echo " -screen (normal router monitoring using the screen utility)"
    echo " -monitor (normal router monitoring operations)"
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
  if [ "$1" == "-setup" ]
    then
      vsetup
  fi

  # Check to see if the uninstall option is being called
  if [ "$1" == "-uninstall" ]
    then
      vuninstall
      echo -e "${CClear}"
      exit 0
  fi

  # Check to see if the screen option is being called and run operations normally using the screen utility
  if [ "$1" == "-screen" ]
    then
      ScreenSess=$(screen -ls | grep "rtrmon" | awk '{print $1}' | cut -d . -f 1)
      if [ -z $ScreenSess ]; then
        clear
        echo -e "${CGreen}Executing RTRMON using the SCREEN utility...${CClear}"
        echo ""
        echo -e "${CGreen}Reconnect at any time using the command 'screen -r rtrmon'${CClear}"
        echo -e "${CGreen}To exit the SCREEN session, type: CTRL-A + D${CClear}"
        echo ""
        screen -dmS "rtrmon" $APPPATH -monitor
        sleep 2
        read -rsp $'Press any key to continue...\n' -n1 key
        echo -e "${CClear}"
        exit 0
      else
        clear
        echo -e "${CGreen}Another RTRMON Screen session is already running...${CClear}"
        echo -e "${CGreen}Would you like to attach to this session?${CClear}"
        if promptyn "(y/n): "; then
          screen -dr $ScreenSess
          sleep 2
          echo -e "${CClear}"
          exit 0
        else
          echo ""
          echo -e "\n${CGreen}Exiting...${CClear}"
          sleep 1
          return
        fi
      fi
  fi

  # Check to see if the monitor option is being called and run operations normally
  if [ "$1" == "-monitor" ]
    then
      clear
      if [ -f $CFGPATH ]; then
        source $CFGPATH

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

          # Per @Stephen Harrington's sugguestion, check NVRAM to see if Wifi is turned on, else mark them as disabled
          if [ $AdvRouter == "True" ]; then
            if [ $($timeoutcmd$timeoutsec nvram get wl0_radio) -eq 0 ]; then
              MaxSpeed5Ghz=0
            fi
            if [ $($timeoutcmd$timeoutsec nvram get wl1_radio) -eq 0 ]; then
              MaxSpeed52Ghz=0
            fi
            if [ $($timeoutcmd$timeoutsec nvram get wl3_radio) -eq 0 ]; then
              MaxSpeed24Ghz=0
            fi
            if [ $($timeoutcmd$timeoutsec nvram get wl2_radio) -eq 0 ]; then
              MaxSpeed6Ghz=0
            fi
          else
            if [ $($timeoutcmd$timeoutsec nvram get wl0_radio) -eq 0 ]; then
              MaxSpeed24Ghz=0
            fi
            if [ $($timeoutcmd$timeoutsec nvram get wl1_radio) -eq 0 ]; then
              MaxSpeed5Ghz=0
            fi
          fi

    else
      echo -e "${CRed}Error: RTRMON is not configured.  Please run 'rtrmon.sh -setup' to complete setup${CClear}"
      echo ""
      echo -e "$(date) - RTRMON ----------> ERROR: rtrmon.cfg was not found. Please run the setup tool." >> $LOGFILE
      kill 0
    fi
  fi

# -------------------------------------------------------------------------------------------------------------------------
# Main RTRMON program initialization
# -------------------------------------------------------------------------------------------------------------------------

# Display the logo and indicator that stats are being gathered.
  clear
  logoNM
  echo ""
  echo -e "  ${CGreen}[Initiating Boot Sequence - Gathering Initial Stats...]"
  echo ""
  INITIALBOOT=1

# Capture initial traffic and store current WAN/WiFi bytes stats
  if [ $WANOverride == "Auto" ]; then WANIFNAME=$(get_wan_setting ifname); else WANIFNAME=$WANOverride; fi
  if [ -z $WANIFNAME ]; then WANIFNAME="eth0"; fi
  oldwanrxbytes="$(cat /sys/class/net/$WANIFNAME/statistics/rx_bytes)"
  oldwantxbytes="$(cat /sys/class/net/$WANIFNAME/statistics/tx_bytes)"

  if [ $AdvRouter == "True" ]; then
    ifname24=$($timeoutcmd$timeoutsec nvram get wl3_ifname)
    ifname5=$($timeoutcmd$timeoutsec nvram get wl0_ifname)
    ifname52=$($timeoutcmd$timeoutsec nvram get wl1_ifname)
    ifname6=$($timeoutcmd$timeoutsec nvram get wl2_ifname)
  else
    ifname24=$($timeoutcmd$timeoutsec nvram get wl0_ifname)
    ifname5=$($timeoutcmd$timeoutsec nvram get wl1_ifname)
  fi

  old24rxbytes="$(cat /sys/class/net/$ifname24/statistics/rx_bytes)"
  old24txbytes="$(cat /sys/class/net/$ifname24/statistics/tx_bytes)"
  old5rxbytes="$(cat /sys/class/net/$ifname5/statistics/rx_bytes)"
  old5txbytes="$(cat /sys/class/net/$ifname5/statistics/tx_bytes)"
  if [ $AdvRouter == "True" ]; then
    old52rxbytes="$(cat /sys/class/net/$ifname52/statistics/rx_bytes)"
    old52txbytes="$(cat /sys/class/net/$ifname52/statistics/tx_bytes)"
    old6rxbytes="$(cat /sys/class/net/$ifname6/statistics/rx_bytes)"
    old6txbytes="$(cat /sys/class/net/$ifname6/statistics/tx_bytes)"
  fi
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
INITIALBOOT=0

# -------------------------------------------------------------------------------------------------------------------------
# Main loop that calls functions to perform all necessary calculations across the interval period
# -------------------------------------------------------------------------------------------------------------------------

while true; do

  if [ "$NextPage" == "1" ]; then
    clear
    DisplayPage1
    echo ""
  elif [ "$NextPage" == "2" ]; then
    clear
    DisplayPage2
    echo ""
  elif [ "$NextPage" == "3" ]; then
    clear
    DisplayPage3
    echo ""
  elif [ "$NextPage" == "4" ]; then
    clear
    DisplayPage4
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
  if [ $AdvRouter == "True" ]; then
    old52rxbytes="$(cat /sys/class/net/$ifname52/statistics/rx_bytes)"
    old52txbytes="$(cat /sys/class/net/$ifname52/statistics/tx_bytes)"
    old6rxbytes="$(cat /sys/class/net/$ifname6/statistics/rx_bytes)"
    old6txbytes="$(cat /sys/class/net/$ifname6/statistics/tx_bytes)"
  fi
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
