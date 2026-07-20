# Ensure the host can resolve the replica-set member names (mongo1/mongo2/mongo3).
# The replica set advertises these internal container hostnames, so a client on the
# Windows host must resolve them to 127.0.0.1 or replica-set discovery times out.
function Add-MongoHostsEntries {
    $hostsPath = "$env:windir\System32\drivers\etc\hosts"
    $names = @("mongo1", "mongo2", "mongo3")
    $current = Get-Content -Path $hostsPath -ErrorAction SilentlyContinue
    $toAdd = foreach ($n in $names) {
        if (-not ($current | Select-String -Pattern "^\s*\d{1,3}(\.\d{1,3}){3}\s+$n(\s|$)" -Quiet)) {
            "127.0.0.1`t$n"
        }
    }

    if (-not $toAdd) {
        Write-Host "Hosts entries already present."
        return
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal] `
            [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltinRole]::Administrator)

    if ($isAdmin) {
        Add-Content -Path $hostsPath -Value $toAdd
    }
    else {
        $joined = ($toAdd -join "','")
        $cmd = "Add-Content -Path '$hostsPath' -Value @('$joined')"
        Start-Process powershell -Verb RunAs -Wait -ArgumentList "-NoProfile", "-Command", $cmd
    }
    Write-Host "Added hosts entries: $($toAdd -join ', ')"
}

# Check if .env file exists
if (Test-Path ".env") {

    # Read file line by line
    Get-Content ".env" | ForEach-Object {

        $line = $_.Trim()

        # Skip comments and blank lines
        if ($line -eq "" -or $line.StartsWith("#")) {
            return
        }

        # Split only on the first "="
        $parts = $line -split "=", 2

        if ($parts.Count -eq 2) {
            $key = $parts[0].Trim()
            $value = $parts[1].Trim()

            # Remove surrounding single or double quotes
            $value = $value -replace '^"', ''
            $value = $value -replace '"$', ''
            $value = $value -replace "^'", ''
            $value = $value -replace "'$", ''

            # Dynamically set environment variable for current PowerShell session
            Set-Item -Path "Env:$key" -Value $value
        }
    }

} else {
    Write-Warning ".env file not found."
}

Write-Host $env:MONGO_ROOT_USER
Write-Host $env:MONGO_ROOT_PASSWORD

# Make mongo1/mongo2/mongo3 resolvable from the host (see function above).
Add-MongoHostsEntries

if (-not (Test-Path ./mongo-keyfile)) {
    [Convert]::ToBase64String((1..756 | ForEach-Object { [byte](Get-Random -Minimum 0 -Maximum 256) })) | Out-File -Encoding ascii mongo-keyfile

    # icacls mongo-keyfile /inheritance:r /grant:r "${env:USERNAME}:(R)"
}

podman compose -f new2.yml up -d --build

Write-Host "Waiting for MongoDB nodes to start..."
Start-Sleep -Seconds 10

for ($i = 1; $i -le 20; $i++) {
    $STATUS = podman inspect --format='{{.State.Health.Status}}' mongo1 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $STATUS) { $STATUS = "starting" }
    Write-Host "mongo1 health: $STATUS (attempt $i)"
    if ($STATUS -eq "healthy") {
        break
    }
    Start-Sleep -Seconds 3
}

podman exec mongo1 mongosh `
    -u $env:MONGO_ROOT_USER `
    -p $env:MONGO_ROOT_PASSWORD `
    --authenticationDatabase admin `
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

Write-Host "Waiting for PRIMARY election..."
for ($i = 1; $i -le 30; $i++) {
    $STATE = podman exec mongo1 mongosh `
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

podman exec mongo1 mongosh `
    -u $env:MONGO_ROOT_USER `
    -p $env:MONGO_ROOT_PASSWORD `
    --authenticationDatabase admin `
    --eval "rs.status().members.forEach(m => print(m.name, m.stateStr))"

Write-Host ""
Write-Host "Connect with:"
Write-Host "mongodb://$($env:MONGO_ROOT_USER):$($env:MONGO_ROOT_PASSWORD)@mongo1:27017,mongo2:27018,mongo3:27019/?replicaSet=rs0&authSource=admin"
