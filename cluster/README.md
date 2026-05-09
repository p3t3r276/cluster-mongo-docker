# MongoDb Cluster with Docker Compose

Using `docker` and `bitnami/mongodb` image

1. Get your machine IP address
```bash
ipconfig getifaddr en0
```
On `macOS` and `Linux` Look for the IP address associated with your main network interface (e.g., `eth0`, `enp0s3`, `wlo1`). It will likely be in a range like `192.168.x.x` or `10.0.x.x`
On `Windows`: Look for your "Ethernet adapter" or "Wi-Fi adapter" and find the "IPv4 Address."

2. Start mongo
```bash
docker-compose -f cluster.yml up -d --build
```

3. Config cluster
```bash
docker exec -it mongo1 mongosh
```
Paste this
```javascript
rs.initiate(
  {
    _id: "rs0",
    members: [
      { _id: 0, host: "mongo1:27017", "priority": 2  },
      { _id: 1, host: "mongo2:27018", "priority": 1 },
      { _id: 2, host: "mongo3:27019", "priority": 0 }
    ]
  }
);
```
Exit mongosh
```bash
exit
```
4. Check clsuter status
```bash
docker exec -it mongo1 mongosh --eval "rs.status()"
```

5. Shut down
```bash
docker-compose -f cluster.yml down --rmi local --volumes 
```

`Note`: Check also `host.docker.internal`
### connection string
```yaml
mongodb://root:{MONGODB_DEFAULT_PASSWORD}@YOUR_ACTUAL_DOCKER_HOST_IP:27017,YOUR_ACTUAL_DOCKER_HOST_IP:27018,YOUR_ACTUAL_DOCKER_HOST_IP:27019/?replicaSet=rs0
```

Example `localhost`:
```yaml
mongodb://root:{MONGODB_DEFAULT_PASSWORD}@localhost:27017,localhost:27018,localhost:27019/admin?replicaSet=rs0
```

Check status

```bash
docker exec -it mongo1 mongosh -u root -p admin123 --eval "rs.status()"
```
