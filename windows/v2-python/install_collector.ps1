# ------------------------------------------------------------
# InfraGuardian - Windows Collector Installer
# ------------------------------------------------------------

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# CONFIG
# ------------------------------------------------------------

$TaskName = "InfraGuardian Collector"

$InstallRoot = "C:\InfraGuardian"
$InstallDir = "$InstallRoot\collector"
$LogDir = "$InstallRoot\logs"

$SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$CollectorSource = "$SourceDir\collector.py"
$RequirementsSource = "$SourceDir\requirements.txt"

# Config files
$ConfigSource = "$SourceDir\config.env"
$ConfigExampleSource = "$SourceDir\config.env.example"

# Optional local Python installer
$LocalPythonInstaller = "$SourceDir\python-installer.exe"

# Fallback online Python installer
$PythonVersion = "3.11.9"
$PythonUrl = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-amd64.exe"
$DownloadedPythonInstaller = "$env:TEMP\python-$PythonVersion-amd64.exe"

$CollectorTarget = "$InstallDir\collector.py"
$RequirementsTarget = "$InstallDir\requirements.txt"
$ConfigTarget = "$InstallDir\config.env"

$VenvDir = "$InstallDir\.venv"
$VenvPython = "$VenvDir\Scripts\python.exe"

# ------------------------------------------------------------
# HELPERS
# ------------------------------------------------------------

function Write-Section {
    param([string]$Message)

    Write-Host ""
    Write-Host "------------------------------------------------"
    Write-Host $Message
    Write-Host "------------------------------------------------"
}

function Get-ValidPythonCommand {
    $candidates = @()

    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) { $candidates += $python.Source }

    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($py) { $candidates += $py.Source }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        try {
            $leaf = (Split-Path $candidate -Leaf).ToLower()

            if ($leaf -eq "py.exe") {
                & $candidate -3 -c "import sys; print(sys.executable)" *> $null
            }
            else {
                & $candidate -c "import sys; print(sys.executable)" *> $null
            }

            if ($LASTEXITCODE -eq 0) {
                return $candidate
            }
        }
        catch {
        }
    }

    return $null
}

# ------------------------------------------------------------
# INSTALL PYTHON IF NEEDED
# ------------------------------------------------------------

function Install-Python {
    Write-Section "Checking Python"

    $PythonCmd = Get-ValidPythonCommand

    if ($PythonCmd) {
        Write-Host "[OK] Valid Python found: $PythonCmd"
        return
    }

    Write-Host "[WARN] No valid Python installation found"

    $Installer = $null

    if (Test-Path $LocalPythonInstaller) {
        Write-Host "[INFO] Using local Python installer"
        $Installer = $LocalPythonInstaller
    }
    else {
        Write-Host "[INFO] Downloading Python installer"
        Invoke-WebRequest -Uri $PythonUrl -OutFile $DownloadedPythonInstaller
        $Installer = $DownloadedPythonInstaller
    }

    Write-Host "[INFO] Installing Python silently"

    Start-Process `
        -FilePath $Installer `
        -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0" `
        -Wait

    Start-Sleep -Seconds 5

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")

    $PythonCmd = Get-ValidPythonCommand

    if (-not $PythonCmd) {
        throw "Python installation failed or Python is still not available in PATH"
    }

    Write-Host "[OK] Python installed: $PythonCmd"
}

# ------------------------------------------------------------
# CREATE DIRECTORIES
# ------------------------------------------------------------

function Create-Directories {
    Write-Section "Creating directories"

    if (-not (Test-Path $InstallRoot)) {
        New-Item -ItemType Directory -Path $InstallRoot | Out-Null
    }

    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir | Out-Null
    }

    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir | Out-Null
    }

    Write-Host "[OK] Directories ready"
}

# ------------------------------------------------------------
# VALIDATE SOURCE FILES
# ------------------------------------------------------------

function Validate-Sources {
    Write-Section "Validating source files"

    if (-not (Test-Path $CollectorSource)) {
        throw "collector.py not found in $SourceDir"
    }

    if (-not (Test-Path $RequirementsSource)) {
        throw "requirements.txt not found in $SourceDir"
    }

    if (-not (Test-Path $ConfigSource) -and -not (Test-Path $ConfigExampleSource)) {
        throw "Neither config.env nor config.env.example were found in $SourceDir"
    }

    Write-Host "[OK] Source files valid"
}

# ------------------------------------------------------------
# COPY FILES
# ------------------------------------------------------------

