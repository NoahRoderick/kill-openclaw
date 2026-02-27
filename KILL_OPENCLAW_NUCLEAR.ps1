# ============================================
#   OPENCLAW NUCLEAR KILL SWITCH
#   Run as Administrator for full effect.
#   Right-click -> "Run with PowerShell"
# ============================================

$logFile = "$env:USERPROFILE\Desktop\openclaw_kill_log.txt"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
# ================================
#   OPENCLAW NUCLEAR KILL SWITCH
#   Hardened Version
# ================================

$ErrorActionPreference = "SilentlyContinue"

# Resolve Desktop safely (works with OneDrive too)
$desktopPath = [Environment]::GetFolderPath("Desktop")

# Fallback if Desktop path fails
if (-not (Test-Path $desktopPath)) {
    $desktopPath = "$env:USERPROFILE"
}

$logFile = Join-Path $desktopPath "openclaw_kill_log.txt"

# Ensure log file exists
if (-not (Test-Path $logFile)) {
    New-Item -Path $logFile -ItemType File -Force | Out-Null
}

function Write-Log {
    param ($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $message"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

Write-Host ""
Write-Host "============================================"
Write-Host "    OPENCLAW NUCLEAR KILL SWITCH"
Write-Host "============================================"
Write-Host ""

Write-Log "=== OpenClaw Kill Switch Activated ==="

# STEP 1 — Kill node.exe
Write-Log "STEP 1: Killing all node.exe processes..."
$nodeProcesses = Get-Process node -ErrorAction SilentlyContinue

if ($nodeProcesses) {
    $nodeProcesses | Stop-Process -Force
    Write-Log "  node.exe processes terminated."
} else {
    Write-Log "  No node.exe processes found."
}

# STEP 2 — Kill npm
Write-Log "STEP 2: Killing npm processes..."
Get-Process npm -ErrorAction SilentlyContinue | Stop-Process -Force

# STEP 3 — Clear common ports
Write-Log "STEP 3: Clearing ports (3000, 8080, 8888)..."

$ports = 3000,8080,8888

foreach ($port in $ports) {
    $connections = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    foreach ($conn in $connections) {
        Stop-Process -Id $conn.OwningProcess -Force
        Write-Log "  Cleared port $port (PID $($conn.OwningProcess))"
    }
}

# STEP 4 — Add firewall rule safely (no duplicates)
Write-Log "STEP 4: Blocking outbound traffic for node.exe..."

$ruleName = "BLOCK_OPENCLAW_NODE_OUTBOUND"
$existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

if (-not $existingRule) {
    New-NetFirewallRule `
        -DisplayName $ruleName `
        -Direction Outbound `
        -Program "C:\Program Files\nodejs\node.exe" `
        -Action Block `
        -Profile Any | Out-Null

    Write-Log "  Firewall rule added."
} else {
    Write-Log "  Firewall rule already exists."
}

Write-Log "  To remove rule later:"
Write-Log "  Remove-NetFirewallRule -DisplayName '$ruleName'"

# STEP 5 — Startup check
Write-Log "STEP 5: Checking startup entries..."
Get-CimInstance Win32_StartupCommand | Where-Object { $_.Command -match "node|openclaw" } | ForEach-Object {
    Write-Log "  Startup Entry Found: $($_.Name)"
}

Write-Host ""
Write-Host "============================================"
Write-Host "  KILL COMPLETE."
Write-Host "  Log saved to:"
Write-Host "  $logFile"
Write-Host "============================================"
Write-Host ""

Read-Host "Press Enter to exit"
function Log($msg) {
    $line = "[$timestamp] $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Red
Write-Host "    OPENCLAW NUCLEAR KILL SWITCH" -ForegroundColor Red
Write-Host "============================================" -ForegroundColor Red
Write-Host ""

Log "=== OpenClaw Kill Switch Activated ==="

# --- STEP 1: Kill all Node.js processes ---
Log "STEP 1: Killing all node.exe processes..."
$nodeProcs = Get-Process -Name "node" -ErrorAction SilentlyContinue
if ($nodeProcs) {
    foreach ($proc in $nodeProcs) {
        Log "  Killing node.exe PID $($proc.Id) | CPU: $($proc.CPU)s | Started: $($proc.StartTime)"
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
    Log "  All node.exe processes terminated."
} else {
    Log "  No node.exe processes found."
}

# --- STEP 2: Kill npm ---
Log "STEP 2: Killing npm processes..."
Get-Process -Name "npm","npm.cmd" -ErrorAction SilentlyContinue | ForEach-Object {
    Log "  Killing npm PID $($_.Id)"
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}

# --- STEP 3: Kill anything on OpenClaw ports ---
Log "STEP 3: Clearing common OpenClaw ports (3000, 8080, 8888)..."
$ports = @(3000, 8080, 8888)
foreach ($port in $ports) {
    $connections = netstat -ano | Select-String ":$port\s"
    foreach ($line in $connections) {
        $parts = $line -split '\s+' | Where-Object { $_ -ne "" }
        $pid = $parts[-1]
        if ($pid -match '^\d+$' -and $pid -ne "0") {
            $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
            if ($proc) {
                Log "  Killing PID $pid ($($proc.Name)) on port $port"
                Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# --- STEP 4: Block OpenClaw network access via Windows Firewall ---
Log "STEP 4: Adding firewall rules to block node.exe outbound traffic..."
$nodePath = (Get-Command node -ErrorAction SilentlyContinue).Source
if ($nodePath) {
    $ruleName = "BLOCK_OPENCLAW_NODE_OUTBOUND"
    # Remove existing rule if present, then re-add
    netsh advfirewall firewall delete rule name="$ruleName" 2>$null | Out-Null
    netsh advfirewall firewall add rule name="$ruleName" dir=out action=block program="$nodePath" enable=yes | Out-Null
    Log "  Firewall rule added: Blocking outbound traffic for $nodePath"
    Log "  !! To re-enable node.js internet access later, run:"
    Log "     netsh advfirewall firewall delete rule name='$ruleName'"
} else {
    Log "  Could not locate node.exe path. Skipping firewall rule."
}

# --- STEP 5: Disable OpenClaw from auto-starting (common locations) ---
Log "STEP 5: Checking for OpenClaw startup entries..."
$regPaths = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
)
foreach ($regPath in $regPaths) {
    $entries = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
    if ($entries) {
        $entries.PSObject.Properties | Where-Object { $_.Value -match "openclaw|openclaw" } | ForEach-Object {
            Log "  Removing startup entry: $($_.Name) = $($_.Value)"
            Remove-ItemProperty -Path $regPath -Name $_.Name -ErrorAction SilentlyContinue
        }
    }
}

# --- DONE ---
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  KILL COMPLETE. Log saved to:" -ForegroundColor Green
Write-Host "  $logFile" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Cyan
Write-Host "  1. Open Task Manager and confirm no 'node' processes remain." -ForegroundColor White
Write-Host "  2. If you want to use Node.js again normally, remove the firewall" -ForegroundColor White
Write-Host "     rule added in Step 4 (command is in the log file)." -ForegroundColor White
Write-Host "  3. Review the log on your Desktop for a full audit trail." -ForegroundColor White
Write-Host ""

Read-Host "Press Enter to exit"
