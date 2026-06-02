if (-not (Test-Path ./mongo-keyfile)) {
    docker run --rm -v "${PWD}:/output" mongo:7.0 `
        bash -c "openssl rand -base64 756 > mongo-keyfile && chmod 400 mongo-keyfile && chown 999:999 mongo-keyfile"
}

docker compose up -d --build

Write-Host "Waiting for MongoDB nodes to start..."
Start-Sleep -Seconds 10

for ($i = 1; $i -le 20; $i++) {
    $STATUS = docker inspect --format='{{.State.Health.Status}}' mongo1 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $STATUS) { $STATUS = "starting" }
    Write-Host "mongo1 health: $STATUS (attempt $i)"
    if ($STATUS -eq "healthy") {
        break
    }
    Start-Sleep -Seconds 3
}

docker exec mongo1 mongosh `
    -u $env:MONGO_ROOT_USER `
    -p $env:MONGO_ROOT_PASSWORD `
    --authenticationDatabase admin `
    --eval '
        rs.initiate({
            _id: "rs0",
            members: [
            { _id: 0, host: "mongo1:27017", priority: 2 },
            { _id: 1, host: "mongo2:27017", priority: 1 },
            { _id: 2, host: "mongo3:27017", priority: 1 }
            ]
        })
'

Write-Host "Waiting for PRIMARY election..."
for ($i = 1; $i -le 30; $i++) {
    $STATE = docker exec mongo1 mongosh `
        -u $env:MONGO_ROOT_USER `
        -p $env:MONGO_ROOT_PASSWORD `
        --authenticationDatabase admin `
        --quiet `
        --eval "rs.status().members.find(m => m.stateStr === 'PRIMARY') ? 'PRIMARY_FOUND' : 'WAITING'" `
        2>$null
    if ($LASTEXITCODE -ne 0 -or -not $STATE) { $STATE = "WAITING" }
    Write-Host "Election state: $STATE (attempt $i)"
    if ($STATE -eq "PRIMARY_FOUND") {
        Write-Host "Replica set is ready"
        break
    }
    Start-Sleep -Seconds 2
}

docker exec mongo1 mongosh `
    -u $env:MONGO_ROOT_USER `
    -p $env:MONGO_ROOT_PASSWORD `
    --authenticationDatabase admin `
    --eval "rs.status().members.forEach(m => print(m.name, m.stateStr))"
