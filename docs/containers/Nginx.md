# Nginx Info (A reverse proxy)

- It's the middleman that the browser contacts, which then navigates to and contacts the necessary server/container.
- It's connected to the same Docker container network, so it can reach the containers on its own.
    - We don't want each container to have its own separate network. It's more important that they share one, so they can communicate with each other when needed — in this case, so Nginx can contact prod and staging as needed.
    - We add the network connection into the docker-compose files so it gets joined. We can set up individual networks if we don't want some projects to be on the same network, but for now the plan is to keep them on the same network.

## Docker Compose

The docker-compose for Nginx handles the setup for its respective container, decoupled from the `docker-compose.prod.yml` and `docker-compose.staging.yml` setups. This means that even if prod isn't up or the staging containers aren't set up, Nginx will still be configured correctly and work as the middleman to handle the different requests. In the current setup, Nginx uses one `nginx.conf` that handles all the different connections, rather than separating them by prod and staging.

Further down the line, once multiple projects are running, Nginx will also be updated to route to different projects using different `server_name`s.

## nginx.conf

Note: `nginx.conf` contains some useful information worth keeping in mind if a new project needs to be added to the homelab.

- **port**: The different connections share the same port, since that's how clients reach Nginx in the first place.
- **server_name**: The name that distinguishes what one wants to call something from within the network.
- **location**: Tells Nginx where a resource is located and how it should be reached.

## Sites

For a smaller system, it's reasonable to place all the service locations in one `nginx.conf` file. However, in order to create some separation and allow for decoupling of responsibilities, the different Docker Compose setups have been split into different site files — so staging lives in its own `staging.local.conf` file.

Note: if one later wants to add a new service, it can be worth updating the location so it says `location /api` instead of `location /`. This would allow the system to differentiate between one service and another — for example, one being `location /api` and another `location /weight`.

## Protection

Nginx listens on one or more ports, which allows users to contact the system through that port (80, in this case). This means we cannot go around nginx by contacting port 80 directly, since doing so *is* contacting nginx. We can circumvent nginx if other ports are open, such as 5001 or 5002; however, if no other ports are open, then all communication must go through nginx's reverse proxy port.