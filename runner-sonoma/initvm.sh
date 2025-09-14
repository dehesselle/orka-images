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

# OS updates and installs
update_macos "macOS Sonoma 14.7.8-23H730"
install_xcode_clt "16.2"
set_hostname

# software
install_ccache
install_gitlabrunner
install_homebrew
install_macports
install_rust
install_sdk 113

# users
create_user
set_admin_password

echo "----------------------------------------------------"
