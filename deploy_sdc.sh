#!/bin/bash

# The sdc user's home directory
sdc_home=/usr/local/cdo

# We need to run as root to create user, restart services, and chown files
if [ "$EUID" -ne 0 ] || [ "$#" -ne 1 ]; then
    echo "usage: sudo ./sdc_prep.sh [bootstrap data]" >&2
    echo "example: sudo ./sdc_prep.sh Q0RPX1RPS0VOPSJleU...Y29fYWFoYWNrbmUtU0RDLTQiCg==" >&2
    exit 1
fi

# Make sure the bootstrap.sh prerequisite packages are installed
for package in net-tools awscli
do
  if [ ! "$(dpkg -l | awk '/'"$package"'/ {print }'|wc -l)" -ge 1 ]; then
    echo "$package is required for the CDO SDC bootstrap script and is not installed."
    echo "Installing $package"
    apt-get install "$package" -y
  fi
done

# Create sdc user if it does not exist
if id sdc >/dev/null 2>&1; then
    echo "Found existing user: sdc"
else
    echo "Creating user: sdc"
    adduser --gecos "" --disabled-password sdc --home "$sdc_home"
fi

# Make sure the sdc user's home dir exists
if [ ! -d /usr/local/cdo ]; then
    mkdir "$sdc_home"
    chown sdc:sdc "$sdc_home"
fi

# Create the docker group if it does not exist
if [ `getent group docker` ]; then
    echo "Found existing group: docker"
else
    echo "Creating group: docker"
    groupadd docker
fi

# Add the sdc user to the docker group
echo "Adding the sdc user to the group docker"
if [ ! `getent group docker | grep -qw "sdc"`]; then
    usermod -aG docker sdc
fi

# Check for the docker daemon.json file
echo "Checking to see if the file daemon.json file exists in /etc/docker"
daemon_json='{"live-restore": true, "group": "docker"}'

if [ -f /etc/docker/daemon.json ]; then
  echo "/etc/docker/daemon.json exists. Please make sure the following parameters are in /etc/docker/daemon.json"
  echo $daemon_json
else
  echo "Writing file /etc/docker/daemon.json"
  echo $daemon_json >> /etc/docker/daemon.json
fi

# Restart the docker daemon
echo "Restarting docker daemon"
systemctl restart docker
echo "Docker status after restart:"
echo `systemctl status docker | grep 'Active'`

# Decode bootstrap data and extract the needed pieces
echo "Decoding the bootstrap data..."
decoded_bootstrap=`echo "$1" | base64 --decode`

# Write env vars to file and load
printf '%s\n' "${decoded_bootstrap[@]}" > "$sdc_home/sdcenv"
eval source "$sdc_home/sdcenv"

# Download the bootstrap file from CDO
echo Downloading CDO Bootstrap File
eval curl --output "$sdc_home/${CDO_BOOTSTRAP_URL##*/}" --header "\"Authorization: Bearer $CDO_TOKEN\"" "$CDO_BOOTSTRAP_URL"

# Untarring CDO Bootstrap file
eval tar xzvf "$sdc_home/${CDO_BOOTSTRAP_URL##*/}" --directory "$sdc_home"

# chown the new files to sdc user
chown --recursive sdc:sdc "$sdc_home"

# Final check for success and exit
if [ -f "$sdc_home/bootstrap/bootstrap.sh" ]; then
  echo
  echo "***********************************************************************************************"
  echo "SDC pre-configuration scripts appears to have completed successfully."
  echo "Run the following commands to start the SDC configration process:"
  echo "sudo su sdc"
  echo "cd $sdc_home; source $sdc_home/sdcenv; $sdc_home/bootstrap/bootstrap.sh"
  echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  exit 0
else
  echo "***********************************************************************************************" >&2
  echo "Something went wrong with the pre-configuration script." >&2
  echo "Post your issue in github and include the output from this script with the debug option enabled" >&2
  echo "bash -x sdc-pre-config.sh" >&2
  echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" >&2
  exit 3
fi