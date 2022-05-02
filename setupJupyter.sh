#!/bin/bash

##################################################################
# Description: Install and setup Jupyter Lab as a hosted service #
#              on a Raspberry Pi, with auto-restart at boo-up.   #
#                                                                #
# Tested on: Rasbian Lite (buster), Ubuntu for Pi4.              #
##################################################################

# user input
printf "Do you want to utilize SSL? [(y)es, no] "
read useSSL

if [ ${useSSL:0:1} == y ]
then
	sudo apt install openssl

	printf "\n\nDo you wish to create a self-signed cert? [(y)es, no] "
	read genCert

	if [ ${genCert:0:1} == y ]
	then
		printf "\nGenerating self signed certs..."
		openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout mykey.key -out mycert.pem
		mkdir /home/$USER/certs

		mv mykey.key /home/$USER/certs/
		keyFile="/home/$USER/certs/mykey.key"
		mv mycert.pem /home/$USER/certs/
		certFile="/home/$USER/certs/mycert.pem"

		printf "Generated $certFile and $keyFile\n\n"
	else
		printf "\nPlease enter the full path to your key file (*.key): "
		read keyFile

		printf "\nPlease enter the full path to your cert file (*.pem): "
		read certFile
	fi
fi

# install python modules
sudo rm /usr/bin/python 
sudo ln -s /usr/bin/python3 /usr/bin/python

sudo apt -y update
sudo apt -y install python3-matplotlib
sudo apt -y install python3-scipy
sudo apt -y install python3-pip
sudo pip3 install --upgrade pip

# install jupyterlab
sudo pip install jupyterlab

# setup jupyterlab config file
# setup jupyterlab as a service file
mkdir /home/$USER/notebooks
jupyter-lab --generate-config

printf "\n\nWhat port do you want to host JupyterLab on? (i.e. 8888) "
read port

printf "\nEnter desired token for JupyterLab access: \n"
read token
#token=`python -c "from notebook.auth import passwd
#print(passwd())"`

printf "\n\n"

printf "
c.ServerApp.notebook_dir = '/home/$USER/notebooks/'
#c.ServerApp.ip = '*'
c.ServerApp.token = '$token'
c.ServerApp.open_browser = False
c.ServerApp.port = $port\n" >> /home/$USER/.jupyter/jupyter_lab_config.py

printf "[Unit]
    Description=Jupyter Lab
[Service]
    Type=simple
    PIDFile=/var/run/ipython-notebook.pid
    Environment='PATH=$PATH:/user/local/bin/'
	 " > jupyterlab.service
if [ ${useSSL:0:1} == y ]
then
	printf "
c.ServerApp.certfile = u'$certFile'
c.ServerApp.keyfile = u'$keyFile'" >> /home/$USER/.jupyter/jupyter_lab_config.py
fi

printf "ExecStart=/usr/local/bin/jupyter-lab --config /home/$USER/.jupyter/jupyter_lab_config.py\n" >> jupyterlab.service

printf "User=$USER
    Group=$USER
    WorkingDirectory=/home/$USER
[Install]
    WantedBy=multi-user.target" >> jupyterlab.service

# setup jupyter lab service
sudo chmod 777 jupyterlab.service
sudo mv jupyterlab.service /lib/systemd/system/
sudo systemctl daemon-reload
sudo systemctl start jupyterlab
#sudo systemctl status jupyterlab

# look for the jupyter service
ps -ef | grep jupyter

# enable the jupyter service
sudo systemctl enable jupyterlab

#
echo "if you see the jupyter service, reboot the machine [sudo reboot]"


exit
