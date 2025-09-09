# MongoDb Cluster with Docker Compose

Using `docker` and `bitnami/mongodb` image

1. Get your machine IP address
```bash
ipconfig
```
On `macOS` and `Linux` Look for the IP address associated with your main network interface (e.g., `eth0`, `enp0s3`, `wlo1`). It will likely be in a range like `192.168.x.x` or `10.0.x.x`
On `Windows`: Look for your "Ethernet adapter" or "Wi-Fi adapter" and find the "IPv4 Address."

2. Start mongo
```bash
docker-compose -f cluster2.yml up -d --build
```

3. Config cluster
```bash
docker exec -it mongo1 mongosh
```
Paste this
```javascript
rs.initiate(
  {
    _id: "replicaset",
    members: [
      { _id: 0, host: "mongodb-primary:27017"  },  
      { _id: 1, host: "mongodb-secondary:27017" },
      { _id: 2, host: "mongodb-arbiter:27017", "arbiterOnly": true }
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
docker-compose -f cluster2.yml down --rmi local --volumes 
```

`Note`: Check also `host.docker.internal`
### connection string
```yaml
mongodb://YOUR_ACTUAL_DOCKER_HOST_IP:27017,YOUR_ACTUAL_DOCKER_HOST_IP:27018,YOUR_ACTUAL_DOCKER_HOST_IP:27019/?replicaSet=rs0
```

Check status

```bash
docker exec -it mongodb-primary mongosh -u root -p admin123 --eval "rs.status()"
```