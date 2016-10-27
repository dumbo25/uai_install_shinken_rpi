#!/bin/bash

# Unattended install for shinken on Raspberry Pi running dietpi or raspbian
# run with the command:
#   bash ./shinken_uai.sh

# Edit to match your settings
username="pi"
password="raspberry"
homedir="/home/pi"

clear
echo "ShinkenUAI: Starting unattended install of shinken on a Rasppberry Pi"
echo "ShinkenUAI: shinken requires DietPi or raspbian"
echo "ShinkenUAI: shinken requires user: $username and password: $password"

# shinken doesn't seem to care if init.d or systemd is used, both can be active
# systemd is recommended over init.d on raspbian
# need to update to systemd
# i=$(ps -p 1 -o comm=)
# if [ $i = "systemd" ] 
# then
# 	echo "Raspberry Pi is running systemd"
# elif [ $i = "init" ]
# then
# 	echo "Raspberry Pi is not running systemd"
# 	exit 1
# else
# 	echo "Raspberry Pi is not running systemd or init"
# 	exit 1
# fi

echo "ShinkenUAI: Check home directory"
cd ~/.
c=$(pwd)
if [ "$c" != "$homedir" ]
then
	echo "ShinkenUAI: Error: The unattended install runs on dietpi or raspbian"
	echo "ShinkenUAI: and requires user: $username with home directory: $homedir and not $c"
	echo "ShinkenUAI: Failed to install"
	exit 1
fi

echo "ShinkenUAI: Instructable step: Always update and upgrade"
echo "ShinkenUAI: Update available packages and their versions"
sudo apt-get update -y
if [ $? -ne 0 ]
then
	echo "ShinkenUAI: Error: Failed apt-get update"
	exit $?
fi

echo "ShinkenUAI: Upgrade before installing new packages"
sudo apt-get upgrade -y
if [ $? -ne 0 ]
then
	echo "ShinkenUAI: Error: Failed apt-get upgrade"
	exit $?
fi

echo "ShinkenUAI: Remove old packages that are no longer required"
sudo apt-get autoremove -y
if [ $? -ne 0 ]
then
	echo "ShinkenUAI: Error: Failed apt-get autoremove"
	exit $?
fi

echo "ShinkenUAI: Instructable step: Install shinken dependencies"
# Install sqlite3, php5, python3 and python libraries
echo "ShinkenUAI: Install sqlite3, if already installed it will skip"
sudo apt-get install sqlite3 -y
if [ $? -ne 0 ]
then
	echo "ShinkenUAI: Error: Failed install of sqlite3"
	exit $?
fi

echo "ShinkenUAI: Install php5, if already installed it will skip"
sudo apt-get install php5 -y
if [ $? -ne 0 ]
then
	echo "ShinkenUAI: Error: Failed install of php5"
	exit $?
fi

echo "ShinkenUAI: Install python3, if already installed it will skip"
sudo apt-get install python3 -y
if [ $? -ne 0 ]
then
	echo "ShinkenUAI: Error: Failed install of python3"
	exit $?
fi

echo "ShinkenUAI: Install python libraries, if already installed it will skip"
sudo apt-get install python-pip python-pycurl python-cherrypy3 python-setuptools -y
if [ $? -ne 0 ]
then
	echo "ShinkenUAI: Error: Failed install of python libraries"
	exit $?
fi
# might need to add this package: sudo apt-get install libsqlite3-dev

echo "ShinkenUAI: Instructable step: Install shinken"
echo "ShinkenUAI: Add shinken user, create shinken home directory, create shinken group"
sudo adduser shinken 
result=$?
if [ $result -eq 0 ]
then
	echo "ShinkenUAI: Shinken user added"
elif [ $result -eq 1 ]
then
	echo "ShinkenUAI: Shinken user already exists"
else
	echo "ShinkenUAI: Error: Failed to add shinken user"
	exit $?
fi

echo "ShinkenUAI: Use pip to install shinken"
sudo pip install shinken 
if [ $? -ne 0 ]
then
	echo "ShinkenUAI: Error: Failed to install shinken using pip"
	exit $?
fi

echo "ShinkenUAI: Add shinken user to sudoers"
sudo adduser shinken sudo
if [ $? -ne 0 ]
then
	echo "ShinkenUAI: Error: Failed to add shinken user to sudoers"
	exit $?
fi

echo "ShinkenUAI: Instructable step: Initialize and start shinken"
echo "ShinkenUAI: Initialize shinken"
sudo mkdir var/log/shinken
sudo chmod 777 /var/log/shinken
sudo service shinken stop
sudo shinken --init
if [ $? -ne 0 ]
then
	echo "ShinkenUAI: Error: Failed to initialize shinken"
	exit $?
fi

