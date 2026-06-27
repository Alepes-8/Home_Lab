# Router setup



## set static ip addresses

The following steps will explain how one can setup a static server. Good to know, this will very slightly based on the router you have, but the overall princable is the same.

- Login to the server, and write "ip a". This should give all information of the servers current address
- Access the router through 192.168.1.1, by adding it to the browser bar
- Login to your router
- Find the static dhcp reservations, or static lease, or address reservations.
- add the servers mac address to the router, based on what you find in the first step.
    - This can also be done by scrolling through the currenly connected units to the router. Select the server.