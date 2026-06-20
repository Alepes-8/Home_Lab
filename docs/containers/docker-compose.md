# Docker composes

The docker compose files are created and structured in order to suport the home lab as well as possible with considerations of the popruse and end use of the server. Especially with consideration of being able to setup different docker envirnoments where we utulise prod and staging envirnoments based on the needs of the project. On top of that, suports multiple projects to be running at the same time. As each docker-compose can be extended to handle multiple projekts and their respective prod, staging, jenkins and monitring runs. Where especially the prod and staging environment is to suport this, where it has the core system to run, with volumes and database setup for the core comunications. But when a new project is to be added, the goal is to add with the files is that it only needs a secion for getting the prod or staging image from github action with the resepctive tag and deploy it.

## Components for prod & staging

The docker compose files are structure the same in both prod and staging, however it will have their internal content changed based on if it is staging and prod. Mainly the difference between them will be the following

- Prod will have **restart: unless-stopped**, which means that unless one manually calls docker compose down, it will restart its self if it ever goes down, no matter the error message.
- They have different image names, based on if it is prod or staging. Example: the **drink_api** is named *drink_api_prod* or *drink_api_staging* based on the envirnoment.
- Prod = port:5001, Staging = port:5002

### Mongo-db

The **mongo-db** container, is the container that contains all the db connections and tables. But more importantly not the data it self, but rather the structure, connections, and system in which the db works through. Rather it is the **volumes** that are used to store the data. So even if the ***mongo-db*** structure is adjusted and updated, the data isn't lost.

### Drink-api

The drink_api is the container that contains the **drink_catalog** api code. This container store the information needed in order for the api to work as intended. Futher information can be found on [drink_catalogV2][https://github.com/Alepes-8/Drink-CatalogV2] for more information on how it works.

### Nginx

This container acts as a proxy between the outer world and the different ports. Rather than making the input user know every port that wanna be used, the **nginx** handles the connection to specific ports, allowing the user to just call port *80* with a specific reference. Example the hostname can be api.local or staging.local in order to connect to the api, rather than IP:port.

### Volumes

The **Volumes** are used to store data, allowing the different containers to be adjusted and updated without the nessessity to repopulate the database with new data each time. Rather the **volumes** keep track of it, allowing for quicker updates, persistant data, and safe updates in between version. As the users, and data is kept between updates despite the change in other containers.