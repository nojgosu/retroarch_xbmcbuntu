#!/bin/bash
#  
#  RetroArch-Setup - Shell script for initializing XBMCbuntu 
#  with RetroArch and various cores. For use in conjunction with
#  RomCollectionBrowser. Adapted from Florian Müller's RetroPie Script for RPi.
#  
#  All licensing is as per the original.
#
#   Original License:
#  (c) Copyright 2012  Florian Müller (petrockblock@gmail.com)
#
#  RetroPie-Setup - Shell script for initializing Raspberry Pi 
#  with RetroArch, various cores, and EmulationStation (a graphical 
#  front end).
# 
#  (c) Copyright 2012  Florian Müller (petrockblock@gmail.com)
# 
#  RetroPie-Setup homepage: https://github.com/petrockblog/RetroPie-Setup
# 
#  Permission to use, copy, modify and distribute RetroPie-Setup in both binary and
#  source form, for non-commercial purposes, is hereby granted without fee,
#  providing that this license information and copyright notice appear with
#  all copies and any derived work.
# 
#  This software is provided 'as-is', without any express or implied
#  warranty. In no event shall the authors be held liable for any damages
#  arising from the use of this software.
# 
#  RetroPie-Setup is freeware for PERSONAL USE only. Commercial users should
#  seek permission of the copyright holders first. Commercial use includes
#  charging money for RetroPie-Setup or software derived from RetroPie-Setup.
# 
#  The copyright holders request that bug fixes and improvements to the code
#  should be forwarded to them so everyone can benefit from the modifications
#  in future versions.
# 
#  Many, many thanks go to all people that provide the individual packages!!!
# 
#  Raspberry Pi is a trademark of the Raspberry Pi Foundation.
# 

__ERRMSGS=""
__INFMSGS=""
__doReboot=0

# HELPER FUNCTIONS ###

function ask()
{   
    echo -e -n "$@" '[y/n] ' ; read ans
    case "$ans" in
        y*|Y*) return 0 ;;
        *) return 1 ;;
    esac
}

function addLineToFile()
{
    if [[ -f "$2" ]]; then
        cp "$2" ./temp
        sudo mv "$2" "$2.old"
    fi
    echo "$1" >> ./temp
    sudo mv ./temp "$2"
    echo "Added $1 to file $2"
}

# arg 1: key, arg 2: value, arg 3: file
# make sure that a key-value pair is set in file
# key = value
function ensureKeyValue()
{
    if [[ -z $(egrep -i "#? *$1 = ""?[+|-]?[0-9]*[a-z]*"""? $3) ]]; then
        # add key-value pair
        echo "$1 = ""$2""" >> $3
    else
        # replace existing key-value pair
        toreplace=`egrep -i "#? *$1 = ""?[+|-]?[0-9]*[a-z]*"""? $3`
        sed $3 -i -e "s|$toreplace|$1 = ""$2""|g"
    fi     
}

# make sure that a key-value pair is NOT set in file
# # key = value
function disableKeyValue()
{
    if [[ -z $(egrep -i "#? *$1 = ""?[+|-]?[0-9]*[a-z]*"""? $3) ]]; then
        # add key-value pair
        echo "# $1 = ""$2""" >> $3
    else
        # replace existing key-value pair
        toreplace=`egrep -i "#? *$1 = ""?[+|-]?[0-9]*[a-z]*"""? $3`
        sed $3 -i -e "s|$toreplace|# $1 = ""$2""|g"
    fi     
}

# arg 1: key, arg 2: value, arg 3: file
# make sure that a key-value pair is set in file
# key=value
function ensureKeyValueShort()
{
    if [[ -z $(egrep -i "#? *$1\s?=\s?""?[+|-]?[0-9]*[a-z]*"""? $3) ]]; then
        # add key-value pair
        echo "$1=""$2""" >> $3
    else
        # replace existing key-value pair
        toreplace=`egrep -i "#? *$1\s?=\s?""?[+|-]?[0-9]*[a-z]*"""? $3`
        sed $3 -i -e "s|$toreplace|$1=""$2""|g"
    fi     
}

# make sure that a key-value pair is NOT set in file
# # key=value
function disableKeyValueShort()
{
    if [[ -z $(egrep -i "#? *$1=""?[+|-]?[0-9]*[a-z]*"""? $3) ]]; then
        # add key-value pair
        echo "# $1=""$2""" >> $3
    else
        # replace existing key-value pair
        toreplace=`egrep -i "#? *$1=""?[+|-]?[0-9]*[a-z]*"""? $3`
        sed $3 -i -e "s|$toreplace|# $1=""$2""|g"
    fi     
}

# ensures pair of key ($1)-value ($2) in file $3
function ensureKeyValueBootconfig()
{
    if [[ -z $(egrep -i "#? *$1=[+|-]?[0-9]*[a-z]*" $3) ]]; then
        # add key-value pair
        echo "$1=$2" >> $3
    else
        # replace existing key-value pair
        toreplace=`egrep -i "#? *$1=[+|-]?[0-9]*[a-z]*" $3`
        sed $3 -i -e "s|$toreplace|$1=$2|g"
    fi     
}

