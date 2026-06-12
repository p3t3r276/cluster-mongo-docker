#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Check if .env file exists
if [ -f .env ]; then
    # Read file line by line, ignoring comments and blank lines
    while IFS='=' read -r key value || [ -n "$key" ]; do
        # Skip comments
        [[ "$key" =~ ^#.*$ ]] && continue
        # Skip empty lines
        [[ -z "$key" ]] && continue
        
        # Remove any leading/trailing whitespace or quotes from the value
        value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
        
        # Dynamically export the variable
        export "$key"="$value"
    done < .env
else
    echo "Warning: .env file not found."
fi

echo $MONGO_ROOT_USER
echo $MONGO_ROOT_PASSWORD

# 1. Check if the keyfile exists, if not generate it
if [ ! -f ./mongo-keyfile ]; then
    docker run --rm -v "${PWD}":/output -w /output mongo:7.0 \
        bash -c "openssl rand -base64 756 > ./mongo-keyfile && chmod 400 ./mongo-keyfile && chown 999:999 ./mongo-keyfile"
fi

# 2. Start the containers
docker compose -f new.yml up -d --build

echo "Waiting for MongoDB nodes to start..."
sleep 10

# 3. Wait for mongo1 to become healthy
for i in {1..20}; do
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' mongo1 2>/dev/null)
    
    # If the command failed or status is empty, default to "starting"
    if [ $? -ne 0 ] || [ -z "$STATUS" ]; then
        STATUS="starting"
    fi
    
    echo "mongo1 health: $STATUS (attempt $i)"
    
    if [ "$STATUS" = "healthy" ]; then
        break
    fi
    sleep 3
done

# 4. Initiate the Replica Set
docker exec mongo1 mongosh \
    -u "$MONGO_ROOT_USER" \
    -p "$MONGO_ROOT_PASSWORD" \
    --authenticationDatabase admin \
    --eval '
        rs.initiate({
            _id: "rs0",
            members: [
            { _id: 0, host: "mongo1:27017", priority: 2 },
            { _id: 1, host: "mongo2:27018", priority: 1 },
            { _id: 2, host: "mongo3:27019", priority: 1 }
            ]
        })
'

# 5. Wait for the PRIMARY node to be elected
echo "Waiting for PRIMARY election..."
for i in {1..30}; do
    STATE=$(docker exec mongo1 mongosh \
        -u "$MONGO_ROOT_USER" \
        -p "$MONGO_ROOT_PASSWORD" \
        --authenticationDatabase admin \
        --quiet \
        --eval "rs.status().members.find(m => m.stateStr === 'PRIMARY') ? 'PRIMARY_FOUND' : 'WAITING'" \
        2>/dev/null)
        
    if [ $? -ne 0 ] || [ -z "$STATE" ]; then
        STATE="WAITING"
    fi
    
    echo "Election state: $STATE (attempt $i)"
    
    if [ "$STATE" = "PRIMARY_FOUND" ]; then
        echo "Replica set is ready"
        break
    fi
    sleep 2
done

# 6. Print final replica set status
docker exec mongo1 mongosh \
    -u "$MONGO_ROOT_USER" \
    -p "$MONGO_ROOT_PASSWORD" \
    --authenticationDatabase admin \
    --eval "rs.status().members.forEach(m => print(m.name, m.stateStr))"
