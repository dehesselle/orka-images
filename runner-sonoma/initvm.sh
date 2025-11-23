#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2025 René de Hesselle <dehesselle@web.de>
#
# SPDX-License-Identifier: GPL-2.0-or-later

### description ################################################################

# Initialize runner on Sonoma.

### shellcheck #################################################################

# Nothing here.

### dependencies ###############################################################

if [ -d "$HOME/orka-images" ]; then
  # shellcheck disable=SC1091 # does not exist before bootstrap
  source "$HOME"/orka-images/runner/common.sh
fi

### variables ##################################################################

REPO_DIR=$HOME/orka-images
SELF_NAME=runner-sonoma

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
update_macos "macOS Sonoma 14.8.2-23J126"
install_xcode "/Volumes/orka/packages/Xcode_15.4.xip"

# software
install_ccache "4.12.1"
install_gitlabrunner "18.5.0"
install_homebrew
install_macports "2.11.6"
install_rust "1.91.1"
install_sdk 113
install_sdk 133
install_uv "0.9.9"

# configuration
set_hostname
set_motd

# users
setup_bot_user
setup_admin_user

echo "----------------------------------------------------"
