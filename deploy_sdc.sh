#!/bin/bash

# The sdc user's home directory
sdc_home=/usr/local/cdo

# We need the b64 bootstrap payload from CDO as a parameter for the script
if [ "$#" -ne 1 ]; then
    echo "usage: source sdc_prep.sh [bootstrap data]" >&2
    echo "example: source sdc_prep.sh Q0RPX1RPS0VOPSJleU...Y29fYWFoYWNrbmUtU0RDLTQiCg==" >&2
    exit
fi

# Make sure the bootstrap.sh prerequisite packages are installed
for package in net-tools awscli
do
  if [ ! "$(sudo dpkg -l | awk '/'"$package"'/ {print }'|wc -l)" -ge 1 ]; then
    echo "$package is required for the CDO SDC bootstrap script and is not installed."
    echo "Installing $package"
    sudo apt-get install "$package" -y
  fi
done

# Create sdc user if it does not exist
if id sdc >/dev/null 2>&1; then
    echo "Found existing user: sdc"
else
    echo "Creating user: sdc"
    sudo adduser --gecos "" --disabled-password sdc --home "$sdc_home"
fi

# Make sure the sdc user's home dir exists
if [ ! -d /usr/local/cdo ]; then
    sudo mkdir "$sdc_home"
    sudo chown sdc:sdc "$sdc_home"
fi

# Create the docker group if it does not exist
if [ $(getent group docker) ]; then
    echo "Found existing group: docker"
else
    echo "Creating group: docker"
    sudo groupadd docker
fi

# Add the sdc user to the docker group
echo "Adding the sdc user to the group docker"
if [ ! $(getent group docker | grep -qw "sdc")]; then
    sudo usermod -aG docker sdc
fi

# Check for the docker daemon.json file
echo "Checking to see if the file daemon.json file exists in /etc/docker"
daemon_json='{"live-restore": true, "group": "docker"}'

if [ -f /etc/docker/daemon.json ]; then
  echo "/etc/docker/daemon.json exists. Please make sure the following parameters are in /etc/docker/daemon.json"
  echo $daemon_json
else
  echo "Writing file /etc/docker/daemon.json"
  echo ${daemon_json} > daemon.json
  sudo cp daemon.json /etc/docker/daemon.json
  rm daemon.json
fi

# Restart the docker daemon
echo "Restarting docker daemon"
sudo systemctl restart docker
echo "Docker status after restart:"
echo sudo systemctl status docker | grep 'Active'

# Decode bootstrap data and extract the needed pieces
echo "Decoding the bootstrap data..."
decoded_bootstrap=$(echo "$1" | base64 --decode)

# Write env vars to file for the sdc and also load the vars
printf '%s\n' ${decoded_bootstrap} > sdcenv
sudo cp sdcenv ${sdc_home}/sdcenv
source sdcenv
rm sdcenv

# Download the bootstrap file from CDO
echo Downloading CDO Bootstrap File
$(sudo curl --output "$sdc_home/${CDO_BOOTSTRAP_URL##*/}" --header "Authorization: Bearer ${CDO_TOKEN}" "$CDO_BOOTSTRAP_URL")

# Untarring CDO Bootstrap file
$(sudo tar xzvf "$sdc_home/${CDO_BOOTSTRAP_URL##*/}" --directory "$sdc_home")

# Remove the tar file
$(sudo rm "$sdc_home/${CDO_BOOTSTRAP_URL##*/}")

# chown the new files to sdc user
$(sudo chown --recursive sdc:sdc "$sdc_home")

# Final check for success and exit
if sudo test -f "${sdc_home}/bootstrap/bootstrap.sh"; then
  echo
  echo "***********************************************************************************************"
  echo "SDC pre-configuration scripts appears to have completed successfully."
  echo "Run the following commands to start the SDC configration process:"
  echo "sudo su sdc"
  echo "cd $sdc_home; source $sdc_home/sdcenv; $sdc_home/bootstrap/bootstrap.sh"
  echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
else
  echo "***********************************************************************************************" >&2
  echo "Something went wrong with the pre-configuration script." >&2
  echo "Post your issue in github and include the output from this script with the debug option enabled" >&2
  echo "bash -x sdc-pre-config.sh" >&2
  echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" >&2
fi
