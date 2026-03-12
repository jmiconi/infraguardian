# =========================================
# InfraGuardian - Windows Collector v1
# =========================================
# Purpose:
# Collect basic system metrics from a Windows host
# and insert them into the central PostgreSQL database
# using psql.
#
# Design goals:
# - Simple and maintainable
# - Similar philosophy to the Linux collector
# - No Python dependency on Windows
# - Uses config.env for configuration
# - Clear troubleshooting output
# =========================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -----------------------------------------
# FUNCTION: Read simple KEY=VALUE env file
# -----------------------------------------
function Import-EnvFile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Config file not found: $Path"
    }

    foreach ($lineRaw in Get-Content $Path) {
        $line = $lineRaw.Trim()

        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.StartsWith("#")) { continue }

        $parts = $line -split "=", 2
        if ($parts.Count -ne 2) { continue }

        $key = $parts[0].Trim()
        $value = $parts[1].Trim()

        [System.Environment]::SetEnvironmentVariable($key, $value, "Process")
    }
}

# -----------------------------------------
# FUNCTION: Escape SQL string values
# -----------------------------------------
function Escape-SqlString {
    param (
        [AllowNull()]
        [string]$Value
    )

    if ($null -eq $Value) {
        return ""
    }

    return $Value.Replace("'", "''")
}

# -----------------------------------------
# FUNCTION: Format decimal using dot
# -----------------------------------------
function To-InvariantDecimal {
    param (
        [double]$Value
    )

    return $Value.ToString("0.00", [System.Globalization.CultureInfo]::InvariantCulture)
}

# -----------------------------------------
# FUNCTION: Get CPU usage percentage
# -----------------------------------------
# We avoid Get-Counter because it can fail on
# localized Windows installations.
# -----------------------------------------
function Get-CpuPercent {
    $cpu = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average

    if ($null -eq $cpu -or $null -eq $cpu.Average) {
        throw "Could not calculate CPU percentage."
    }

    return [math]::Round([double]$cpu.Average, 2)
}

# -----------------------------------------
# FUNCTION: Get RAM usage percentage
# -----------------------------------------
function Get-RamPercent {
    $os = Get-CimInstance Win32_OperatingSystem

    $totalKb = [double]$os.TotalVisibleMemorySize
    $freeKb  = [double]$os.FreePhysicalMemory
    $usedKb  = $totalKb - $freeKb

    if ($totalKb -le 0) {
        throw "Total visible memory is zero or invalid."
    }

    return [math]::Round(($usedKb / $totalKb) * 100, 2)
}

# -----------------------------------------
# FUNCTION: Get disk usage percentage
# -----------------------------------------
# v1 decision:
# Use the highest usage percentage among
# local fixed disks (DriveType = 3).
# -----------------------------------------
function Get-DiskPercent {
    $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"

    if (-not $disks) {
        throw "No fixed disks found."
    }

    $percentages = @()

    foreach ($disk in $disks) {
        if ([double]$disk.Size -gt 0) {
            $usedPercent = (([double]$disk.Size - [double]$disk.FreeSpace) / [double]$disk.Size) * 100
            $percentages += [math]::Round($usedPercent, 2)
        }
    }

    if ($percentages.Count -eq 0) {
        throw "Could not calculate disk percentage."
    }

    return [double](($percentages | Measure-Object -Maximum).Maximum)
}

# -----------------------------------------
# FUNCTION: Get total process count
# -----------------------------------------
function Get-ProcessCount {
    return (Get-Process | Measure-Object).Count
}

# -----------------------------------------
# FUNCTION: Get network bytes sent/received
# -----------------------------------------
# We sum stats from active adapters.
# If none can be read, we return 0/0 instead
# of breaking the whole collector.
# -----------------------------------------
function Get-NetworkBytes {
    $totalSent = 0
    $totalRecv = 0
    $successfulAdapters = 0

    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }

    if (-not $adapters) {
        return @{
            SentBytes = 0
            RecvBytes = 0
        }
    }

    foreach ($adapter in $adapters) {
        try {
            $stats = Get-NetAdapterStatistics -Name $adapter.Name -ErrorAction Stop
            $totalSent += [int64]$stats.SentBytes
            $totalRecv += [int64]$stats.ReceivedBytes
            $successfulAdapters++
        }
        catch {
            Write-Warning "Could not read network stats for adapter: $($adapter.Name)"
        }
    }

    if ($successfulAdapters -eq 0) {
        return @{
            SentBytes = 0
            RecvBytes = 0
        }
    }

    return @{
        SentBytes = $totalSent
        RecvBytes = $totalRecv
    }
}

# -----------------------------------------
# FUNCTION: Validate required configuration
# -----------------------------------------
function Test-RequiredConfig {
    $requiredVars = @(
        "POSTGRES_HOST",
        "POSTGRES_PORT",
        "POSTGRES_DB",
        "POSTGRES_USER",
        "POSTGRES_PASSWORD",
        "PSQL_PATH"
    )

    foreach ($varName in $requiredVars) {
        $value = [System.Environment]::GetEnvironmentVariable($varName, "Process")

        if ([string]::IsNullOrWhiteSpace($value)) {
            throw "Required config value missing: $varName"
        }
    }
}

