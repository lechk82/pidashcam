#!/bin/bash -e

# Please ensure you specify "OS_TYPE"="dride-plus" as an environment variable
# IF you wish to enable advanced feature for Dride/Rpi3
# Do not include if you are building for RPiZW


install -m 755 files/etc_initd_dride-core ${ROOTFS_DIR}/etc/init.d/dride-core
install -m 644 files/lib_udev_hwclock-set ${ROOTFS_DIR}/lib/udev/hwclock-set

#install -m 644 files/systemctl/ble.service ${ROOTFS_DIR}/lib/systemd/system/ble.service
install -m 644 files/systemctl/record.service ${ROOTFS_DIR}/lib/systemd/system/record.service
install -m 644 files/systemctl/ws.service ${ROOTFS_DIR}/lib/systemd/system/ws.service
install -m 644 files/systemctl/live.service ${ROOTFS_DIR}/lib/systemd/system/live.service
#install -m 644 files/systemctl/led.service ${ROOTFS_DIR}/lib/systemd/system/led.service
install -m 644 files/systemctl/rtc.service ${ROOTFS_DIR}/lib/systemd/system/rtc.service

install -m 644 files/systemctl/fbcp-ili9341.service ${ROOTFS_DIR}/lib/systemd/system/fbcp-ili9341.service

#on_chroot << EOF

#-------------------------------------------------------
# Script to check if all is good before install script runs
#-------------------------------------------------------
echo "====== Dride install script ======"
echo ""
echo ""
echo ""
echo "██████╗ ██████╗ ██╗██████╗ ███████╗"
echo "██╔══██╗██╔══██╗██║██╔══██╗██╔════╝"
echo "██║  ██║██████╔╝██║██║  ██║█████╗  "
echo "██║  ██║██╔══██╗██║██║  ██║██╔══╝  "
echo "██████╔╝██║  ██║██║██████╔╝███████╗"
echo "╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝ ╚══════╝"
echo ""
echo ""
echo "This will install all the necessary dependences and software for dride."
echo "======================================================="
echo ""
echo ""



echo ""
echo ""
echo "==============================="
echo "*******************************"
echo " *** STARTING INSTALLATION ***"
echo "  ** this may take a while **"
echo "   *************************"
echo "   ========================="
echo ""
echo ""

cd /home

# Install dependencies
echo "========== Update Aptitude ==========="
sudo apt-get update -y
# sudo apt-get upgrade

echo "========== Installing gpac ============"
# provides MP4Box
sudo apt-get install gpac -y

echo "========== Installing htop ============"
sudo apt-get install htop -y


echo "========== Setup libav  ============"
# provides avconv
sudo apt-get install ffmpeg -y
sudo ln -s /usr/bin/ffmpeg /usr/bin/avconv

echo "========== Installing Node ============"
wget -O - https://raw.githubusercontent.com/sdesalas/node-pi-zero/master/install-node-v8.9.0.sh | bash

echo "========== Installing pip ============"
sudo apt-get install python-pip -y

# enable camera on raspi-config and allocate more ram to the GPU
echo "" >> /boot/config.txt
echo "#enable piCamera" >> /boot/config.txt
echo "start_x=1" >> /boot/config.txt
echo "gpu_mem=144" >> /boot/config.txt
echo "dtparam=spi=on" >> /boot/config.txt

# express on startup
sudo systemctl enable ws

# dride-core on startup
sudo update-rc.d dride-core defaults
sudo systemctl enable record
#sudo systemctl enable ble
#sudo systemctl enable led
#sudo systemctl enable rtc

echo "========== Setup RTC  ============"
# https://learn.adafruit.com/adding-a-real-time-clock-to-raspberry-pi/set-rtc-time
sudo apt-get install python-smbus i2c-tools -y

# add to /boot/config.txt
#echo "dtoverlay=i2c-rtc,ds1307" >> /boot/config.txt
#echo "dtparam=i2c_arm=on" >> /boot/config.txt

# add to /etc/modules
#echo "i2c-dev" >> /etc/modules
#echo "rtc-ds1307" >> /etc/modules


