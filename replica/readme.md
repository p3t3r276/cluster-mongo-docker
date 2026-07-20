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

> **Host name resolution required.** The replica set advertises its members as
> `mongo1`/`mongo2`/`mongo3`. With `?replicaSet=rs0`, so the host must resolve them to
> `127.0.0.1` — otherwise the connection times out even though the cluster is healthy.
> Both setup scripts add these entries automatically: `setup-podman.ps1` may prompt for
> admin once (UAC), and `setup.sh` may prompt for `sudo`.
>
> To add them manually on **Windows**, append to `%windir%\System32\drivers\etc\hosts`
> (as Administrator); on **Linux/macOS**, append to `/etc/hosts` (with `sudo`):
>
> ```text
> 127.0.0.1 mongo1
> 127.0.0.1 mongo2
> 127.0.0.1 mongo3
> ```

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