function Copy-Files {
    Write-Section "Copying collector files"

    Copy-Item $CollectorSource $CollectorTarget -Force
    Copy-Item $RequirementsSource $RequirementsTarget -Force

    if (-not (Test-Path $ConfigTarget)) {

        if (Test-Path $ConfigSource) {
            Copy-Item $ConfigSource $ConfigTarget -Force
            Write-Host "[OK] config.env copied from source config.env"
        }
        elseif (Test-Path $ConfigExampleSource) {
            Copy-Item $ConfigExampleSource $ConfigTarget -Force
            Write-Host "[OK] config.env created from config.env.example"
            Write-Host "[WARN] Source config.env not found. Example configuration was used."
        }
        else {
            throw "Neither config.env nor config.env.example were found in $SourceDir"
        }

    }
    else {
        Write-Host "[OK] Existing config.env preserved"
    }
}

# ------------------------------------------------------------
# CREATE VENV
# ------------------------------------------------------------

function Create-Venv {
    Write-Section "Creating Python virtualenv"

    if (Test-Path $VenvPython) {
        Write-Host "[OK] Existing venv detected"
        return
    }

    $PythonCmd = Get-ValidPythonCommand

    if (-not $PythonCmd) {
        throw "No valid Python command found after installation"
    }

    $leaf = (Split-Path $PythonCmd -Leaf).ToLower()

    if ($leaf -eq "py.exe") {
        & $PythonCmd -3 -m venv $VenvDir
    }
    else {
        & $PythonCmd -m venv $VenvDir
    }

    if (-not (Test-Path $VenvPython)) {
        throw "Failed to create virtualenv"
    }

    Write-Host "[OK] Virtualenv created"
}

# ------------------------------------------------------------
# INSTALL DEPENDENCIES
# ------------------------------------------------------------

function Install-Dependencies {
    Write-Section "Installing Python dependencies"

    & $VenvPython -m pip install --upgrade pip
    & $VenvPython -m pip install -r $RequirementsTarget

    Write-Host "[OK] Dependencies installed"
}

# ------------------------------------------------------------
# STOP / REMOVE EXISTING TASK
# ------------------------------------------------------------

function Remove-ExistingTask {
    Write-Section "Cleaning existing task"

    $Existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    if ($Existing) {
        try {
            Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
        catch {
        }

        Unregister-ScheduledTask `
            -TaskName $TaskName `
            -Confirm:$false

        Write-Host "[OK] Previous Scheduled Task removed"
    }
    else {
        Write-Host "[OK] No previous task found"
    }
}

# ------------------------------------------------------------
# CREATE SCHEDULED TASK
# ------------------------------------------------------------

function Create-ScheduledTask {
    Write-Section "Creating Scheduled Task"

    $Action = New-ScheduledTaskAction `
        -Execute $VenvPython `
        -Argument "`"$CollectorTarget`"" `
        -WorkingDirectory $InstallDir

    $Trigger = New-ScheduledTaskTrigger -AtStartup

    $Settings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -MultipleInstances IgnoreNew

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $Action `
        -Trigger $Trigger `
        -Settings $Settings `
        -User "SYSTEM" `
        -RunLevel Highest `
        -Force | Out-Null

    Write-Host "[OK] Scheduled Task created"
}

# ------------------------------------------------------------
# START COLLECTOR IMMEDIATELY
# ------------------------------------------------------------

function Start-CollectorNow {
    Write-Section "Starting collector immediately"

    Start-ScheduledTask -TaskName $TaskName
    Start-Sleep -Seconds 5

    $TaskInfo = Get-ScheduledTaskInfo -TaskName $TaskName

    Write-Host "[INFO] LastRunTime:    $($TaskInfo.LastRunTime)"
    Write-Host "[INFO] LastTaskResult: $($TaskInfo.LastTaskResult)"

    if (Test-Path "$LogDir\collector.log") {
        Write-Host "[OK] Log file detected: $LogDir\collector.log"
    }
    else {
        Write-Host "[WARN] Log file not detected yet"
    }
}

# ------------------------------------------------------------
# SUMMARY
# ------------------------------------------------------------

function Show-Summary {
    Write-Section "Installation complete"

    Write-Host "Collector installed in:"
    Write-Host "  $InstallDir"
    Write-Host ""

    Write-Host "Logs:"
    Write-Host "  $LogDir"
    Write-Host ""

    Write-Host "Task Scheduler:"
    Write-Host "  $TaskName"
    Write-Host ""

    Write-Host "Config file in use:"
    Write-Host "  $ConfigTarget"
    Write-Host ""

    Write-Host "Useful checks:"
    Write-Host "  Get-ScheduledTaskInfo -TaskName `"$TaskName`""
    Write-Host "  Get-Content `"$LogDir\collector.log`" -Tail 50"
}

# ------------------------------------------------------------
# MAIN
# ------------------------------------------------------------

Write-Section "InfraGuardian Collector Installer"

Validate-Sources
Install-Python
Create-Directories
Copy-Files
Create-Venv
Install-Dependencies
Remove-ExistingTask
Create-ScheduledTask
Start-CollectorNow
Show-Summary