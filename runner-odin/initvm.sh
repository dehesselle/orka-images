#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2025 René de Hesselle <dehesselle@web.de>
#
# SPDX-License-Identifier: GPL-2.0-or-later

### description ################################################################

# runner-odin
#
# TODO: This script is neither consistent nor optimized because I hven't
#       decided in which direction to take this. But it's a start.
#       Or maybe replace with Ansible?

### shellcheck #################################################################

# Nothing here.

### dependencies ###############################################################

# Nothing here.

### variables ##################################################################

SELF_DIR=$(dirname "${BASH_SOURCE[0]}")
PACKAGES_DIR=/Volumes/orka/packages
CONFIGS_DIR=$SELF_DIR

### functions ##################################################################

function install_macports
{
  echo "${FUNCNAME[0]}"

  if [ -d /opt/macports ]; then
    sudo rm -rf /opt/macports
  fi
  sudo mkdir /opt/macports
  sudo chown admin:staff /opt/macports
  tar -C /opt -xJf $PACKAGES_DIR/macports15.tar.xz
}

function install_sdk
{
  echo "${FUNCNAME[0]}"

  if [ -d /opt/sdks ]; then
    sudo rm -rf /opt/sdks
  fi
  sudo mkdir /opt/sdks
  sudo chown admin:staff /opt/sdks
  tar -C /opt/sdks -xJf $PACKAGES_DIR/macosx113sdk.tar.xz
}

function install_rust
{
  echo "${FUNCNAME[0]}"

  if [ -d /opt/rustup ]; then
    sudo rm -rf /opt/rustup
  fi
  sudo mkdir /opt/rustup
  sudo chown admin:staff /opt/rustup
  tar -C /opt -xJf $PACKAGES_DIR/rustup_1860.tar.xz
}

function create_user
{
  echo "${FUNCNAME[0]}"

  python3 -m venv .venv
  # shellcheck disable=SC1091 # temporary location
  source .venv/bin/activate
  pip install diceware==1.0.1
  local password
  password=$(diceware -n3 -d "-")
  echo "****** YOUR PASSWORD:    $password    *******"
  deactivate
  rm -rf .venv

  sudo dscl . -create /Users/bot
  sudo dscl . -create /Users/bot UserShell /bin/zsh
  sudo dscl . -create /Users/bot RealName "Robot Bottington"
  sudo dscl . -create /Users/bot UniqueID "600"
  sudo dscl . -create /Users/bot PrimaryGroupID 20 # staff
  sudo dscl . -create /Users/bot NFSHomeDirectory /Users/bot
  sudo dscl . -passwd /Users/bot "$password"
  sudo dscl . -passwd /Users/admin admin "$password" # TODO: convenient, but doesn't belong here

  sudo mkdir -p /Users/bot/.ssh
  sudo cp "$CONFIGS_DIR"/bot@runner_ecdsa.pub /Users/bot/.ssh/authorized_keys
  sudo chown -R bot:staff /Users/bot/.ssh
  sudo chmod 600 /Users/bot/.ssh/authorized_keys

  sudo chown -R bot:staff /opt/homebrew
}

function set_hostname
{
  echo "${FUNCNAME[0]}"

  sudo /usr/libexec/PlistBuddy -c "Set :System:System:ComputerName runner" /Library/Preferences/SystemConfiguration/preferences.plist
  sudo /usr/libexec/PlistBuddy -c "Set :System:Network:HostNames:LocalHostName runner" /Library/Preferences/SystemConfiguration/preferences.plist
}

function setup_ramdisk
{
  echo "${FUNCNAME[0]}"

  sudo cp /Volumes/orka/config/local.volumes.ram.plist /Library/LaunchDaemons
}

function install_gitlabrunner
{
  echo "${FUNCNAME[0]}"

  sudo mkdir -p /usr/local/bin
  sudo chown admin:staff /usr/local/bin

  tar -C /usr/local/bin -xJf $PACKAGES_DIR/gitlab-runner_17101.tar.xz
}

function install_ccache
{
  sudo mkdir /opt/ccache
  sudo chown admin:staff /opt/ccache

  local ccache_ver=4.11.3
  local ccache_url=https://github.com/ccache/ccache/releases/download/v$ccache_ver/ccache-$ccache_ver-darwin.tar.gz

  curl -L "$ccache_url" | tar -C /opt/ccache -xz --strip-components 1
}

### main #######################################################################

install_macports
install_sdk
install_rust
create_user
set_hostname
#setup_ramdisk
install_gitlabrunner
install_ccache
