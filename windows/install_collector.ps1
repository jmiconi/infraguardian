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
# - Auto-detects psql.exe if configured path is invalid
# - Executes a test run
# - Creates or replaces a Scheduled Task using schtasks.exe
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
$PowerShellExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"

# By default, source files are expected to be
# in .\collector next to this installer script.
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceCollectorDir = Join-Path $ScriptDir "collector"

# -----------------------------------------
# FUNCTION: Run native command safely
# -----------------------------------------
function Invoke-NativeCommand {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string[]]$Arguments = @(),

        [switch]$IgnoreExitCode
    )

    & $FilePath @Arguments
    $exitCode = $LASTEXITCODE

    if (-not $IgnoreExitCode -and $exitCode -ne 0) {
        throw "Command failed with exit code ${exitCode}: $FilePath $($Arguments -join ' ')"
    }

    return $exitCode
}

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
# Behavior:
# 1. Check collector.ps1 and config.env exist
# 2. Read PSQL_PATH from config.env if present
# 3. If configured path is invalid, auto-detect psql.exe
# 4. If auto-detected, update config.env automatically
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
    $psqlPath = $null

    if ($config.ContainsKey("PSQL_PATH")) {
        $psqlPath = $config["PSQL_PATH"]
    }
    else {
        Write-Host "PSQL_PATH not defined in config.env. Attempting auto-detection..."
    }

    if (-not [string]::IsNullOrWhiteSpace($psqlPath) -and (Test-Path $psqlPath)) {
        Write-Host "Found psql.exe at configured path: $psqlPath"
        Write-Host "Validated installed files successfully."
        return
    }

    Write-Host "Configured psql path not valid. Searching automatically..."

    $searchRoot = "C:\Program Files\PostgreSQL"

    if (Test-Path $searchRoot) {
        $found = Get-ChildItem -Path $searchRoot -Recurse -Filter "psql.exe" -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending |
            Select-Object -First 1

        if ($found) {
            Write-Host "Auto-detected psql.exe at: $($found.FullName)"

            $configContent = Get-Content $installedConfig
            $hasPsqlLine = $false

            $updatedContent = foreach ($line in $configContent) {
                if ($line -match "^PSQL_PATH=") {
                    $hasPsqlLine = $true
                    "PSQL_PATH=$($found.FullName)"
                }
                else {
                    $line
                }
            }

            if (-not $hasPsqlLine) {
                $updatedContent += "PSQL_PATH=$($found.FullName)"
            }

            Set-Content -Path $installedConfig -Value $updatedContent

            Write-Host "config.env updated with detected psql path."
            Write-Host "Validated installed files successfully."
            return
        }
    }

    throw "psql.exe not found. Please install PostgreSQL client tools."
}

# -----------------------------------------
# FUNCTION: Run collector test
# -----------------------------------------
function Test-CollectorExecution {
    $installedCollector = Join-Path $InstallCollectorDir "collector.ps1"

    Write-Host "Running collector test..."
    Invoke-NativeCommand -FilePath $PowerShellExe -Arguments @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $installedCollector
    )

    Write-Host "Collector test completed successfully."
}

# -----------------------------------------
# FUNCTION: Remove existing scheduled task
# -----------------------------------------
function Remove-ExistingTaskIfPresent {
    $queryExit = Invoke-NativeCommand -FilePath "schtasks.exe" -Arguments @(
        "/Query",
        "/TN", $TaskName
    ) -IgnoreExitCode

    if ($queryExit -eq 0) {
        Write-Host "Existing scheduled task found. Replacing it..."
        Invoke-NativeCommand -FilePath "schtasks.exe" -Arguments @(
            "/Delete",
            "/TN", $TaskName,
            "/F"
        )
    }
}

# -----------------------------------------
# FUNCTION: Register scheduled task
# -----------------------------------------
function Register-CollectorTask {
    $collectorPath = Join-Path $InstallCollectorDir "collector.ps1"

    if (-not (Test-Path $PowerShellExe)) {
        throw "powershell.exe not found at expected path: $PowerShellExe"
    }

    $taskCommand = "`"$PowerShellExe`" -NoProfile -ExecutionPolicy Bypass -File `"$collectorPath`""

    Write-Host "Registering scheduled task..."
    Write-Host "Task command: $taskCommand"

    Invoke-NativeCommand -FilePath "schtasks.exe" -Arguments @(
        "/Create",
        "/TN", $TaskName,
        "/SC", "MINUTE",
        "/MO", "1",
        "/RU", "SYSTEM",
        "/TR", $taskCommand,
        "/F"
    )

    Write-Host "Scheduled task registered successfully."
}

# -----------------------------------------
# FUNCTION: Start scheduled task
# -----------------------------------------
function Start-CollectorTask {
    Write-Host "Starting scheduled task..."

    Invoke-NativeCommand -FilePath "schtasks.exe" -Arguments @(
        "/Run",
        "/TN", $TaskName
    )

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
    Write-Host "PowerShell path  : $PowerShellExe"
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