#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2025 René de Hesselle <dehesselle@web.de>
#
# SPDX-License-Identifier: GPL-2.0-or-later

### description ################################################################

# Initialize runner on Sequoia.

### shellcheck #################################################################

# Nothing here.

### dependencies ###############################################################

if [ -d "$HOME/orka-images" ]; then
  # shellcheck disable=SC1091 # does not exist before bootstrap
  source "$HOME"/orka-images/runner/common.sh
fi

### variables ##################################################################

REPO_DIR=$HOME/orka-images
SELF_NAME=runner-sequoia

### functions ##################################################################

function bootstrap
{
  if [ -d "$REPO_DIR" ]; then
    echo "already bootstrapped"
  else
    mkdir "$REPO_DIR"
    curl -L https://github.com/dehesselle/orka-images/archive/refs/heads/main.zip |
        bsdtar -C "$REPO_DIR" --strip-components 1 -xvf-
    bash "$REPO_DIR"/$SELF_NAME/initvm.sh
    exit $?
  fi
}

### main #######################################################################

echo "----------------------------------------------------"

bootstrap

# system
update_macos "macOS Sequoia 15.7.1-24G231"
install_xcode "/Volumes/orka/packages/Xcode_16.4.xip"

# software
install_ccache "4.12.1"
install_gitlabrunner "18.4.0"
install_homebrew
install_macports
install_rust "1.90.0"
install_sdk 113
install_sdk 155
install_uv

# configuration
set_hostname
set_motd

# users
setup_bot_user
setup_admin_user

echo "----------------------------------------------------"