function printMsg()
{
    echo -e "\n= = = = = = = = = = = = = = = = = = = = =\n$1\n= = = = = = = = = = = = = = = = = = = = =\n"
}

function rel2abs() {
  cd "$(dirname $1)" && dir="$PWD"
  file="$(basename $1)"

  echo $dir/$file
}

function checkForInstalledAPTPackage()
{
    PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $1|grep "install ok installed")
    echo Checking for somelib: $PKG_OK
    if [ "" == "$PKG_OK" ]; then
        echo "NOT INSTALLED: $1"
    else
        echo "installed: $1"
    fi    
}

function checkFileExistence()
{
    if [[ -f "$1" ]]; then
        ls -lh "$1" >> "$rootdir/debug.log"
    else
        echo "$1 does NOT exist." >> "$rootdir/debug.log"
    fi
}

# clones or updates the sources of a repository $2 into the directory $1
function gitPullOrClone()
{
    if [[ -d "$1/.git" ]]; then
        pushd "$1"
        git pull
    else
        rm -rf "$1" # makes sure that the directory IS empty
        mkdir -p "$1"
        git clone --depth=0 "$2" "$1"
        pushd "$1"
    fi
}

# END HELPER FUNCTIONS ###

function availFreeDiskSpace()
{
    local __required=$1
    local __avail=`df -P $rootdir | tail -n1 | awk '{print $4}'`

    if [[ "$__required" -le "$__avail" ]] || ask "Minimum recommended disk space (500 MB) not available. Please resize partition. Only $__avail available at $rootdir continue anyway?"; then
        return 0;
    else
        exit 0;
    fi
}

# update APT repositories
function update_apt() 
{
    clear
    printMsg "Updating APT-GET database"
    apt-get -y update
    printMsg "Performing APT-GET upgrade"
    apt-get -y upgrade
}


# add user $user to groups "video", "audio", and "input"
function add_to_groups()
{
    printMsg "Adding user $user to groups video, audio, and input."
    add_user_to_group $user video
    add_user_to_group $user audio
    add_user_to_group $user input
}

# add user $1 to group $2, create the group if it doesn't exist
function add_user_to_group()
{
    if [ -z $(egrep -i "^$2" /etc/group) ]
    then
      sudo addgroup $2
    fi
    sudo adduser $1 $2
}

# make sure ALSA, uinput, and joydev modules are active
function ensure_modules()
{
    printMsg "Enabling ALSA, uinput, and joydev modules permanently"
    sudo modprobe snd_bcm2835
    sudo modprobe uinput
    sudo modprobe joydev

    if ! grep -q "uinput" /etc/modules; then
        addLineToFile "uinput" "/etc/modules"
    else
        echo -e "uinput module already contained in /etc/modules"
    fi
    if ! grep -q "joydev" /etc/modules; then
        addLineToFile "joydev" "/etc/modules"
    else
        echo -e "joydev module already contained in /etc/modules"
    fi    
}

# needed by SDL for working joypads
function exportSDLNOMOUSE()
{
    printMsg "Exporting SDL_NOMOUSE=1 permanently to $home/.bashrc"
    export SDL_NOMOUSE=1
    if ! grep -q "export SDL_NOMOUSE=1" $home/.bashrc; then
        echo -e "\nexport SDL_NOMOUSE=1" >> $home/.bashrc
    else
        echo -e "SDL_NOMOUSE=1 already contained in $home/.bashrc"
    fi    
}

# make sure that all needed packages are installed
function packages_install()
{
    clear
    #ensure the video buffer is accessible by non-root users
    chmod 777 /dev/fb0

    #install apt-get packages needed for RetroArch
    printMsg "Ensuring package dependencies are installed"
    apt-get install -y libsdl1.2-dev screen scons libasound2-dev pkg-config libgtk2.0-dev \
                        libboost-filesystem-dev libboost-system-dev zip python-imaging \
                        libfreeimage-dev libfreetype6-dev libxml2 libxml2-dev libbz2-dev \
                        libaudiofile-dev libsdl-sound1.2-dev libsdl-mixer1.2-dev \
                        joystick fbi gcc-4.7 automake1.4 libcurl4-openssl-dev  libzip-dev \
                        build-essential nasm libgl1-mesa-dev libglu1-mesa-dev libsdl1.2-dev \
                        libvorbis-dev libpng12-dev libvpx-dev freepats subversion \
                        libboost-serialization-dev libboost-thread-dev libsdl-ttf2.0-dev \
                        cmake g++-4.7 unrar-free p7zip p7zip-full
                        # libgles2-mesa-dev

    #Does It Slow Down non NUC?
    # remove PulseAudio since this is slowing down the whole system significantly
    #apt-get remove -y pulseaudio
    #apt-get -y autoremove
}