# Remove hw-clock
#sudo apt-get -y remove fake-hwclock
#sudo update-rc.d -f fake-hwclock remove

# we will sync the current date form the app using BLE
# looks at /daemon/bluetooth/updateDate.js


#echo "========== Setup Accelerometer  ============"
# http://www.stuffaboutcode.com/2014/06/raspberry-pi-adxl345-accelerometer.html
# enable i2c 0
#echo "# Accelerometer" >> /boot/config.txt
#echo "dtparam=i2c_vc=on" >> /boot/config.txt


echo "========== Install Dride-core   ============"
sudo cp files/dride.zip /home/
cd /home/
# https://s3.amazonaws.com/dride/releases/dride/latest.zip
# sudo wget -c -O "core.zip" "https://s3.amazonaws.com/dride/releases/dride/latest.zip"
sudo unzip "dride.zip"
sudo rm -R dride.zip
cd core
echo '{"name":"drideOS","version":"1.0.0","settings":{"debug":false,"videoRecord":true,"flipVideo":true,"gps":false,"speaker":false,"mic":false,"indicator":false,"resolution":"1080","fps":"25","clipLength":"1","gSensorSensitivity":"medium","netwrok":{"ssid":"dashcam","password":"dashcam"}}}' | sudo tee /home/core/config.json
sudo chmod 777 config.json

echo "========== Create video path ==========="
# create the video/content destination
sudo mkdir -p /dride/clip /dride/thumb /dride/tmp_clip


sudo chmod 777 -R /dride/
sudo chmod 777 -R /home/core/modules/settings/
# make gps position writable
# sudo chmod +x /home/core/daemons/gps/position

# make the firmware dir writable
sudo chmod 777 -R /home/core/firmware/

# make the state dir writable
sudo chmod 777 -R /home/core/state/

# run npm install on dride-ws
cd /home/core/dride-ws
sudo npm i --production

# run npm install on modules/video
cd /home/core/modules/video
sudo chmod 0777 savedVideos.json
sudo npm i --production

echo "========== Add CronJobs  ============"

# setup clear cron job
sudo touch /var/spool/cron/crontabs/root
sudo crontab -l > cronJobs

# setup cleaner cron job
echo "* * * * * sudo node /home/core/modules/video/helpers/cleaner.js" | sudo tee -a cronJobs

# setup ensureAllClipsAreDecoded cron job
echo "* * * * * sudo node /home/core/modules/video/helpers/ensureAllClipsAreDecoded.js" | sudo tee -a cronJobs

sudo crontab cronJobs
sudo rm cronJobs

echo "========== Install Display  ============"

sudo apt-get install cmake -y
cd ~
git clone https://github.com/juj/fbcp-ili9341.git
cd fbcp-ili9341
sed -i '/#define DISPLAY_SPI_DRIVE_SETTINGS (0)/c\#define DISPLAY_SPI_DRIVE_SETTINGS (1 | BCM2835_SPI0_CS_CPOL | BCM2835_SPI0_CS_CPHA)' display.h
mkdir build
cd build
cmake -DST7789=ON -DBACKLIGHT_CONTROL=ON -DGPIO_TFT_DATA_CONTROL=25 -DGPIO_TFT_RESET_PIN=24 -DGPIO_TFT_BACKLIGHT=23 -DSPI_BUS_CLOCK_DIVISOR=12 -DSTATISTICS=1 ..
make -j
cd ~
sudo systemctl enable fbcp-ili9341

#echo "========== Install LED  ============"
#sudo apt-get install scons -y
#echo "# Needed for SPI LED" >> /boot/config.txt
#echo "core_freq=250" >> /boot/config.txt

#cd /home/core/modules/led
#sudo npm i
#sudo chmod 0777 bin/main

#echo "========== Setup bluetooth  ============"
#sudo apt-get install bluetooth bluez libbluetooth-dev libudev-dev -y
## run npm install on Bluetooth daemon
#cd /home/core/daemons/bluetooth
#sudo npm i --production


echo ""
echo '============================='
echo '*****************************'
echo '========= Finished =========='
echo '*****************************'
echo '============================='
echo ""

#EOF
