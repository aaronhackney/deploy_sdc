# deploy_sdc.sh
This is a script to simplify installing the Cisco Defense Orchestrator (CDO) Secure Device Connector (SDC) on a Linux Ubuntu system (Tested on Ubuntu 22.04 - Jammy). The script is based on the manual steps required to run the SDC docker container on one's own Linux system as documented [here](https://docs.defenseorchestrator.com/index.html#!t_deploy-a-secure-device-connector-on-your-own-vm.html).  
  
The SDC is just a docker container that facilitates communication between Cisco Adaptive Security Appliance (ASAs) firewalls, Cisco IOS Devices (Routers and Switches), and other SSH based integrations.

## Ubuntu system requirements
This script was written using Ubuntu 22.04 as the test system. Your milage may vary on older Ubuntu releases.  
  
Requirements are for both bare-metal Ubuntu installations and virtual installations (Like qemu, vmware, etc)  
- SDC Container Only
  - CPU Requirement: 2 CPU Cores/vCPUs
  - RAM Requirement: 2 Gig
- SDC and Secure Events Connector (SEC) Containers
  - CPU Requirement: 6 CPU Cores/vCPUs
  - RAM Requirement: 10 Gig

## Docker
The SDC is a container that runs in docker. See the README-DOCKER.md file for more information about installing Docker.

## Create the SDC in your CDO tenant
1. Log into your CDO Tenant and navigate to Tools & Services --> Secure Connectors
2. Click the blue (+) button and add a Secure Device Connector (SDC)
3. Copy the `CDO Bootstrap Data` text string and paste it in text document for reference later

## What does the deploy_sdc.sh script do?
1. Checks to make sure the required apt packages are installed (awscli and net-tools) and install them if they are not present.
2. Add a new user `sdc`. This is the user under which the SDC container will run.
3. Create the `sdc` user's home directory at `/usr/local/cdo`
4. Add the `sdc` user to the `docker` group to give the `sdc` users permissions to start and stop containers
5. Check that the `/etc/daemon.json` file exists. If the file does not exist, create it.
6. Restart the docker daemon and display the docker daemon status. **Note**: If you have existing containers, this restart will impact them.
7. Write the bootstrap data to the file `/usr/local/cdo/sdcenv` for the bootstrap script to use
8. Download the `bootstrap.sh` script from CDO specific to your tenant and uncompress the tar file

## How to run the deploy_sdc.sh script
We will sudo run the `deploy_sdc.sh` with the `CDO Bootstrap Data` that you copied from the CDO tenant portal as the only parameter for the script. Note that the `CDO Bootstrap Data` will wrap several lines in your terminal. This is fine and there is no need to try and split the data into smaller chunks.
Example:
```
sudo ./sdc_prep.sh Q0RPX1RPS0VOPSJleU...Y29fYWFoYWNrbmUtU0RDLTQiCg==
```

## Download and run the containers
If everything was successful, you should be ready to execute the bootstrap script that configures, loads, and runs the SDC docker image.
```
sudo su sdc
cd /usr/local/cdo/; source sdcenv; /usr/local/cdo/bootstrap/bootstrap.sh
```