# remove all packages that are installed by the RetroPie Setup Script (Not needed yet, no uninstall supported)
function removeAPTPackages()
{
    printMsg "Making sure that all packages that are installed by the script are removed."
    apt-get remove -y libsdl1.2-dev screen scons libasound2-dev pkg-config libgtk2.0-dev \
                        libboost-filesystem-dev libboost-system-dev zip python-imaging \
                        libfreeimage-dev libfreetype6-dev libxml2 libxml2-dev libbz2-dev \
                        libaudiofile-dev libsdl-sound1.2-dev libsdl-mixer1.2-dev \
                        joystick fbi gcc-4.7 automake1.4 libcurl4-openssl-dev  libzip-dev \
                        build-essential nasm libgl1-mesa-dev libglu1-mesa-dev libsdl1.2-dev \
                        libvorbis-dev libpng12-dev libvpx-dev freepats subversion \
                        libboost-serialization-dev libboost-thread-dev libsdl-ttf2.0-dev \
                        cmake g++-4.7 unrar-free p7zip p7zip-full
                        # libgles2-mesa-dev

    apt-get -y autoremove   

    dialog --backtitle "PetRockBlock.com - RetroPie Setup. Installation folder: $rootdir for user $user" --msgbox "Successfully removed APT packages. For a complete uninstall you need to delete the 'RetroPie' folder on your own." 22 76
}

# start SNESDev on boot and configure RetroArch input settings
function enableSplashscreenAtStart()
{
    clear
    printMsg "Enabling custom splashscreen on boot."

    chmod +x "$scriptdir/supplementary/asplashscreen/asplashscreen"
    cp "$scriptdir/supplementary/asplashscreen/asplashscreen" /etc/init.d/

    cp "$scriptdir/supplementary/asplashscreen/splashscreen.png" /etc/

    # This command installs the init.d script so it automatically starts on boot
    insserv /etc/init.d/asplashscreen
    # not-so-elegant hack for later re-enabling the splashscreen
    update-rc.d asplashscreen enable

}

# disable start SNESDev on boot and remove RetroArch input settings
function disableSplashscreenAtStart()
{
    clear
    printMsg "Disabling custom splashscreen on boot."

    update-rc.d asplashscreen disable

}

# Show dialogue for enabling/disabling SNESDev on boot
function enableDisableSplashscreen()
{
    cmd=(dialog --backtitle "PetRockBlock.com - RetroPie Setup. Installation folder: $rootdir for user $user" --menu "Choose the desired boot behaviour." 22 86 16)
    options=(1 "Disable custom splashscreen on boot."
             2 "Enable custom splashscreen on boot")
    choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
    if [ "$choices" != "" ]; then
        case $choices in
            1) disableSplashscreenAtStart
               dialog --backtitle "PetRockBlock.com - RetroPie Setup. Installation folder: $rootdir for user $user" --msgbox "Disabled custom splashscreen on boot." 22 76    
                            ;;
            2) enableSplashscreenAtStart
               dialog --backtitle "PetRockBlock.com - RetroPie Setup. Installation folder: $rootdir for user $user" --msgbox "Enabled custom splashscreen on boot." 22 76    
                            ;;
        esac
    else
        break
    fi    
}

# prepare folder structure for emulator, cores, front end, and roms
function prepareFolders()
{
    printMsg "Creating folder structure for emulator, front end, cores, and roms"

    pathlist=()
    pathlist+=("$rootdir/savefiles")
    pathlist+=("$rootdir/savestates")
    pathlist+=("$rootdir/roms/atari2600")
    pathlist+=("$rootdir/roms/gba")
    pathlist+=("$rootdir/roms/gbc")
    pathlist+=("$rootdir/roms/mame")
    pathlist+=("$rootdir/roms/mastersystem")
    pathlist+=("$rootdir/roms/megadrive")
    pathlist+=("$rootdir/roms/nes")
    pathlist+=("$rootdir/roms/psx")
    pathlist+=("$rootdir/roms/snes")
    pathlist+=("$rootdir/emulatorcores")
    pathlist+=("$rootdir/emulators")
    pathlist+=("$rootdir/supplementary")

    for elem in "${pathlist[@]}"
    do
        if [[ ! -d $elem ]]; then
            mkdir -p $elem
            chown $user $elem
            chgrp $user $elem
        fi
    done    
}