# -----------------------------------------
# FUNCTION: Build INSERT statement
# -----------------------------------------
function Build-InsertSql {
    param (
        [string]$Hostname,
        [string]$Role,
        [string]$Environment,
        [double]$CpuPercent,
        [double]$RamPercent,
        [double]$DiskPercent,
        [int]$ProcessCount,
        [int64]$NetworkBytesSent,
        [int64]$NetworkBytesRecv
    )

    $hostnameEsc    = Escape-SqlString $Hostname
    $roleEsc        = Escape-SqlString $Role
    $environmentEsc = Escape-SqlString $Environment

    $cpu  = To-InvariantDecimal $CpuPercent
    $ram  = To-InvariantDecimal $RamPercent
    $disk = To-InvariantDecimal $DiskPercent

    return @"
INSERT INTO system_metrics (
    hostname,
    role,
    environment,
    cpu_percent,
    ram_percent,
    disk_percent,
    process_count,
    load_1,
    load_5,
    load_15,
    network_bytes_sent,
    network_bytes_recv
)
VALUES (
    '$hostnameEsc',
    '$roleEsc',
    '$environmentEsc',
    $cpu,
    $ram,
    $disk,
    $ProcessCount,
    NULL,
    NULL,
    NULL,
    $NetworkBytesSent,
    $NetworkBytesRecv
);
"@
}

# -----------------------------------------
# FUNCTION: Execute SQL using psql
# -----------------------------------------
function Invoke-Psql {
    param (
        [string]$PsqlPath,
        [string]$DbHost,
        [string]$DbPort,
        [string]$DbName,
        [string]$DbUser,
        [string]$DbPassword,
        [string]$Sql
    )

    if (-not (Test-Path $PsqlPath)) {
        throw "psql.exe not found at: $PsqlPath"
    }

    $env:PGPASSWORD = $DbPassword

    try {
        & $PsqlPath `
            -h $DbHost `
            -p $DbPort `
            -U $DbUser `
            -d $DbName `
            -v ON_ERROR_STOP=1 `
            -c $Sql

        if ($LASTEXITCODE -ne 0) {
            throw "psql returned exit code $LASTEXITCODE"
        }
    }
    finally {
        Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
    }
}

# -----------------------------------------
# MAIN
# -----------------------------------------
try {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $configPath = Join-Path $scriptDir "config.env"

    Import-EnvFile -Path $configPath
    Test-RequiredConfig

    $dbHost = $env:POSTGRES_HOST
    $dbPort = $env:POSTGRES_PORT
    $dbName = $env:POSTGRES_DB
    $dbUser = $env:POSTGRES_USER
    $dbPass = $env:POSTGRES_PASSWORD

    $role = if ($env:ROLE) { $env:ROLE } else { "windows-host" }
    $environment = if ($env:ENVIRONMENT) { $env:ENVIRONMENT } else { "default" }
    $psqlPath = $env:PSQL_PATH

    $hostname = $env:COMPUTERNAME

    Write-Host "========================================="
    Write-Host "InfraGuardian Windows Collector"
    Write-Host "========================================="
    Write-Host "Hostname    : $hostname"
    Write-Host "Role        : $role"
    Write-Host "Environment : $environment"
    Write-Host ""

    Write-Host "[1/5] Reading CPU usage..."
    $cpuPercent = Get-CpuPercent
    Write-Host "CPU %               : $cpuPercent"

    Write-Host "[2/5] Reading RAM usage..."
    $ramPercent = Get-RamPercent
    Write-Host "RAM %               : $ramPercent"

    Write-Host "[3/5] Reading disk usage..."
    $diskPercent = Get-DiskPercent
    Write-Host "Disk %              : $diskPercent"

    Write-Host "[4/5] Reading process count..."
    $processCount = Get-ProcessCount
    Write-Host "Process count       : $processCount"

    Write-Host "[5/5] Reading network usage..."
    $network = Get-NetworkBytes
    $networkBytesSent = $network.SentBytes
    $networkBytesRecv = $network.RecvBytes
    Write-Host "Network bytes sent  : $networkBytesSent"
    Write-Host "Network bytes recv  : $networkBytesRecv"

    $sql = Build-InsertSql `
        -Hostname $hostname `
        -Role $role `
        -Environment $environment `
        -CpuPercent $cpuPercent `
        -RamPercent $ramPercent `
        -DiskPercent $diskPercent `
        -ProcessCount $processCount `
        -NetworkBytesSent $networkBytesSent `
        -NetworkBytesRecv $networkBytesRecv

    Write-Host ""
    Write-Host "Inserting metrics into PostgreSQL..."

    Invoke-Psql `
        -PsqlPath $psqlPath `
        -DbHost $dbHost `
        -DbPort $dbPort `
        -DbName $dbName `
        -DbUser $dbUser `
        -DbPassword $dbPass `
        -Sql $sql

    Write-Host "Metrics inserted successfully."
    exit 0
}
catch {
    Write-Error "Collector execution failed: $($_.Exception.Message)"
    exit 1
}