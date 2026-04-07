# Setup

The following steps will be devided up into different sections based on where one may be in the process of setting this system up. Either it can be from the beginning, from where one doesn't have a server setup with ubundu yet, or just from where one wanna setup this home lab. But overall, the documentaiton should explain the process no matter which of the steps that one are on.

Note, that these steps are explained based on the system ubuntu 24.04.4 LTS. It can different depending on what they decide to do as changes. But the steps should still be a good representation of how it can be setup and processed.

## Server setup

This section will go through the core installations and setups that are required for setting up the hardware to be able to work with the given project. 

### Linux/server core

This is the steps for ubuntu and the core steps to just install ubuntu


#### Ubuntu installation
prerequisites
- aquire a system that can be used for the server, either an old laptop, computer, server, or other computer system that you wanna use based on the popruse and use cases. 
- aquire a screen and internet connection that are connected and plugged into the server
- plug in a keyboard to the server
- have an empty usb

setup
- Plug the usb into your computer(not server) and go to [link][https://ubuntu.com/download/desktop] and download the LTS lates ubuntu version
- Download balenaEtcher, and open balenaEtcher as it is finished
- In balenaEtcher, find the Ubuntu download and select it, with the destination of the USB stick.
- When balenaEtcher, is finished, take the USB Stick and unplug it and plug it into the server system
- Open Boot, select from file, and select the usb stick. If there are multiple efi files, select bootx64.efi.
- Now go through the process if setting it up. Make sure that the network is set to eno1 or eno0, with both IPv6 and IPv4 setup
- Continue through the steps, but **Important** remeber what you set as your **password** and set as **server name**, as both will be required when accessing the system. When OpenSsh Server is an option install, and **DO NOT SKIP*
    - The following things can be done as desired. But if you wonder you can do the following settings for some of the steps. Leave vlan blank, no proxy, no encryption with lvl group luks, skip ubuntu pro.
    - The difference between Your name, username, and servername: your name is the display name and is cosmetic only, username is to login through the ssh username@192.168.1.xxx, and the server name is what the machine calls itself within the network.
- Do not import snaps

#### Core server installation setup

When the ubuntu server is setup it is time to setup the require pre requirstes, which is a installations and static server ip.

- Follow the steps found in access-server.md for setting up a static ip, and accessing through ssh values. 
    - note the values are what was set in the ubuntu installation steps
- Access the server and run
    - sudo apt update && sudo apt upgrade -y ( get the fully up to date system before anything else)
    - sudo apt install docker.io -y  (Install docker)
    - sudo usermod -aG docker $USER  (Logs in, so sudo isn't required every time)
    - exit  (To allow the previous step to go into effect)
- access server again and run
    - docker run hello-world (This will verify that the setup of docker was done correctly)


## project setup