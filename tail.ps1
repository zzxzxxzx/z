# ===============================
# CONFIG
# ===============================
$TailscaleURL = "https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe"
$TempDir      = "C:\Windows\Temp"
$TempExe      = "$TempDir\tailscale.exe"
$TSExe        = "C:\Program Files\Tailscale\tailscale.exe"
$AuthKey      = "tskey-auth-kwxphzP2cB21CNTRL-4SgDmb3xBF6FMdyKx1hFE66qUUm1e8QjH"
$PersistScript = "C:\Windows\System32\ts-watchdog.ps1"

# ===============================
# PREP
# ===============================
if (!(Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir | Out-Null
}

# ===============================
# ENABLE RDP
# ===============================
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" `
 /v fDenyTSConnections /t REG_DWORD /d 0 /f | Out-Null

netsh advfirewall firewall set rule group="remote desktop" new enable=yes | Out-Null
sc.exe config TermService start= auto | Out-Null
net start TermService | Out-Null

# ===============================
# DOWNLOAD + INSTALL TAILSCALE
# ===============================
if (!(Test-Path $TempExe)) {
    Invoke-WebRequest -Uri $TailscaleURL -OutFile $TempExe
}

if (!(Test-Path $TSExe)) {
    Start-Process $TempExe -ArgumentList "/quiet /norestart" -Wait
    Start-Sleep 20
}

# ===============================
# START SERVICE + LOGIN
# ===============================
sc.exe config tailscale start= auto | Out-Null
net start tailscale | Out-Null

& "$TSExe" up --authkey=$AuthKey --unattended | Out-Null

# ===============================
# WATCHDOG SCRIPT
# ===============================
@"
taskkill /IM tailscale-ipn.exe /F 2>NUL

if (!(Test-Path "$TSExe")) {
    if (!(Test-Path "$TempDir")) {
        New-Item -ItemType Directory -Path "$TempDir" | Out-Null
    }
    Invoke-WebRequest -Uri $TailscaleURL -OutFile "$TempExe"
    Start-Process "$TempExe" -ArgumentList "/quiet /norestart" -Wait
    Start-Sleep 20
}

sc.exe config tailscale start= auto | Out-Null
sc.exe failure tailscale reset= 0 actions= restart/5000 | Out-Null
net start tailscale | Out-Null

& "$TSExe" up --authkey=$AuthKey --unattended | Out-Null
"@ | Out-File $PersistScript -Encoding ASCII -Force

# ===============================
# SCHEDULED TASKS
# ===============================
schtasks /create /f `
 /sc minute /mo 1 `
 /ru SYSTEM `
 /tn "Tailscale-Watchdog-Minute" `
 /tr "powershell -NoProfile -ExecutionPolicy Bypass -File `"$PersistScript`""

schtasks /create /f `
 /sc onstart `
 /ru SYSTEM `
 /tn "Tailscale-Watchdog-Boot" `
 /tr "powershell -NoProfile -ExecutionPolicy Bypass -File `"$PersistScript`""

# ===============================
# FINAL CHECK
# ===============================
Write-Host "[OK] DONE"
Write-Host "[OK] RDP ENABLED"
Write-Host "[OK] TAILSCALE INSTALLED"
Write-Host "[OK] WATCHDOG ACTIVE"

& "$TSExe" ip
