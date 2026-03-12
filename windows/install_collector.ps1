# =========================================
# InfraGuardian - Windows Installer v1
# =========================================
# Purpose:
# Install the InfraGuardian Windows collector
# into a standard path and register a scheduled task.
#
# What it does:
# - Creates C:\InfraGuardian\collector
# - Copies collector files
# - Validates psql path from config.env
# - Executes a test run
# - Creates or replaces a Scheduled Task
# - Starts the task
# =========================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -----------------------------------------
# CONFIG
# -----------------------------------------
$InstallRoot = "C:\InfraGuardian"
$InstallCollectorDir = Join-Path $InstallRoot "collector"
$TaskName = "InfraGuardian Collector"

# By default, source files are expected to be
# in .\collector next to this installer script.
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceCollectorDir = Join-Path $ScriptDir "collector"

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

    $result = @{}

    foreach ($lineRaw in Get-Content $Path) {
        $line = $lineRaw.Trim()

        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.StartsWith("#")) { continue }

        $parts = $line -split "=", 2
        if ($parts.Count -ne 2) { continue }

        $key = $parts[0].Trim()
        $value = $parts[1].Trim()

        $result[$key] = $value
    }

    return $result
}

# -----------------------------------------
# FUNCTION: Ensure admin rights
# -----------------------------------------
function Test-IsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# -----------------------------------------
# FUNCTION: Create installation folders
# -----------------------------------------
function New-InstallFolders {
    Write-Host "Creating installation folders..."
    New-Item -ItemType Directory -Path $InstallCollectorDir -Force | Out-Null
}

# -----------------------------------------
# FUNCTION: Copy collector files
# -----------------------------------------
function Copy-CollectorFiles {
    if (-not (Test-Path $SourceCollectorDir)) {
        throw "Source collector directory not found: $SourceCollectorDir"
    }

    $sourceCollectorPs1 = Join-Path $SourceCollectorDir "collector.ps1"
    $sourceConfigEnv = Join-Path $SourceCollectorDir "config.env"

    if (-not (Test-Path $sourceCollectorPs1)) {
        throw "collector.ps1 not found in source path: $sourceCollectorPs1"
    }

    if (-not (Test-Path $sourceConfigEnv)) {
        throw "config.env not found in source path: $sourceConfigEnv"
    }

    Write-Host "Copying collector files..."
    Copy-Item -Path $sourceCollectorPs1 -Destination (Join-Path $InstallCollectorDir "collector.ps1") -Force
    Copy-Item -Path $sourceConfigEnv -Destination (Join-Path $InstallCollectorDir "config.env") -Force
}

# -----------------------------------------
# FUNCTION: Validate installed files
# -----------------------------------------
function Test-InstalledFiles {
    $installedCollector = Join-Path $InstallCollectorDir "collector.ps1"
    $installedConfig = Join-Path $InstallCollectorDir "config.env"

    if (-not (Test-Path $installedCollector)) {
        throw "Installed collector.ps1 not found: $installedCollector"
    }

    if (-not (Test-Path $installedConfig)) {
        throw "Installed config.env not found: $installedConfig"
    }

    $config = Import-EnvFile -Path $installedConfig

    if (-not $config.ContainsKey("PSQL_PATH")) {
        throw "PSQL_PATH not found in config.env"
    }

    $psqlPath = $config["PSQL_PATH"]

    if (-not (Test-Path $psqlPath)) {
        throw "psql.exe not found at configured path: $psqlPath"
    }

    Write-Host "Validated installed files successfully."
}

# -----------------------------------------
# FUNCTION: Run collector test
# -----------------------------------------
function Test-CollectorExecution {
    $installedCollector = Join-Path $InstallCollectorDir "collector.ps1"

    Write-Host "Running collector test..."
    & powershell.exe -ExecutionPolicy Bypass -File $installedCollector

    if ($LASTEXITCODE -ne 0) {
        throw "Collector test failed with exit code $LASTEXITCODE"
    }

    Write-Host "Collector test completed successfully."
}

# -----------------------------------------
# FUNCTION: Remove existing scheduled task
# -----------------------------------------
function Remove-ExistingTaskIfPresent {
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    if ($null -ne $existingTask) {
        Write-Host "Existing scheduled task found. Replacing it..."
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
}

# -----------------------------------------
# FUNCTION: Register scheduled task
# -----------------------------------------
function Register-CollectorTask {
    $collectorPath = Join-Path $InstallCollectorDir "collector.ps1"

    Write-Host "Registering scheduled task..."

    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$collectorPath`""

    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
    $trigger.RepetitionInterval = (New-TimeSpan -Minutes 1)
    $trigger.RepetitionDuration = [TimeSpan]::MaxValue

    $principal = New-ScheduledTaskPrincipal `
        -UserId "SYSTEM" `
        -LogonType ServiceAccount `
        -RunLevel Highest

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -MultipleInstances IgnoreNew

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description "InfraGuardian Windows metrics collector"

    Write-Host "Scheduled task registered successfully."
}

# -----------------------------------------
# FUNCTION: Start scheduled task
# -----------------------------------------
function Start-CollectorTask {
    Write-Host "Starting scheduled task..."
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Scheduled task started."
}

# -----------------------------------------
# MAIN
# -----------------------------------------
try {
    Write-Host "========================================="
    Write-Host "InfraGuardian Windows Installer"
    Write-Host "========================================="
    Write-Host "Source path      : $SourceCollectorDir"
    Write-Host "Install path     : $InstallCollectorDir"
    Write-Host "Task name        : $TaskName"
    Write-Host ""

    if (-not (Test-IsAdministrator)) {
        throw "This installer must be run as Administrator."
    }

    New-InstallFolders
    Copy-CollectorFiles
    Test-InstalledFiles
    Test-CollectorExecution
    Remove-ExistingTaskIfPresent
    Register-CollectorTask
    Start-CollectorTask

    Write-Host ""
    Write-Host "InfraGuardian Windows collector installed successfully."
    Write-Host "Collector path : $InstallCollectorDir"
    Write-Host "Scheduled task : $TaskName"
    exit 0
}
catch {
    Write-Error "Installation failed: $($_.Exception.Message)"
    exit 1
}