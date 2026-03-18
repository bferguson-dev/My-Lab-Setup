$ErrorActionPreference = 'Stop'
$logDir = 'C:\LabSetup'
New-Item -Path $logDir -ItemType Directory -Force | Out-Null
$logFile = Join-Path $logDir 'bootstrap-windows.log'

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format s), $Message
    $line | Out-File -FilePath $logFile -Append -Encoding utf8
}

Write-Log 'Starting Windows bootstrap'

Write-Log 'Disabling automatic updates'
New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Force | Out-Null
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name NoAutoUpdate -Type DWord -Value 1
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name AUOptions -Type DWord -Value 1
foreach ($svc in 'wuauserv','bits','dosvc','UsoSvc') {
    try { Stop-Service $svc -Force -ErrorAction SilentlyContinue } catch {}
    try { Set-Service $svc -StartupType Disabled -ErrorAction SilentlyContinue } catch {}
}

Write-Log 'Configuring WinRM for lab use'
winrm quickconfig -q | Out-Null
winrm set winrm/config/service '@{AllowUnencrypted="false"}' | Out-Null
winrm set winrm/config/service/auth '@{Basic="false"}' | Out-Null
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM

Write-Log 'Adjusting firewall for WinRM'
netsh advfirewall firewall set rule group="windows remote management" new enable=yes profile=any | Out-Null

Write-Log 'Capturing verification state'
Get-Service WinRM,wuauserv,bits,UsoSvc | Select-Object Name,Status,StartType |
    Out-File -FilePath (Join-Path $logDir 'service-state.txt') -Encoding utf8
reg query 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' /v NoAutoUpdate |
    Out-File -FilePath (Join-Path $logDir 'wu-policy.txt') -Encoding utf8
winrm enumerate winrm/config/listener |
    Out-File -FilePath (Join-Path $logDir 'winrm-listener.txt') -Encoding utf8

Write-Log 'Windows bootstrap complete'
