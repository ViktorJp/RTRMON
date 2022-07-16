#!/bin/sh

# RTRMON v1.0 - Asus-Merlin Router Monitor
# RTRMON is a shell script that provides near-realtime stats about your Asus-Merlin firmware router. Instead of having to
# find this information on various different screens or apps, this tool was built to bring all this info together in one
# stat dashboard.  Having a 'system' dashboard showing current CPU, Memory, Disk and Network stats would compiment other
# dashboard-like scripts greatly (like RTRMON), sitting side-by-side in their own SSH windows to give you everything
# you need to know with a glance at your screen.
#
# Please use the 'rtrmon.sh -setup' to configure the necessary parameters that match your environment the best!
#
# -------------------------------------------------------------------------------------------------------------------------
# System Variables (Do not change beyond this point or this may change the programs ability to function correctly)
# -------------------------------------------------------------------------------------------------------------------------
Version="1.0"
Beta=0
LOGFILE="/jffs/addons/rtrmon.d/rtrmon.log"          # Logfile path/name that captures important date/time events - change
APPPATH="/jffs/scripts/rtrmon.sh"                   # Path to the location of rtrmon.sh
CFGPATH="/jffs/addons/rtrmon.d/rtrmon.cfg"          # Path to the location of rtrmon.cfg
DLVERPATH="/jffs/addons/rtrmon.d/version.txt"       # Path to downloaded version from the source repository

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
  echo -e "     / __ \/_  __/ __ \/  |/  / __ \/ | / /  ${CGreen}v$Version${CYellow}"
  echo -e "    / /_/ / / / / /_/ / /|_/ / / / /  |/ /  ${CRed}(S)${CGreen}etup${CYellow}"
  echo -e "   / _, _/ / / / _, _/ /  / / /_/ / /|  /   ${CRed}(N)${CGreen}ext Page ($NextPage/2)${CYellow}"
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
        printf "${InvGreen}${CWhite}$insertspc${CClear}${CGreen}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      elif [ $progr -gt 59 ] && [ $progr -lt 85 ]; then
        printf "${InvYellow}${CBlack}$insertspc${CClear}${CYellow}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      else
        printf "${InvRed}${CWhite}$insertspc${CClear}${CRed}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      fi
    elif [ "$5" == "Reverse" ]; then
      if [ $progr -lt 35 ]; then
        printf "${InvRed}${CWhite}$insertspc${CClear}${CRed}${3} [%.${barch}s%.${barsp}s]${CClear} ${CWhite}${InvDkGray}$AltNum ${4} / ${progr}%%\r${CClear}" "$barchars" "$barspaces"
      elif [ $progr -gt 35 ] && [ $progr -lt 85 ]; then
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
      echo -e "${CGreen}RTRMON Configuration Utility${CClear}" # Provide main setup menu
      echo ""
      echo -e "${CGreen}----------------------------------------------------------------"
      echo -e "${CGreen}Options"
      echo -e "${CGreen}----------------------------------------------------------------"
      echo -e "${InvDkGray}${CWhite} 1 ${CClear}${CCyan}: Timer Interval (seconds)      :"${CGreen}$Interval
      echo -e "${InvDkGray}${CWhite} 2 ${CClear}${CCyan}: Max Internet Speed (Mbps)     :"${CGreen}$MaxSpeedInet
      echo -e "${InvDkGray}${CWhite} 3 ${CClear}${CCyan}: Max LAN Speed (Mbps)          :"${CGreen}$MaxSpeedLAN
      echo -e "${InvDkGray}${CWhite} 4 ${CClear}${CCyan}: Max 2.4Ghz Speed (Mbps)       :"${CGreen}$MaxSpeed24Ghz
      echo -e "${InvDkGray}${CWhite} 5 ${CClear}${CCyan}: Max 5Ghz Speed (Mbps)         :"${CGreen}$MaxSpeed5Ghz
      echo -e "${InvDkGray}${CWhite} 6 ${CClear}${CCyan}: Temperature Units (C/F/K)     :"${CGreen}$TempUnits
      echo -e "${InvDkGray}${CWhite} s ${CClear}${CCyan}: Save & Exit"
      echo -e "${InvDkGray}${CWhite} e ${CClear}${CCyan}: Exit & Discard Changes"
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
              Interval=$Interval1
            ;;

            2) # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan}2. What is your maximum internet bandwidth/speed in Mbps?"
              echo -e "${CYellow}(Default = 1000)${CClear}"
              read -p 'Max Internet Speed (Mbps): ' MaxSpeedInet1
              MaxSpeedInet=$MaxSpeedInet1
            ;;

            3) # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan}3. What is your maximum LAN switch bandwidth/speed in Mbps?"
              echo -e "${CYellow}(Default = 1000)${CClear}"
              read -p 'Max LAN Speed (Mbps): ' MaxSpeedLAN1
              MaxSpeedLAN=$MaxSpeedLAN1
            ;;

            4) # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan}4. What is your maximum realistic 2.4Ghz speed in Mbps?"
              echo -e "${CYellow}(Default = 450)${CClear}"
              read -p 'Max 2.4Ghz Speed (Mbps): ' MaxSpeed24Ghz1
              MaxSpeed24Ghz=$MaxSpeed24Ghz1
            ;;

            5) # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan}5. What is your maximum realistic 5Ghz speed in Mbps?"
              echo -e "${CYellow}(Default = 780)${CClear}"
              read -p 'Max 5Ghz Speed (Mbps): ' MaxSpeed5Ghz1
              MaxSpeed5Ghz=$MaxSpeed5Ghz1
            ;;

            6) # -----------------------------------------------------------------------------------------
              echo ""
              echo -e "${CCyan}6. Which Temperature Units would you prefer? (C)elcius,"
              echo -e "${CCyan}(Fahrenheit) or (K)elvin?"
              echo -e "${CYellow}(Default = C)${CClear}"
              read -p 'Temp Units (C/F/K): ' TempUnits1
              TempUnits=$(echo $TempUnits1 | tr '[a-z]' '[A-Z]')
            ;;

            s) # -----------------------------------------------------------------------------------------
              echo ""
              { echo 'Interval='$Interval
                echo 'MaxSpeedInet='$MaxSpeedInet
                echo 'MaxSpeedLAN='$MaxSpeedLAN
                echo 'MaxSpeed24Ghz='$MaxSpeed24Ghz
                echo 'MaxSpeed5Ghz='$MaxSpeed5Ghz
                echo 'TempUnits="'"$TempUnits"'"'
              } > $CFGPATH
              echo ""
              echo -e "${CGreen}Please restart RTRMON to apply your changes..."
              echo -e "$(date) - RTRMON - Successfully wrote a new config file" >> $LOGFILE
              sleep 3
              return
            ;;

            e) # -----------------------------------------------------------------------------------------
              return
            ;;

          esac
    done

  else
      #Create a new config file with default values to get it to a basic running state
      { echo 'Interval=10'
        echo 'MaxSpeedInet=1000'
        echo 'MaxSpeedLAN=1000'
        echo 'MaxSpeed24Ghz=450'
        echo 'MaxSpeed5Ghz=780'
        echo 'TempUnits="C"'
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
  echo -e "${CGreen}RTRMON Uninstall Utility${CClear}"
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
  echo -e "${CGreen}RTRMON Update Utility${CClear}"
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
    echo -e "${CGreen}RTRMON Setup Utility${CClear}" # Provide main setup menu
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

          e)
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