# settings for RetroArch
function configure_retroarch()
{
    printMsg "Configuring RetroArch"

    if [[ ! -f "$rootdir/configs/all/retroarch.cfg" ]]; then
        mkdir -p "$rootdir/configs/all/"
        mkdir -p "$rootdir/configs/atari2600/"
        echo -e "# All settings made here will override the global settings for the current emulator core\n" >> $rootdir/configs/atari2600/retroarch.cfg
        mkdir -p "$rootdir/configs/cavestory/"
        echo -e "# All settings made here will override the global settings for the current emulator core\n" >> $rootdir/configs/cavestory/retroarch.cfg
        mkdir -p "$rootdir/configs/doom/"
        echo -e "# All settings made here will override the global settings for the current emulator core\n" >> $rootdir/configs/doom/retroarch.cfg
        mkdir -p "$rootdir/configs/gb/"
        echo -e "# All settings made here will override the global settings for the current emulator core\n" >> $rootdir/configs/gb/retroarch.cfg
        mkdir -p "$rootdir/configs/gbc/"
        echo -e "# All settings made here will override the global settings for the current emulator core\n" >> $rootdir/configs/gbc/retroarch.cfg
        mkdir -p "$rootdir/configs/gamegear/"
        echo -e "# All settings made here will override the global settings for the current emulator core\n" >> $rootdir/configs/gamegear/retroarch.cfg
        mkdir -p "$rootdir/configs/mame/"
        echo -e "# All settings made here will override the global settings for the current emulator core\n" >> $rootdir/configs/mame/retroarch.cfg
        mkdir -p "$rootdir/configs/mastersystem/"
        echo -e "# All settings made here will override the global settings for the current emulator core\n" >> $rootdir/configs/mastersystem/retroarch.cfg
        mkdir -p "$rootdir/configs/nes/"
        echo -e "# All settings made here will override the global settings for the current emulator core\n" >> $rootdir/configs/nes/retroarch.cfg
        mkdir -p "$rootdir/configs/pcengine/"
        echo -e "# All settings made here will override the global settings for the current emulator core\n" >> $rootdir/configs/pcengine/retroarch.cfg
        mkdir -p "$rootdir/configs/psx/"
        echo -e "# All settings made here will override the global settings for the current emulator core\n" >> $rootdir/configs/psx/retroarch.cfg
        mkdir -p "$rootdir/configs/snes/"
        echo -e "# All settings made here will override the global settings for the current emulator core\n" >> $rootdir/configs/snes/retroarch.cfg
        mkdir -p "$rootdir/configs/fba/"
        echo -e "# All settings made here will override the global settings for the current emulator core\n" >> $rootdir/configs/fba/retroarch.cfg
        cp /etc/retroarch.cfg "$rootdir/configs/all/"
    fi

    ensureKeyValue "savefile_directory" "$rootdir/savefiles/" "$rootdir/configs/all/retroarch.cfg"
    ensureKeyValue "savestate_directory" "$rootdir/savestates/" "$rootdir/configs/all/retroarch.cfg"
    ensureKeyValue "savestate_auto_save" "false" "$rootdir/configs/all/retroarch.cfg"
    ensureKeyValue "savestate_auto_load" "false" "$rootdir/configs/all/retroarch.cfg"
    
    ensureKeyValue "system_directory" "$rootdir/emulatorcores/" "$rootdir/configs/all/retroarch.cfg"
    ensureKeyValue "video_aspect_ratio" "1.33" "$rootdir/configs/all/retroarch.cfg"
    ensureKeyValue "video_smooth" "false" "$rootdir/configs/all/retroarch.cfg"

    #setup keyboard to exit
    ensureKeyValue "input_exit_emulator" "escape" "$rootdir/configs/all/retroarch.cfg"

    # enable and configure rewind feature
    ensureKeyValue "rewind_enable" "true" "$rootdir/configs/all/retroarch.cfg"
    ensureKeyValue "rewind_buffer_size" "40" "$rootdir/configs/all/retroarch.cfg"
    ensureKeyValue "rewind_granularity" "2" "$rootdir/configs/all/retroarch.cfg"
    ensureKeyValue "input_rewind" "r" "$rootdir/configs/all/retroarch.cfg"

    # configure keyboard mappings
    ensureKeyValue "input_player1_a" "x" "$rootdir/configs/all/retroarch.cfg"
    ensureKeyValue "input_player1_b" "z" "$rootdir/configs/all/retroarch.cfg"
    ensureKeyValue "input_player1_y" "a" "$rootdir/configs/all/retroarch.cfg"
    ensureKeyValue "input_player1_x" "s" "$rootdir/configs/all/retroarch.cfg"
    ensureKeyValue "input_player1_start" "enter" "$rootdir/configs/all/retroarch.cfg"
    ensureKeyValue "input_player1_select" "rshift" "$rootdir/configs/all/retroarch.cfg"
    ensureKeyValue "input_player1_l" "q" "$rootdir/configs/all/retroarch.cfg"
    ensureKeyValue "input_player1_r" "w" "$rootdir/configs/all/retroarch.cfg"
    ensureKeyValue "input_player1_left" "left" "$rootdir/configs/all/retroarch.cfg"
    ensureKeyValue "input_player1_right" "right" "$rootdir/configs/all/retroarch.cfg"
    ensureKeyValue "input_player1_up" "up" "$rootdir/configs/all/retroarch.cfg"
    ensureKeyValue "input_player1_down" "down" "$rootdir/configs/all/retroarch.cfg"
}

# install RetroArch emulator
function install_retroarch()
{
    printMsg "Installing RetroArch emulator"
    gitPullOrClone "$rootdir/emulators/RetroArch" git://github.com/libretro/RetroArch.git
    ./configure
    make
    sudo make install
    cp $scriptdir/supplementary/retroarch-zip "$rootdir/emulators/RetroArch/"
    if [[ ! -f "/usr/local/bin/retroarch" ]]; then
        __ERRMSGS="$__ERRMSGS Could not successfully compile and install RetroArch."
    fi  
    popd
}

