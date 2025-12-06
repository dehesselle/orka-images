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
ADMIN_USER_GROUP=admin:staff
PRODUCT_VERSION=$(sw_vers -productVersion)

### functions ##################################################################

function _mkdir
{
  local dir=${1:?}
  local delete_if_exists=${2:true}

  if [ -d "$dir" ] && $delete_if_exists; then
    sudo rm -rf "$dir"
  fi
  sudo mkdir -p "$dir"
  sudo chown $ADMIN_USER_GROUP "$dir"
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
  local size=${1:-1}

  if [ ! -d /Volumes/RAM ]; then
    diskutil erasevolume HFS+ "RAM" "$(diskutil image attach ram://"${size}"GiB)"
  fi
}

function _reinitialize_repo
{
  git -C "$REPO_DIR" init
  git -C "$REPO_DIR" remote add origin https://github.com/dehesselle/orka-images
  git -C "$REPO_DIR" fetch
  git -C "$REPO_DIR" reset --hard origin/main
  git -C "$REPO_DIR" clean -f
}

function install_macports
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  local version=${1:-2.11.5}

  _create_ramdisk
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
    chown -R $ADMIN_USER_GROUP /opt/macports
    chmod -R g+w /opt/macports
  )
}

function install_sdk
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  local version=$1

  _mkdir /opt/sdks false
  tar -C /opt/sdks -xJf $PACKAGES_DIR/macosx"${version}"sdk.tar.xz
}

function install_rust
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  local version=${1:-1.80.0}

  _mkdir /opt/rustup

  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
      RUSTUP_HOME=/opt/rustup sh -s -- \
          -y \
          --default-toolchain "$version"-aarch64-apple-darwin \
          --no-modify-path
}

function setup_bot_user
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  local home=/Users/${BOT_USER_GROUP%%:*}

  sudo dscl . -create "$home"
  sudo dscl . -create "$home" UserShell /bin/zsh
  sudo dscl . -create "$home" RealName "Robot Bottington"
  sudo dscl . -create "$home" UniqueID "600"
  sudo dscl . -create "$home" PrimaryGroupID 20 # staff
  sudo dscl . -create "$home" NFSHomeDirectory "$home"
  sudo dscl . -passwd "$home" start123
  sudo dseditgroup -o edit -a bot -t user com.apple.access_ssh

  _mkdir "$home"/.ssh
  sudo cp "$REPO_DIR"/runner/bot@runner_ecdsa.pub "$home"/.ssh/authorized_keys
  sudo chmod 600 "$home"/.ssh/authorized_keys
  sudo chown -R $BOT_USER_GROUP "$home"
}

function set_motd
{
  sudo touch /etc/motd
  sudo chown $ADMIN_USER_GROUP /etc/motd

  local macos_version=${PRODUCT_VERSION%%.*}
  local image_version
  case "$macos_version" in
    14) image_version="$(git -C "$REPO_DIR" describe --tags --match 'runner-sonoma*')" ;;
    15) image_version="$(git -C "$REPO_DIR" describe --tags --match 'runner-sequoia*')" ;;
    *)  image_version="$(git -C "$REPO_DIR" rev-parse --short HEAD)";;
  esac

  {
    echo "═════════════════════════════════════════════════════════════════════"
    uvx pyfiglet -f smblock "$image_version"
    echo "source:  https://github.com/dehesselle/orka-images"
    echo "created: $(date +'%Y-%m-%dT%H:%M:%S%z' | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')"
    echo "═════════════════════════════════════════════════════════════════════"
  } > /etc/motd
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

  local version=${1:-17.11.4}

  _mkdir /usr/local/bin false
 
  curl -o /usr/local/bin/gitlab-runner \
      -L https://gitlab-runner-downloads.s3.amazonaws.com/v$version/binaries/gitlab-runner-darwin-arm64
  chmod 755 /usr/local/bin/gitlab-runner
}

function install_ccache
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  local ccache_ver=${1:-4.11.3}
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
    _reinitialize_repo
  fi
}

function install_xcode
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  local xip_archive=$1

  (
    cd /Applications || return
    sudo xip -x "$xip_archive"
    sudo xcodebuild -license accept
    _reinitialize_repo
  )
}

function setup_admin_user
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  _mkdir "$HOME"/.ssh
  cp "$REPO_DIR"/runner/bot@runner_ecdsa.pub "$HOME"/.ssh/authorized_keys
  chmod 600 "$HOME"/.ssh/authorized_keys

  sudo bash -c 'echo "%admin ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/admin_no_pw'
}

function install_uv
{
  echo -e "$ANSI_FG_YELLOW_BRIGHT${FUNCNAME[0]}$ANSI_FG_RESET"

  local uv_ver=${1:-0.9.15}
  local uv_url=https://github.com/astral-sh/uv/releases/download/$uv_ver/uv-aarch64-apple-darwin.tar.gz

  _mkdir /usr/local/bin false
  curl -L "$uv_url" | tar -C /usr/local/bin -xz --strip-components 1
}

### main #######################################################################

ensure_admin_user
