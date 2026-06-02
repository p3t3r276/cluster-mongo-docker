# Mongo Replica Cluster

```bash
docker-compose up -d  --build 
```

Manually config cluster
```bash
docker exec mongo1 mongosh -u admin -p supersecretpassword --au
thenticationDatabase admin --file /docker-entrypoint-initdb.d/init-replicaset.js
```

Connection string:
```text
mongodb://admin:supersecretpassword@mongo1:27017,mongo2:27018,mongo3:27019/?replicaSet=rs0&authSource=admin
```

Connnect to mongo2
```bash
docker exec -it mongo2 mongosh \
-u admin -p supersecretpassword \
--authenticationDatabase admin \
--eval "rs.status().members.forEach(m => print(m.name, m.stateStr, m.health))" \
--port 27018
```
```powershell
.\setup.ps1
```

```bash
chmod +x setup.sh
./setup.sh
```