# install driver for XBox 360 controllers
function install_xboxdrv()
{
    printMsg "Installing xboxdrv"
    apt-get install -y xboxdrv
        
    #setup xboxdrv to load on start up for two controllers
    echo "xboxdrv --trigger-as-button --wid 0 --led 2 --deadzone 10% --silent &"  >> /etc/rc.local
    echo "sleep 1"                                                                >> /etc/rc.local
    echo "xboxdrv --trigger-as-button --wid 1 --led 3 --deadzone 10% --silent &"  >> /etc/rc.local
    echo "sleep 1"                                                                >> /etc/rc.local
    
    #configure xbox controllers
    echo "input_player1_joypad_index = \"0\""    >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_b_btn = \"0\""           >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_y_btn = \"2\""           >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_select_btn = \"6\""      >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_start_btn = \"7\""       >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_up_axis = \"-7\""        >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_down_axis = \"+7\""      >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_left_axis = \"-6\""      >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_right_axis = \"+6\""     >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_a_btn = \"1\""           >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_x_btn = \"3\""           >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_l_btn = \"4\""           >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_r_btn = \"5\""           >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_l2_axis = \"+2\""        >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_r2_axis = \"+5\""        >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_l3_btn = \"9\""          >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_r3_btn = \"10\""         >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_l_x_plus_axis = \"+0\""  >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_l_x_minus_axis = \"-0\"" >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_l_y_plus_axis = \"+1\""  >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_l_y_minus_axis = \"-1\"" >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_r_x_plus_axis = \"+3\""  >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_r_x_minus_axis = \"-3\"" >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_r_y_plus_axis = \"+4\""  >> $rootdir/configs/all/retroarch.cfg
    echo "input_player1_r_y_minus_axis = \"-4\"" >> $rootdir/configs/all/retroarch.cfg
    
    echo "input_player2_joypad_index = \"1\""    >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_b_btn = \"0\""           >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_y_btn = \"2\""           >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_select_btn = \"6\""      >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_start_btn = \"7\""       >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_up_axis = \"-7\""        >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_down_axis = \"+7\""      >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_left_axis = \"-6\""      >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_right_axis = \"+6\""     >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_a_btn = \"1\""           >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_x_btn = \"3\""           >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_l_btn = \"4\""           >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_r_btn = \"5\""           >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_l2_axis = \"+2\""        >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_r2_axis = \"+5\""        >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_l3_btn = \"9\""          >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_r3_btn = \"10\""         >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_l_x_plus_axis = \"+0\""  >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_l_x_minus_axis = \"-0\"" >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_l_y_plus_axis = \"+1\""  >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_l_y_minus_axis = \"-1\"" >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_r_x_plus_axis = \"+3\""  >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_r_x_minus_axis = \"-3\"" >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_r_y_plus_axis = \"+4\""  >> $rootdir/configs/all/retroarch.cfg
    echo "input_player2_r_y_minus_axis = \"-4\"" >> $rootdir/configs/all/retroarch.cfg

    echo "input_enable_hotkey_btn = \"8\""       >> $rootdir/configs/all/retroarch.cfg
    echo "input_exit_emulator_btn = \"5\""       >> $rootdir/configs/all/retroarch.cfg
    echo "input_rewind_btn = \"4\""              >> $rootdir/configs/all/retroarch.cfg
    echo "input_save_state_btn = \"3\""          >> $rootdir/configs/all/retroarch.cfg
    echo "input_load_state_btn = \"0\""          >> $rootdir/configs/all/retroarch.cfg
    echo "input_state_slot_increase = \"+6\""    >> $rootdir/configs/all/retroarch.cfg
    echo "input_state_slot_decrease = \"-6\""    >> $rootdir/configs/all/retroarch.cfg
    echo "input_disk_eject_toggle = \"7\""        >> $rootdir/configs/all/retroarch.cfg
    echo "input_disk_next = \"6\""                >> $rootdir/configs/all/retroarch.cfg
}

# shows help information in the console
function showHelp()
{
    echo ""
    echo "RetroArch Setup script for XBMCbuntu"
    echo "======================================"
    echo ""
    echo "The script installs the RetroArch emulator base with various cores and a graphical front end."
    echo "Because it needs to install some APT packages it has to be run with root priviliges."
    echo ""
    echo "Usage:"
    echo "sudo ./retroarch_setup_xbmcbuntu.sh: The installation directory is /home/pi/RetroPie for user pi"
    echo "sudo ./retroarch_setup_xbmcbuntu.sh USERNAME: The installation directory is /home/USERNAME/RetroPie for user USERNAME"
    echo "sudo ./retroarch_setup_xbmcbuntu.sh USERNAME ABSPATH: The installation directory is ABSPATH for user USERNAME"
    echo ""
}

# install runcommand script for switching video modes
function install_runcommandscript()
{
    printMsg "Installing script for setting video mode."
    mkdir -p "$rootdir/supplementary/runcommand/"
    cp $scriptdir/supplementary/runcommand.sh "$rootdir/supplementary/runcommand/"
    chmod +x "$rootdir/supplementary/runcommand/runcommand.sh"
    chown -R $user $rootdir
    chgrp -R $user $rootdir
}


