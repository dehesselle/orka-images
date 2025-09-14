#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2025 René de Hesselle <dehesselle@web.de>
#
# SPDX-License-Identifier: GPL-2.0-or-later

### description ################################################################

# Common functiosn and configuration to setup a runner.

### shellcheck #################################################################

# Nothing here.

### dependencies ###############################################################

# Nothing here.

### variables ##################################################################

PACKAGES_DIR=/Volumes/orka/packages
REPO_DIR=$HOME/orka-images
ANSI_FG_RESET="\033[0;0m"
ANSI_FG_YELLOW_BRIGHT="\033[0;93m"
BOT_USER_GROUP=bot:staff
PASSWORD=$(dd if=/dev/urandom bs=1 count=256 2>/dev/null |
    LC_ALL=C tr -cd '[:graph:]' |
    tr -d \'\" |
    head -c 64)
PRODUCT_VERSION=$(sw_vers | grep ProductVersion | awk '{print $2}')

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

function ensure_admin_user
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  if [ "$(whoami)" != "admin" ]; then
    echo "error: I am not 'admin'"
    exit 1
  fi
}

function _create_ramdisk
{
  local size=$1

  diskutil erasevolume HFS+ "RAM" "$(diskutil image attach ram://"${size}"GiB)"
}

function install_macports
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  local version=2.11.5

  _create_ramdisk 2
  _mkdir /opt/macports

  curl -L https://github.com/macports/macports-base/releases/download/v$version/MacPorts-$version.tar.bz2 |
      tar -C /Volumes/RAM -xj

  (
    cd /Volumes/RAM/MacPorts-$version || exit 1
    ./configure \
        --prefix=/opt/macports \
        --with-unsupported-prefix \
        --with-no-root-privileges \
        --with-install-user=admin \
        --with-install-group=staff \
        --with-macports-user=admin \
        --with-applications-dir=/opt/macports/Applications \
        --with-frameworks-dir=/opt/macports/Frameworks \
        --without-startupitems
    make -j "$(sysctl -n hw.ncpu)"
    make install
    chown -R admin:staff /opt/macports
    chmod -R g+w /opt/macports
  )
}

function install_sdk
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  local version=$1

  _mkdir /opt/sdks
  tar -C /opt/sdks -xJf $PACKAGES_DIR/macosx"${version}"sdk.tar.xz
}

function install_rust
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  local version=1860

  _mkdir /opt/rustup
  tar -C /opt -xJf $PACKAGES_DIR/rustup_$version.tar.xz
}

function create_user
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  local home=/Users/${BOT_USER_GROUP%%:*}

  sudo dscl . -create "$home"
  sudo dscl . -create "$home" UserShell /bin/zsh
  sudo dscl . -create "$home" RealName "Robot Bottington"
  sudo dscl . -create "$home" UniqueID "600"
  sudo dscl . -create "$home" PrimaryGroupID 20 # staff
  sudo dscl . -create "$home" NFSHomeDirectory "$home"
  sudo dscl . -passwd "$home" "$PASSWORD"
  echo "******   $PASSWORD   ******"

  sudo mkdir -p "$home"/.ssh
  sudo cp "$REPO_DIR"/runner/bot@runner_ecdsa.pub "$home"/.ssh/authorized_keys
  sudo chown -R $BOT_USER_GROUP "$home"
  sudo chmod 600 "$home"/.ssh/authorized_keys
  sudo dseditgroup -o edit -a bot -t user com.apple.access_ssh
}

function install_homebrew
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  _mkdir /opt/homebrew
  curl -L https://github.com/Homebrew/brew/tarball/main |
      tar xz --strip-components 1 -C /opt/homebrew
  chmod -R g+w /opt/homebrew
}

function set_hostname
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  local name=runner

  sudo /usr/libexec/PlistBuddy -c "Set :System:System:ComputerName $name" /Library/Preferences/SystemConfiguration/preferences.plist
  sudo /usr/libexec/PlistBuddy -c "Set :System:Network:HostNames:LocalHostName $name" /Library/Preferences/SystemConfiguration/preferences.plist
}

function setup_ramdisk
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  sudo cp "$REPO_DIR"/runner/local.volumes.ram.plist /Library/LaunchDaemons
}

function install_gitlabrunner
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  local version=17.11.4

  _mkdir /usr/local/bin false
 
  curl -o /usr/local/bin/gitlab-runner \
      -L https://gitlab-runner-downloads.s3.amazonaws.com/v$version/binaries/gitlab-runner-darwin-arm64
  chmod 755 /usr/local/bin/gitlab-runner
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

  local version=$1
  local version_no=${version##* }

  if [ "$PRODUCT_VERSION" = "${version_no%%-*}" ]; then
    echo "no update required"
  else
    echo "You need to rerun 'bash initvm.sh' after reboot!"
    sudo softwareupdate -i -R "$version"
  fi
}

function install_xcode_clt
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  local version=$1

  if [ -d "/Library/Developer/CommandLineTools" ]; then
    echo "no installation required"
  else
    touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    softwareupdate -i "Command Line Tools for Xcode-$version"
    rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  fi
}

function set_admin_password
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  sudo dscl . -passwd /Users/admin admin "$PASSWORD"
  echo "******   $PASSWORD   ******"
}

### main #######################################################################

ensure_admin_user
