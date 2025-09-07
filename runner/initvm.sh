#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2025 René de Hesselle <dehesselle@web.de>
#
# SPDX-License-Identifier: GPL-2.0-or-later

### description ################################################################

# TBD

### shellcheck #################################################################

# Nothing here.

### dependencies ###############################################################

# Nothing here.

### variables ##################################################################

SELF_DIR=$(dirname "${BASH_SOURCE[0]}")
PACKAGES_DIR=/Volumes/orka/packages
CONFIGS_DIR=$SELF_DIR
ANSI_FG_RESET="\033[0;0m"
ANSI_FG_YELLOW_BRIGHT="\033[0;93m"
BOT_USER_GROUP=bot:staff

### functions ##################################################################

function _mkdir
{
  local dir=${1:?}
  local delete_if_exists=${2:true}

  if [ -d "$dir" ] && $delete_if_exists; then
    sudo rm -rf "$dir"
  fi
  sudo mkdir "$dir"
  sudo chown admin:staff "$dir"
}

function install_macports
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  _mkdir /opt/macports
  tar -C /opt -xJf $PACKAGES_DIR/macports15.tar.xz
}

function install_sdk
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  local version=113

  _mkdir /opt/sdks
  tar -C /opt/sdks -xJf $PACKAGES_DIR/macosx${version}sdk.tar.xz
}

function install_rust
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  local version=1860

  _mkdir /opt/rustup
  tar -C /opt -xJf $PACKAGES_DIR/rustup_$version.tar.xz
}

function setup_user_and_password
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  python3 -m venv .venv
  # shellcheck disable=SC1091 # temporary location
  source .venv/bin/activate
  pip install diceware==1.0.1
  local password
  password=$(diceware -n3 -d "-")
  echo "****** YOUR PASSWORD:    $password    *******"
  deactivate
  rm -rf .venv

  local home=/Users/${BOT_USER_GROUP%%:*}

  sudo dscl . -create "$home"
  sudo dscl . -create "$home" UserShell /bin/zsh
  sudo dscl . -create "$home" RealName "Robot Bottington"
  sudo dscl . -create "$home" UniqueID "600"
  sudo dscl . -create "$home" PrimaryGroupID 20 # staff
  sudo dscl . -create "$home" NFSHomeDirectory "$home"
  sudo dscl . -passwd "$home" "$password"
  sudo dscl . -passwd /Users/admin admin "$password" # TODO: convenient, but doesn't belong here

  sudo mkdir -p "$home"/.ssh
  sudo cp "$CONFIGS_DIR"/bot@runner_ecdsa.pub "$home"/.ssh/authorized_keys
  sudo chown -R $BOT_USER_GROUP "$home"
  sudo chmod 600 "$home"/.ssh/authorized_keys
}

function install_homebrew
{
  _mkdir /opt/homebrew
  curl -L https://github.com/Homebrew/brew/tarball/main |
      tar xz --strip-components 1 -C /opt/homebrew
  sudo chown -R $BOT_USER_GROUP /opt/homebrew
}

function set_hostname
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  local name=$1

  sudo /usr/libexec/PlistBuddy -c "Set :System:System:ComputerName $name" /Library/Preferences/SystemConfiguration/preferences.plist
  sudo /usr/libexec/PlistBuddy -c "Set :System:Network:HostNames:LocalHostName $name" /Library/Preferences/SystemConfiguration/preferences.plist
}

function setup_ramdisk
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  sudo cp /Volumes/orka/config/local.volumes.ram.plist /Library/LaunchDaemons
}

function install_gitlabrunner
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  local version=17101

  _mkdir /usr/local/bin
  tar -C /usr/local/bin -xJf $PACKAGES_DIR/gitlab-runner_$version.tar.xz
}

function install_ccache
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  local ccache_ver=4.11.3
  local ccache_url=https://github.com/ccache/ccache/releases/download/v$ccache_ver/ccache-$ccache_ver-darwin.tar.gz

  _mkdir /opt/ccache
  curl -L "$ccache_url" | tar -C /opt/ccache -xz --strip-components 1
}

function update_macos
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  local version=15.6.1-24G90

  if [ "$(sw_vers | grep ProductVersion | awk '{print $2}')" = "${version%%-*}" ]; then
    echo "no update required"
  else
    sudo softwareupdate -i -R "macOS Sequoia $version"
  fi
}

function install_xcode_clt
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  local version=16.4

  if [ -d "/Library/Developer/CommandLineTools" ]; then
    echo "no installation required"
  else
    touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    softwareupdate -i "Command Line Tools for Xcode-$version"
    rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  fi
}

### main #######################################################################

# OS updates and installs
update_macos
install_xcode_clt
set_hostname "$1"

# software
install_macports
install_sdk
install_rust
install_gitlabrunner
install_ccache

# user and related software
setup_user_and_password
install_homebrew