function checkNeededPackages()
{
    doexit=0
    type -P git &>/dev/null && echo "Found git command." || { echo "Did not find git. Try 'sudo apt-get install -y git' first."; doexit=1; }
    type -P dialog &>/dev/null && echo "Found dialog command." || { echo "Did not find dialog. Try 'sudo apt-get install -y dialog' first."; doexit=1; }
    if [[ $doexit -eq 1 ]]; then
        exit 1
    fi
}

function main_reboot()
{
    clear
    reboot    
}

# checks all kinds of essential files for existence and logs the results into the file debug.log
function createDebugLog()
{
    clear
    printMsg "Generating debug log"

    echo "RetroArch files:" > "$rootdir/debug.log"

    # existence of files
    checkFileExistence "/usr/local/bin/retroarch"
    checkFileExistence "/usr/local/bin/retroarch-zip"
    checkFileExistence "$rootdir/configs/all/retroarch.cfg"
    echo -e "\nActive lines in $rootdir/configs/all/retroarch.cfg:" >> "$rootdir/debug.log"
    sed '/^$\|^#/d' "$rootdir/configs/all/retroarch.cfg"  >>  "$rootdir/debug.log"

    echo -e "\nEmulation Station files:" >> "$rootdir/debug.log"
    checkFileExistence "$rootdir/supplementary/EmulationStation/emulationstation"
    checkFileExistence "$rootdir/../.emulationstation/es_systems.cfg"
    checkFileExistence "$rootdir/../.emulationstation/es_input.cfg"
    echo -e "\nContent of es_systems.cfg:" >> "$rootdir/debug.log"
    cat "$rootdir/../.emulationstation/es_systems.cfg" >> "$rootdir/debug.log"
    echo -e "\nContent of es_input.cfg:" >> "$rootdir/debug.log"
    cat "$rootdir/../.emulationstation/es_input.cfg" >> "$rootdir/debug.log"

    echo -e "\nEmulators and cores:" >> "$rootdir/debug.log"
    checkFileExistence "`find $rootdir/emulatorcores/fceu-next/ -name "*libretro*.so"`"
    checkFileExistence "`find $rootdir/emulatorcores/libretro-prboom/ -name "*libretro*.so"`"
    checkFileExistence "$rootdir/emulatorcores/libretro-prboom/prboom.wad"
    checkFileExistence "`find $rootdir/emulatorcores/stella-libretro/ -name "*libretro*.so"`"
    checkFileExistence "`find $rootdir/emulatorcores/nxengine-libretro/ -name "*libretro*.so"`"
    checkFileExistence "`find $rootdir/emulatorcores/gambatte-libretro/ -name "*libretro*.so"`"
    checkFileExistence "`find $rootdir/emulatorcores/Genesis-Plus-GX/ -name "*libretro*.so"`"
    checkFileExistence "`find $rootdir/emulatorcores/fba-libretro/ -name "*libretro*.so"`"
    checkFileExistence "`find $rootdir/emulatorcores/pcsx_rearmed/ -name "*libretro*.so"`"
    checkFileExistence "`find $rootdir/emulatorcores/mednafen-pce-libretro/ -name "*libretro*.so"`"
    checkFileExistence "`find $rootdir/emulatorcores/pocketsnes-libretro/ -name "*libretro*.so"`"
    checkFileExistence "`find $rootdir/emulatorcores/vba-next/ -name "*libretro*.so"`"
    checkFileExistence "$rootdir/emulatorcors/uae4all/uae4all"

    echo -e "\nSNESDev:" >> "$rootdir/debug.log"
    checkFileExistence "$rootdir/supplementary/SNESDev-Rpi/bin/SNESDev"

    echo -e "\nSummary of ROMS directory:" >> "$rootdir/debug.log"
    du -ch --max-depth=1 "$rootdir/roms/" >> "$rootdir/debug.log"

    echo -e "\nUnrecognized ROM extensions:" >> "$rootdir/debug.log"
    find "$rootdir/roms/amiga/" -type f ! \( -iname "*.adf" -or -iname "*.jpg" -or -iname "*.xml" \) >> "$rootdir/debug.log"
    find "$rootdir/roms/atari2600/" -type f ! \( -iname "*.bin" -or -iname "*.jpg" -or -iname "*.xml" \) >> "$rootdir/debug.log"
    find "$rootdir/roms/doom/" -type f ! \( -iname "*.WAD" -or -iname "*.jpg" -or -iname "*.xml" -or -name "*.wad" \) >> "$rootdir/debug.log"
    find "$rootdir/roms/fba/" -type f ! \( -iname "*.zip" -or -iname "*.jpg" -or -iname "*.xml" \) >> "$rootdir/debug.log"
    find "$rootdir/roms/gamegear/" -type f ! \( -iname "*.gg" -or -iname "*.jpg" -or -iname "*.xml" \) >> "$rootdir/debug.log"
    find "$rootdir/roms/gba/" -type f ! \( -iname "*.gba" -or -iname "*.jpg" -or -iname "*.xml" \) >> "$rootdir/debug.log"
    find "$rootdir/roms/gbc/" -type f ! \( -iname "*.gb" -or -iname "*.jpg" -or -iname "*.xml" \) >> "$rootdir/debug.log"
    find "$rootdir/roms/mame/" -type f ! \( -iname "*.zip" -or -iname "*.jpg" -or -iname "*.xml" \) >> "$rootdir/debug.log"
    find "$rootdir/roms/mastersystem/" -type f ! \( -iname "*.sms" -or -iname "*.jpg" -or -iname "*.xml" \) >> "$rootdir/debug.log"
    find "$rootdir/roms/megadrive/" -type f ! \( -iname "*.smd" -or -iname "*.jpg" -or -iname "*.xml" \) >> "$rootdir/debug.log"
    find "$rootdir/roms/nes/" -type f ! \( -iname "*.nes" -or -iname "*.jpg" -or -iname "*.xml" \) >> "$rootdir/debug.log"
    find "$rootdir/roms/pcengine/" -type f ! \( -iname "*.iso" -or -iname "*.jpg" -or -iname "*.xml" \) >> "$rootdir/debug.log"
    find "$rootdir/roms/psx/" -type f ! \( -iname "*.img" -or -iname "*.jpg" -or -iname "*.xml" \) >> "$rootdir/debug.log"
    find "$rootdir/roms/snes/" -type f ! \( -iname "*.smc" -or -iname "*.jpg" -or -iname "*.xml" \) >> "$rootdir/debug.log"

    echo -e "\nCheck for needed APT packages:" >> "$rootdir/debug.log"
    checkForInstalledAPTPackage "libsdl1.2-dev" >> "$rootdir/debug.log"
    checkForInstalledAPTPackage "screen" >> "$rootdir/debug.log"
    checkForInstalledAPTPackage "scons" >> "$rootdir/debug.log"
    checkForInstalledAPTPackage "libasound2-dev" >> "$rootdir/debug.log"
    checkForInstalledAPTPackage "pkg-config" >> "$rootdir/debug.log"
    checkForInstalledAPTPackage "libgtk2.0-dev" >> "$rootdir/debug.log"
    checkForInstalledAPTPackage "libboost-filesystem-dev" >> "$rootdir/debug.log"
    checkForInstalledAPTPackage "libboost-system-dev" >> "$rootdir/debug.log"
    checkForInstalledAPTPackage "zip" >> "$rootdir/debug.log"
    checkForInstalledAPTPackage "libxml2" >> "$rootdir/debug.log"
    checkForInstalledAPTPackage "libxml2-dev" >> "$rootdir/debug.log"
    checkForInstalledAPTPackage "libbz2-dev" >> "$rootdir/debug.log"
    checkForInstalledAPTPackage "python-imaging" >> "$rootdir/debug.log"
    checkForInstalledAPTPackage "libfreeimage-dev" >> "$rootdir/debug.log"
    checkForInstalledAPTPackage "libfreetype6-dev" >> "$rootdir/debug.log"
    checkForInstalledAPTPackage "libaudiofile-dev" >> "$rootdir/debug.log"
    checkForInstalledAPTPackage "libsdl-sound1.2-dev" >> "$rootdir/debug.log"
    checkForInstalledAPTPackage "libsdl-mixer1.2-dev" >> "$rootdir/debug.log"

    echo -e "\nEnd of log file" >> "$rootdir/debug.log" >> "$rootdir/debug.log"

    dialog --backtitle "PetRockBlock.com - RetroPie Setup. Installation folder: $rootdir for user $user" --msgbox "Debug log was generated in $rootdir/debug.log" 22 76    

}

