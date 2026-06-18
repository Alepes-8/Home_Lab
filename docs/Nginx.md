# Nginx info

- middleman that the browser contact and then in turn it will be used to navigate and contat the nessusary server/container
- it will be connected to the same docker container network, so that way it can know how to contact the containers on it's own. 
    - we don't want each of tyhe containers to have one network each. Rather it is more important that they share it, so that they can communicate between eachother if needed. in this case so that nginx can contact the prod and staging as needed.
    - we add the network connection into the docker-compose files so that it is joined. We can set individual networks up, if we wouldn't want some projects to be on the sam enetwork, but as of now the plan is to leave it on the same networks.