# Borrowed this wonderful keypress capturing mechanism from @Eibgrad... thank you! :)
key_press=''; read -rsn1 -t 1 key_press < "$(tty 0>&2)"

if [ $key_press ]; then
    case $key_press in
        [Ss]) FromUI=1; (vsetup); echo -e "${CGreen}  [Returning to the Main UI momentarily]                                   "; FromUI=0;;
        [Nn]) if [ "$NextPage" == "1" ]; then NextPage=2; clear; DisplayPage2; echo -e "\n"; elif [ "$NextPage" == "2" ]; then NextPage=1; clear; DisplayPage1; echo -e "\n"; fi;;
        [Ee]) echo -e "${CClear}"; exit 0;;
    esac
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

# calculatestats calculates, well, all the current stats  ;)
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
    F_cputemp=$($timeoutcmd$timeoutsec cat /sys/class/thermal/thermal_zone0/temp | cut -c -2)

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
    $($timeoutcmd$timeoutsec nvram show >/tmp/output.txt 2> /tmp/size.txt)
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
    w0tempraw=$($timeoutcmd$timeoutsec wl -i $ifname24 phy_tempsense | awk '{print $1}' )
    w1tempraw=$($timeoutcmd$timeoutsec wl -i $ifname5 phy_tempsense | awk '{print $1}' )
    if [ -z $w0tempraw ] || [ $w0tempraw -eq 0 ]; then w0tempraw=4; fi  #in case it does not return a valid number
    if [ -z $w1tempraw ] || [ $w1tempraw -eq 0 ]; then w1tempraw=4; fi
    w0temp=$(awk -v v1=$w0tempraw 'BEGIN{printf "\n" (v1/2)+20}' | cut -d . -f 1)
    w1temp=$(awk -v v1=$w1tempraw 'BEGIN{printf "\n" (v1/2)+20}' | cut -d . -f 1)

  # Network - Wifi - Traffic
    ifname24=$($timeoutcmd$timeoutsec nvram get wl0_ifname)
    ifname5=$($timeoutcmd$timeoutsec nvram get wl1_ifname)
    new24rxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname24/statistics/rx_bytes)"
    new24txbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname24/statistics/tx_bytes)"
    new5rxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname5/statistics/rx_bytes)"
    new5txbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/$ifname5/statistics/tx_bytes)"

  # Network - LAN - Traffic
    newlanrxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/br0/statistics/rx_bytes)"
    newlantxbytes="$($timeoutcmd$timeoutsec cat /sys/class/net/br0/statistics/tx_bytes)"

  # Network - WAN - Traffic
    WANIFNAME=$(get_wan_setting ifname)
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

  # Network - Traffic - Results are further divided by the timer/interval to give Megabits/sec
    wanrxmbrate=$(awk -v rb=$diffwanrxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
    wantxmbrate=$(awk -v tb=$diffwantxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    w24rxmbrate=$(awk -v rb=$diff24rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
    w24txmbrate=$(awk -v tb=$diff24txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    w5rxmbrate=$(awk -v rb=$diff5rxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
    w5txmbrate=$(awk -v tb=$diff5txbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)
    lanrxmbrate=$(awk -v rb=$difflanrxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", rb/intv}' | cut -d . -f 1)
    lantxmbrate=$(awk -v tb=$difflantxbytes -v intv=$RM_ELAPSED_TIME 'BEGIN{printf "%0.2f\n", tb/intv}' | cut -d . -f 1)

  # Uptime calc
    uptime=$(awk '{printf("%03dd %02dh %02dm %02ds\n",($1/60/60/24),($1/60/60%24),($1/60%60),($1%60))}' /proc/uptime)
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
  echo -e "${CGreen}/${CRed}CPU${CClear}${CGreen}\_____________________________________________________________${CClear}"
  echo ""
  echo -e "  ${CCyan}Uptime     ${CGreen}[         ${CCyan}$uptime${CGreen}          ]${CClear}"
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
  converttemps $oldF_cputemp
  progressbar $currenttemp $currentrange " CPU Temp  " $TempUnits "Standard"
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

# This function displays the stats UI for page 2
DisplayPage2 () {
  logo
  if [ "$UpdateNotify" != "0" ]; then
    echo -e "${CRed}  $UpdateNotify${CClear}"
    echo -e "${CGreen} ___${CClear}"
  else
    echo -e "${CGreen} ___${CClear}"
  fi
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
  if [ "$MaxSpeed24Ghz" != "0" ]; then
    preparebar 35 "|"
    progressbar $oldw24rxmbrate $MaxSpeed24Ghz " Avg 24G RX" "Mbps" "Standard"
    echo ""
    preparebar 35 "|"
    progressbar $oldw24txmbrate $MaxSpeed24Ghz " Avg 24G TX" "Mbps" "Standard"
    echo ""
    preparebar 35 "|"
    converttemps $oldw0temp
    progressbar $currenttemp $currentrange " 2.4G Temp " $TempUnits "Standard"
    echo ""
    echo ""
  else
    echo -e "${InvCyan} ${CClear}${CCyan} W0 Disabled"
    echo ""
  fi
  if [ "$MaxSpeed5Ghz" != "0" ]; then
    preparebar 35 "|"
    progressbar $oldw5rxmbrate $MaxSpeed5Ghz " Avg 50G RX" "Mbps" "Standard"
    echo ""
    preparebar 35 "|"
    progressbar $oldw5txmbrate $MaxSpeed5Ghz " Avg 50G TX" "Mbps" "Standard"
    echo ""
    preparebar 35 "|"
    converttemps $oldw1temp
    progressbar $currenttemp $currentrange " 5.0G Temp " $TempUnits "Standard"
  else
    echo -e "${InvCyan} ${CClear}${CCyan} W1 Disabled"
  fi
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
    echo " -config (configuration/setup utility)"
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

          if [ "$DelayStartup" != "0" ]
            then
              SPIN=$DelayStartup
              echo -e "${CGreen}Delaying RTRMON start-up for $DelayStartup seconds..."
              spinner
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
