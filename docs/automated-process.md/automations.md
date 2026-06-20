# Automations

The project has several automated processes, some placed locally on the server and some external. The different repos have their own CI/CD processes, separate from this project, but they're required in order for the docker-compose files to acquire an image from the respective repos. Furthermore, this project has two prominent automated processes: the Jenkins setup and the GitHub runners. Lastly, there's a separate automated process running on the Raspberry Pi, or another external setup, which holds the WireGuard VPN and the Prometheus/Grafana setup, scraping for information on the server.

For further information, go to the respective documentation for each automated process.

## Responsibilites

- Jenkins: handles rollback for both staging and prod, and the production envinroments as a whole. In order to handle that that the process isn't automated fully, though an automated process in the case what would be pulled doesn't work as intended.
- Github runner: Runs the process of ppulling and deploying the most recently updated staging image to the server
- raberry pi: handles the vpn, and the scraping and visualisation of data in the server.