echo "ShinkenUAI: Start shinken"
sudo /etc/init.d/shinken start
if [ $? -ne 0 ]
then
	echo "ShinkenUAI: Error: Failed to start shinken"
	exit $?
fi

echo "ShinkenUAI: Verify shinken is configured properly"
/usr/bin/shinken-arbiter -v -c /etc/shinken/shinken.cfg
if [ $? -ne 0 ]
then
	echo "ShinkenUAI: Error: Shinken is not configured properly"
	exit $?
fi

echo "ShinkenUAI: Make shinken start on reboot"
update-rc.d shinken defaults
if [ $? -ne 0 ]
then
	echo "ShinkenUAI: Error: Failed to make shinken start on reboot"
	exit $?
fi

echo "ShinkenUAI: Instructable step: Setup and configure sqlite3"
echo "ShinkenUAI: Install sqlitedb"
sudo shinken install sqlitedb
if [ $? -ne 0 ]
then
	echo "ShinkenUAI: Error: Failed to install sqlitedb"
	exit $?
fi

# In many installations, the module name is SQLitedb - this won't work
{
  echo '  ## Module:      SQLite'
  echo '  ## Loaded by:   WebUI'
  echo '  # In WebUI: Save/read user preferences'
  echo '  define module {'
  echo '    module_name     sqlitedb'
  echo '    module_type     sqlitedb'
  echo '    uri             /var/lib/shinken/webui.db'
  echo '}'
} > /etc/shinken/modules/sqlitedb.cfg
sudo chmod 666 /etc/shinken/modules/sqlitedb.cfg

echo "ShinkenUAI: Instructable step: Install shinken Web UI"
echo "ShinkenUAI: Search webui"
sudo /usr/bin/shinken search webui 
if [ $? -ne 0 ]
then
	echo "ShinkenUAI: Error: Failed on search webui"
	exit $?
fi

echo "ShinkenUAI: Install webui"
sudo /usr/bin/shinken install webui
if [ $? -ne 0 ]
then
	echo "ShinkenUAI: Error: Failed to install webui"
	exit $?
fi


echo "ShinkenUAI: Overwrite CHANGE_ME with mypassword"
sudo sed -i -e 's/CHANGE_ME/mypassword/g' /etc/shinken/modules/webui.cfg
if [ $? -ne 0 ]
then
	echo "ShinkenUAI: Error: Failed to overwrite CHANGE_ME"
	exit $?
fi

echo "ShinkenUAI: Add webui to modules line"
sudo sed -i -e 's/    modules/    modules webui/g' /etc/shinken/brokers/broker-master.cfg
if [ $? -ne 0 ]
then
	echo "ShinkenUAI: Error: Failed to add webui to modules"
	exit $?
fi
# if webui was added twice remove second one
sudo sed -i -e 's/webui webui/webui/g' /etc/shinken/brokers/broker-master.cfg

echo "ShinkenUAI: Restart shinken"
sudo /etc/init.d/shinken restart
if [ $? -ne 0 ]
then
	echo "ShinkenUAI: Error: Failed to restart shinken"
	exit $?
fi


echo "ShinkenUAI: Instructable step: Add users and passwords"
echo "ShinkenUAI: Install configuration password"
sudo shinken install auth-cfg-password
if [ $? -ne 0 ]
then
	echo "ShinkenUAI: Error: Failed to install config password"
	exit $?
fi

echo "ShinkenUAI: Add auth-cfg-password to modules line"
sudo sed -i -e 's/    modules/    modules             auth-cfg-password,sqlitedb/g' /etc/shinken/modules/webui.cfg
if [ $? -ne 0 ]
then
	echo "ShinkenUAI: Error: Failed to add auth-cfg-password to modules"
	exit $?
fi
# if auth-cfg-password was added twice remove second one
sudo sed -i -e 's/auth-cfg-password,sqlitedb             auth-cfg-password/auth-cfg-password,sqlitedb/g' /etc/shinken/modules/webui.cfg


echo "ShinkenUAI: Restart shinken"
sudo /etc/init.d/shinken restart

# echo "ShinkenUAI: Verify shinken is configured properly"
# /usr/bin/shinken-arbiter -v -c /etc/shinken/shinken.cfg
# if [ $? -ne 0 ]
# then
# 	echo "ShinkenUAI: Error: Shinken is not configured properly"
# 	exit $?
# fi


echo -e "shinken successfully installed!\n"
echo "ShinkenUAI: Reboot Raspberry Pi with command: sudo reboot"
echo "ShinkenUAI: Open browser on laptop and enter the following in URL:"
echo "ShinkenUAI:    http://?raspberry-pi-ip?:7767"
echo "ShinkenUAI: Login using: admin, <your_raspberry_pi_password>"

exit 0
