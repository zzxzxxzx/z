# Kill Tailscale as SYSTEM via Scheduled Task
# Jalankan PowerShell sebagai Administrator

$taskName = "KillTailscale"

# Action: stop service + kill process
$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c sc stop Tailscale & taskkill /IM tailscale-ipn.exe /F"

# Kalau task sudah ada, hapus dulu
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Register task sebagai SYSTEM
Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -User "SYSTEM" `
    -RunLevel Highest `
    -Force | Out-Null

# Jalankan task
Start-ScheduledTask -TaskName $taskName

# Info hasil
Start-Sleep 1
Get-ScheduledTaskInfo -TaskName $taskName
