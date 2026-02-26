# ============================================
#   OPENCLAW NUCLEAR KILL SWITCH
#   Run as Administrator for full effect.
#   Right-click -> "Run with PowerShell"
# ============================================

$logFile = "$env:USERPROFILE\Desktop\openclaw_kill_log.txt"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

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
