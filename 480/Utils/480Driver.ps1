Import-Module '480-utils' -Force

Show-480Banner

$conf = Get-480Config -ConfigPath "/home/eli.minkoff-adm/Git/lab-submission-assets/480/Utils/480.json"

Connect-480VIServer -Server $conf.vcenter_server

$Global:CurrentVM = Select-VM
