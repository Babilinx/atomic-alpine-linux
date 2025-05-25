#!/bin/ash
# Ash is the default shell on the Live ISO

# Atomic Alpine Linux installer
# Copyright (C) Atomic Alpine Linux
#               2024 Babilinx <babilinx.evx1o@simplelogin.com>
# This program is distributed under the terms of the GNU General Public License
# version 3. See <https://gnu.org/licenses/> for more.

set -euo pipefail

# Installer variables
AAL_FLAVOR=""
AAL_INSTALL_DISK=""
AAL_USERS=( "root" "" "__nopasswd__" )  # [ $name $groups $passwd ... ]
AAL_FLAVORS=( "GNOME" "Shell" )
AAL_FEATURES=(
    "Edge Kernel"               "off"
    "Edge repos"
    "AppArmor"                  "off"
    "AppArmor Extras"           "off"
    "NetworkManager"            "off"
    "WiFi (wpa_supplicant)"     "off"
    "ZRAM (swap in RAM)"        "off"
)
AAL_SOFTWARES=(
    "flatpak"                   "off"
)


## Helpers

# Credit: https://www.cyberciti.biz/faq/repeat-a-character-in-bash-script-under-linux-unix/
repeat(){
	local start=1
	local end=${1:-80}
	local str="${2:-=}"
	local range=$(seq $start $end)
	for i in $range ; do echo -n "${str}"; done
}



## Exit and error handleing programs
# Logics

exit_menu() {
    case `exit_box 3>&2 2>&1 1>&3` in
        1) echo "reboot";;
        2) echo "exit";;
        3) echo "poweroff";;
    esac

  exit
}


no_root_rights() {
    no_root_rights_box
    exit_menu
}

no_uefi() {
    no_uefi_box
    exit_menu
}

keymap_failed() {

}

network_configuration_failed() {

}

internet_connection_failed() {

}

repos_config_failed() {

}

iso_update_failed() {

}

deps_install_failed() {

}

installation_failed() {

}

user_configuration_failed() {

}

select_features_failed() {

}

select_software_failed() {

}

post_install_setup_not_confirmed() {

}

post_install_failed() {

}

unknow_page() {

}


# Box

exit_box() {
  local title="Exit install"`
  local menu_msg="Select what to do"
  local reboot_msg="Reboot computer"
  local exit_msg=`"Exit AAL installer"
  local poweroff_msg="Poweroff computer"
    
  dialog --title "$title" --no-cancel --menu "\n$menu_msg" 50 50 10 1 \
  "$reboot_msg" 2 "$exit_msg" 3 "$poweroff_msg"
}

no_root_rights_box() {
    local title="Prepare the install"
    local text_failed="No root rights!"
    local text="This installer requires root rights.
\n
Unable to continue the installation."

    dialog --title "$title" --ok-label "Go to exit menu" --colors --msgbox \
  "\n\Z1\Zb\Zr$text_failed\Zn\n\n$text" 50 50
}

no_uefi_box() {
  local title="Prepare the install"
  local text_failed="No UEFI support present!"
  local text="This system does not support UEFI mode. UEFI is a requirement for \
Atomic Alpine Linux as it uses EFI capabilities.

If your system supports in facts UEFI, please disable Legacy Boot/CSM support \
in your BIOS to force the Alpine ISO to boot into UEFI mode."

  dialog --title "$title" --ok-label "Go to exit menu" --colors --msgbox \
  "\n\Z1\Zb\Zr$text_failed\Zn\n\n$text" 50 50
}



## Pre install
# Logic

select_keymap() {

}

configure_network() {

}

check_internet() {

}

configure_repos() {

}

update_iso() {

}

install_deps() {

}

select_aal_flavor() {
  aal_flavor_choices=()
  local spacer=$(repeat 10 " ")
    
  for key in "${!AAL_FLAVORS[@]}"; do
    if [[ "${AAL_FLAVORS[$key]}" == "Shell" ]]; then
      aal_flavor_choices+=("${AAL_FLAVORS[$key]}" "$spacer" "on")
      continue
    fi

    aal_flavor_choices+=("${AAL_FLAVORS[$key]}" "$spacer" "off")
  done
    
  AAL_FLAVOR="$(select_aal_flavor_box 3>&2 2>&1 1>&3)"
}


select_install_disk() {
  install_disk_choices=()

  get_disks

  for disk_number in "${!disks_names[@]}"; do
    install_disk_choices+=("${disks_names[$disk_number]}" \
    "${disks_sizes[$disk_number]}  ${disks_models[$disk_number]}" "off")
  done
    
  # Select the first disk
  install_disk_choices[2]="on"
    
  AAL_INSTALL_DISK="$(select_install_disk_box 3>&2 2>&1 1>&3)"
}


# Box

welcome_box() {
  local title="Welcome to the Atomic Alpine Linux installer."
  local text="This script will let you configure and install 
an atomic Alpine Linux. Please be careful as you can delete important data!"
    
  dialog --title "$title" --no-label "Exit" --yes-label "Continue" --yesno "\n$text" 50 50
}

