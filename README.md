# MongoDb Cluster with Docker Compose

Using `docker` and `bitnami/mongodb` image

Check status

```bash
docker exec -it mongodb-primary mongosh -u root -p admin123 --eval "rs.status()"
```