#!/bin/bash
# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

set -e

# Builds the R environment by copying the AGAVE_* environment
# variables over to the user's .Renviorn file
function build_Renviron_file() {

  # if there are Agave environment variables set,
  # clear all Agave environment variables from the
  # current /home/$NB_USER/.Renviron file and add the ones
  # from the current environment
  if [ -n "$AGAVE_VARS" ]; then
    # if the file exists, clear out the old vars, add the new
    if [ -e "/home/$NB_USER/.Renviron" ]; then
      sed -i 's/^AGAVE.*//g' /home/$NB_USER/.Renviron
    fi

    for i in `env | grep '^AGAVE_'`; do
      echo "$i" >> /home/$NB_USER/.Renviron
    done

  fi
}


# Handle special flags if we're root
if [ $(id -u) == 0 ] ; then
    # Handle username change. Since this is cheap, do this unconditionally
    usermod -d /home/$NB_USER -l $NB_USER jovyan

    # Change UID of NB_USER to NB_UID if it does not match
    if [ "$NB_UID" != $(id -u $NB_USER) ] ; then
        echo "Set user UID to: $NB_UID"
        usermod -u $NB_UID $NB_USER
        # Careful: $HOME might resolve to /root depending on how the
        # container is started. Use the $NB_USER home path explicitly.
        for d in "$CONDA_DIR" "$JULIA_PKGDIR" "/home/$NB_USER"; do
            if [[ ! -z "$d" && -d "$d" ]]; then
                echo "Set ownership to uid $NB_UID: $d"
                chown -R $NB_UID "$d"
            fi
        done
    fi

    # Change GID of NB_USER to NB_GID if NB_GID is passed as a parameter
    if [ "$NB_GID" ] ; then
        echo "Change GID to $NB_GID"
        groupmod -g $NB_GID -o $(id -g -n $NB_USER)
    fi

    # Enable sudo if requested
    if [[ "$GRANT_SUDO" == "1" || "$GRANT_SUDO" == 'yes' ]]; then
        echo "Granting $NB_USER sudo access"
        echo "$NB_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/notebook
    fi

    build_Renviron_file

    # Exec the command as NB_USER
    echo "Execute the command as $NB_USER"
    exec su $NB_USER -c "env PATH=$PATH $*"
else
  if [[ ! -z "$NB_UID" && "$NB_UID" != "$(id -u)" ]]; then
      echo 'Container must be run as root to set $NB_UID'
  fi
  if [[ ! -z "$NB_GID" && "$NB_GID" != "$(id -g)" ]]; then
      echo 'Container must be run as root to set $NB_GID'
  fi
  if [[ "$GRANT_SUDO" == "1" || "$GRANT_SUDO" == 'yes' ]]; then
      echo 'Container must be run as root to grant sudo permissions'
  fi

  build_Renviron_file

  # Exec the command
  echo "Execute the command"
  exec $*
fi
