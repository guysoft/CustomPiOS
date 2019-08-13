#!/bin/bash
#
# Helper script from the CustomPiOS admin-toolkit module

#only run if root
if [ `whoami` != root ]; then
    echo " To change a the hostname please run this script as root or using sudo."
    echo " exiting...."
    exit
fi

read -p " Enter your new host name[leave blank to skip]: " host
HOSTNAME=${host:-skip}
if [ "$HOSTNAME" != "skip" ]
then
    echo " Changing the hostname to:" $HOSTNAME
    echo "  Your pi will reboot with the new configuration."
    read -p " Press enter to continue or ctrl+c to exit.: ......."
    echo $HOSTNAME > /etc/hostname
else
    echo " Skipping hostname change. Removing chromium Singleton"
fi

sudo pkill chromium
sudo rm -rf /home/pi/.config/chromium/Singleton*
sudo reboot -h now