function main_updatescript()
{
  scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  pushd $scriptdir
  if [[ ! -d .git ]]; then
    dialog --backtitle "https://github.com/nojgosu/retroarch_xbmcbuntu - RetroArch Setup for XBMCbuntu." --msgbox "Cannot find direcotry '.git'. Please clone the RetroArch Setup script via 'git clone git://github.com/nojgosu/retroarch_xbmcbuntu.git'" 20 60    
    popd
    return
  fi
  git pull
  popd
  dialog --backtitle "RetroArch Setup for XBMCbuntu." --msgbox "Fetched the latest version of the RetroArch Setup script. You need to restart the script." 20 60    
}

#function to configure xbmcbuntu environment suitable for RetroArch and libretro
function configure_xbmcbuntu_environ()
{
       echo "nothing"
}

##################
## menus #########
##################

function retroarch_install()
{
#Add user $user to groups video, audio, and input" ON \ # any option can be set to default to "on"
#Add user $user to groups video, audio, and input" ON \ # any option can be set to default to "on"
#"(C) Enable modules ALSA, uinput, and joydev" ON \
#8 "(C) Export SDL_NOMOUSE=1" OFF \ #not sure if i need this
#54 "(C) Configure sound settings for RetroArch" ON \
    cmd=(dialog --separate-output --backtitle "RetroArch Setup for XBMCbuntu. Installation folder: $rootdir for user $user" --checklist "Select options with 'space' and arrow keys. The default selection installs a complete set of packages and configures basic settings. The entries marked as (C) denote the configuration steps." 22 76 16)
    options=(1 "(C) Configure XBMCbuntu environment" ON \
             2 "(C) Generate folder strucure" ON \
             3 "Install RetroArch" ON \
             4 "(C) Configure RetroArch" ON \
             5 "Install Atari 2600 core" ON \
             6 "Install Nintendo core" ON \
             7 "Install Super Nintendo core" ON \
             8 "Install Nintendo64 core" ON \
             9 "Install Playstation core" ON \
             10 "Install Sega Master System core" ON \
             11 "Install Sega Genesis core" ON \
             12 "Install Gameboy Colour core" ON \
             13 "Install Game Boy Advance core" ON \
             14 "Install MAME (iMAME4All) core" ON )
    choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
    clear
    __ERRMSGS=""
    __INFMSGS=""
    if [ "$choices" != "" ]; then
        for choice in $choices
        do
            case $choice in
                1) configure_xbmcbuntu_environ ;;
                2) prepareFolders ;;
                3) install_retroarch ;;
                4) configure_retroarch ;;
                5) install_atari2600 ;;
                6) install_nes ;;
                7) install_snes ;;
                8) install_n64 ;;
                9) install_psx;;
                10) install_sega_master ;;
                11) install_sega_genesis;;
                12) install_gbc ;;
                13) install_gba ;;
                14) install_mame ;;
            esac
        done

        chgrp -R $user $rootdir
        chown -R $user $rootdir

        createDebugLog

        if [[ ! -z $__ERRMSGS ]]; then
            dialog --backtitle "RetroArch Setup for XBMCbuntu. Installation folder: $rootdir for user $user" --msgbox "$__ERRMSGS See debug.log for more details." 20 60    
        fi

        if [[ ! -z $__INFMSGS ]]; then
            dialog --backtitle "RetroArch Setup for XBMCbuntu. Installation folder: $rootdir for user $user" --msgbox "$__INFMSGS" 20 60    
        fi

        dialog --backtitle "RetroArch Setup for XBMCbuntu. Installation folder: $rootdir for user $user" --msgbox "Finished installation.\nInstall RomCollectionBrowser plugin for XBMC and configure. Have fun!" 20 60    
    fi
}

