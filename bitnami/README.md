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

3. Check clsuter status
```bash
docker exec -it mongo-primary mongosh --eval "rs.status()"
```

4. Shut down
```bash
docker-compose -f bitnami.yml down --rmi local --volumes 
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
docker exec -it mongodb-primary mongosh -u root -p {MONGODB_DEFAULT_PASSWORD} --eval "rs.status()"
```