important_aal_is_alpha_box() {
  local title="Important note!"
  local text="Please note that Atomic Alpine Linux project is still in early developpement.
Please do not use it as your main operating system as things can break. We recomands using it inside a VM.

If you understand the risks, please continue."
    
  dialog --title "\Z1\Zb$title\Zn" --no-label "Exit" --yes-label "Continue" \
  --colors --yesno "\n$text" 50 50
}

important_installer_is_alpha_box() {
  local title="Important note!"
  local text="Please note that the install script itself is in early developpement.\
Unexpected things can append during the installation process.

Please do not use it on your main machine

If you understand the risks, please continue."
    
  dialog --title "\Z1\Zb$title\Zn" --no-label "Exit" --yes-label "Continue" \
    --colors --yesno "\n$text" 50 50
}

select_keymap_box() {

}

configure_network_box() {

}

check_network_box() {

}

configure_repos_box() {

}

update_iso_box() {

}

install_deps_box() {

}

select_aal_flavor_box() {
  local choices=($@)
  local title="Select AAL flavor"
  local text="Choose the AAL flavor to install"
    
  dialog --title "$title" --radiolist "\n$text" 50 50 10 "${aal_version_choices[@]}"
}

select_install_disk_box() {
  local title="Select the disk"
  local text="Choose the disk to intall Sophora into"
    
  dialog --title "$title" --radiolist "\n$text" 50 50 10 \
  "${install_disk_choices[@]}"
}

confirm_install_setup_box() {

}



## Install
# Logic

get_disks() {
  local DISKS_NAMES=(`lsblk -p -l -n -o NAME,TYPE | awk '{if ($2 =="disk") print $1}'`)
  local DISKS_SIZES=(`lsblk -p -l -n -o SIZE,TYPE | awk '{if ($2 =="disk") print $1}'`)
  local DISKS_MODELS=()
  disks_names=()
  disks_sizes=()
  disks_model=()
    
  for disk in "${DISKS_NAMES[@]}"; do
    disk_id="${disk/\/dev\//}"
    DISKS_MODELS+=("`cat "/sys/class/block/$disk_id/device/model" | \
    awk '$1=$1'`")
  done

  for disk_number in "${!DISKS_NAMES[@]}"; do
    if [[ "${DISKS_SIZES[$disk_number]}" == "0B" ]]; then
      continue
    fi

    disks_names+=("${DISKS_NAMES[$disk_number]}")
    disks_sizes+=("${DISKS_SIZES[$disk_number]}")
    disks_models+=("${DISKS_MODELS[$disk_number]}")
  done
}

# Box



## Post install
# Logic


# Box

configure_users_box() {
    
}

configure_user_box() {
    # [ $name $groups $passwd ]
    local user=( "" "" "" )
}

# Main

page=0

main() {
  case $page in
    0) [ "$EUID" -eq 0 ] || exit_no_root_rights
        [ -d /sys/firmware/efi/efivars ] || exit_no_uefi
        welcome_box && page=$((page+1)) || exit_menu;;

    1) important_aal_is_alpha_box && page=$((page+1)) || exit_menu;;
        
    2) important_installer_is_alpha_box && page=$((page+1)) || exit_menu;;
    
    3) select_keymap && page=$((page+1)) || keymap_failed;;
    
    4) configure_network && page=$((page+1)) || network_configuration_failed;;
    
    5) check_internet && page=$((page+1)) || internet_connection_failed;;
    
    6) configure_repos && page=$((page+1)) || repos_config_failed;;
    
    7) update_iso && page=$((page+1)) || iso_update_failed;;
    
    8) install_deps && page=$((page+1)) || deps_install_failed;; 
        
    9) select_aal_flavor && page=$((page+1)) || exit_menu;;
        
    10) select_install_disk && page=$((page+1)) || exit_menu;;
    
    11) confirm_install_setup && page=$((page+1)) || exit_menu;;
    
    12) install_aal && page=$((page+1)) || installation_failed;;
    
    13) configure_users && page=$((page+=1)) || user_configuration_failed;;
    
    14) select_additional_features && page =$((page+1)) || select_features_failed;;
    
    15) select_additional_software && page=$((page+1)) || select_software_failed;;
    
    16) confirm_post_install_setup && page=$((page+1)) || post_install_setup_not_confirmed;;
    
    17) post_install && page=$((page+1)) || post_install_failed;;
    
    18) install_complete && exit_menu;;
        
    *) unknow_page;;
  esac
}

while true; do
  main
done




prepare_box() {
  local title="Prepare the install"
  local text="Please wait until basic preparations are \
finished..."
    
  dialog --title "$title" --infobox "\n$text" 50 50
}


prepare_finished_box() {
  local title="Prepare the install"
  local text="Preparations finished."
    
  dialog --title "$title" --msgbox "\n$text" 50 50
}


prepare_failed_box() {
  local title="Prepare the install"
  local text_failed="Preparations failed!"
  local text_exit="Exiting."
    
  dialog --title "$title" --colors --msgbox \
  "\n\Z1\Zb\Zr$text_failed\Zn\n\n$text_exit" 50 50
}