######################################
# here starts the main loop ##########
######################################

if [[ "$1" == "--help" ]]; then
    showHelp
    exit 0
fi

if [ $(id -u) -ne 0 ]; then
  printf "Script must be run as root. Try 'sudo ./retroarch_setup_xbmcbuntu.sh' or ./retroarch_setup_xbmcbuntu.sh --help for further information\n"
  exit 1
fi


clear
#ensure dialog & git package is installed
printMsg "Installing dialog & git package."
apt-get install -y dialog git

scriptdir=`dirname $0`
scriptdir=`cd $scriptdir && pwd`

#no longer need to check for dialog and git
#checkNeededPackages

# if called with sudo ./retroarch_setup_xbmcbuntu.sh, the installation directory is /home/CURRENTUSER/RetroPie for the current user
# if called with sudo ./retroarch_setup_xbmcbuntu.sh USERNAME, the installation directory is /home/USERNAME/RetroPie for user USERNAME
# if called with sudo ./retroarch_setup_xbmcbuntu.sh USERNAME ABSPATH, the installation directory is ABSPATH for user USERNAME
    
if [[ $# -lt 1 ]]; then
    user=$SUDO_USER
    if [ -z "$user" ]
    then
        user=$(whoami)
    fi
    rootdir=/home/$user/RetroArch
elif [[ $# -lt 2 ]]; then
    user=$1
    rootdir=/home/$user/RetroArch
elif [[ $# -lt 3 ]]; then
    user=$1
    rootdir=$2
fi



home=$(eval echo ~$user)

if [[ ! -d $rootdir ]]; then
    mkdir -p "$rootdir"
    if [[ ! -d $rootdir ]]; then
      echo "Couldn't make directory $rootdir"
      exit 1
    fi
fi

availFreeDiskSpace 800000

while true; do
    cmd=(dialog --backtitle "https://github.com/nojgosu/retroarch_xbmcbuntu - RetroArch Setup for XBMCbuntu. Installation folder: $rootdir for user $user" --menu "RetroArch Setup." 22 76 16)
    options=(1 "Update atp-get" 
             2 "Install package dependencies"
             3 "Install RetroArch"
             4 "Update RetroArch XBMCbuntu setup script"
             5 "Update libretro emulator cores"
             6 "Update RetroArch"
             7 "Uninstall RetroArch"
             8 "Perform Reboot" )
    choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)    
    if [ "$choices" != "" ]; then
        case $choices in
            1) update_apt ;;
            2) packages_install ;;
            3) retroarch_install ;;
            4) main_updatescript ;;
            5) downloadBinaries ;;
            6) removeAPTPackages ;;
            7) main_options ;;
            8) main_reboot ;;
        esac
    else
        break
    fi
done

if [[ $__doReboot -eq 1 ]]; then
    dialog --title "The firmware has been updated and a reboot is needed." --clear \
        --yesno "Would you like to reboot now?\
        " 22 76

        case $? in
          0)
            main_reboot
            ;;
          *)        
            ;;
        esac
fi
clear