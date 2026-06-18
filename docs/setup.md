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

When setting up the code there are multiple ways to do so. But the cleanest way to go through the setup and have it done correctly is by following the give steps:

1. Clone the repo onto your development machine and to the following prepwork
    1. get your public key for the **bootstap.sh file**, which is done through
        ```
        cat ~/.ssh/id_ed25519.pub
        ```
        - if you done have one, run
        ```
        ssh-keygen -t ed25519 -C "your@email.com"
        ```
        - which creates ~/.ssh/id_ed25519 — private key, never touch this and ~/.ssh/id_ed25519.pub — public key, this is what you share. it will then look like ssh-ed25519 AAAAC3Nza... your@email.com
        - copy the whole string and add it to the bootstrap.sh file, where it asks for TODO
    2. create .env.prod and create .env.staging
        - make sure you update mongo_uri to the following as it should not be local host.
        ```
        MONGO_URI=mongodb://mongo:27017/drink
        ```
        - make sure they are placed in the docker-compose folder to make sure its easy to apply in the docker-compose.staging and prod
2. Open a terminal in the scripts folder, then get bootstrap onto server via one of the following options 
    1. Copies the file from your local machine to the server over SSH. Then SSH in and run it.
    ``` 
    scp bootstrap.sh homelab@192.168.1.xxx:~/bootstrap.sh  
    ```
    2. copy paste: SSH into the server, create the file manually 
    ```
    nano bootstrap.sh
    # paste the contents, Ctrl+X to save
    sudo bash bootstrap.sh
    ```
    3. curl from GitHub (cleanest): If your repo is public, you can pull the raw file directly on the server
    ```
    curl -o bootstrap.sh https://raw.githubusercontent.com/Alepes-8/Drink-CatalogV2/main/scripts/bootstrap.sh
    sudo bash bootstrap.sh
    ```
3. Login to the server through ssh connection. read **access-server.md** for further descriptions on how to do that.
4. Run bootstrap — installs Docker, configures firewall, adds SSH key
    - run bootstrap by executing the following command:
    ```
    cd scripts
    sudo bash bootstrap.sh
    ```
    - When it asks if you wanna automaticly restart docker deamon, say yes.
5. Clone the repo onto the server
    ```
    git clone https://github.com/Alepes-8/Home_Lab.git
    ```
6. Copy .env files onto the server via scp
    - as the **.env** is never commited due to **.gitignore** we make sure that we add env correctly. So we can use scp
    ```
    scp /e/Programing/Home_Lab/Drink-CatalogV2/.env.prod user@192.168.1.30:~/Drink-CatalogV2/.env.prod
    scp /e/Programing/Home_Lab/Drink-CatalogV2/.env.staging user@192.168.1.30:~/Drink-CatalogV2/.env.staging
    ```
7. Go through the step 1-5 that is proposed after the bootstap.sh is executed
8. run 
```
docker network create homelab-network
```
8. Run the rollback script or docker compose manually