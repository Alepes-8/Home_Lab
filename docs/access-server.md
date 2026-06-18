# Accessing the server

The server can be accessed through a shh connection based on a password and ip address. However, as this is not to be shared anywhere the important part of the documentation is that this will explain the genreal premise of how to access it, and how to create a static ip address.

## Static server IP

When working with the system it is a good idea to set the server ip to a static set value, so that even when the system goes down, or needs to be moved the address will remain the same for the server on the local network. This allows the system that we are working with to always know where it should route its messages to send it to the server or any of the other unites that are up. Especially good for proxies or middle ware that will handle the communication into the house network.

### How to

The following steps will explain how one can setup a static server. Good to know, this will very slightly based on the router you have, but the overall princable is the same.

- Login to the server, and write "ip a". This should give all information of the servers current address
- Access the router through 192.168.1.1, by adding it to the browser bar
- Login to your router
- Find the static dhcp reservations, or static lease, or address reservations.
- add the servers mac address to the router, based on what you find in the first step.
    - This can also be done by scrolling through the currenly connected units to the router. Select the server.

## Accessing through ssh

When accessing the server, as it is ment to be handled remotly it is important to know how it can be done. The following steps will be given based on the current setup without password and sensative information. 

- open the cmd promt
- write `ssh homelab@192.168.1.xxx` and press enter
    - the name **homelab** would be set in the setup steps of the server. This name can be anything
    - the **xxx** represent the specific ip address that was set in the **How to** step of **Static server IP**
- write yes when it asks for fingerprint
- write the password, press enter, and you are in.

## UFW (Uncomplicated Firewall)

Is a tool to control what the network traffic allows in and out of the server. By defualt it blocks everything, but with the current setup it will allow for 
- 22 — SSH, so you can actually connect to the machine remotely
- 5001 — prod API
- 5002 — staging API
- 80 — HTTP Nginx (for when that's set up) (unencrypted)
- 443 - HTTPS Nginx  (encrypted, via TLS/SSL)