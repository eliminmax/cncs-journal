param ([Parameter(Mandatory=$true)][string] $ConfigPath)
$ErrorActionPreference = 'Stop'
Import-Module '480-utils' -Force

# Load config from path specified by $ConfigPath parameter
$Config = Get-480Config -ConfigPath $ConfigPath
$Connection = Connect-480VIServer -Server $Config.VIServer

$TargetVMDestination = (Get-Folder -Name $Config.TargetVMDestinationName)

$TargetVMs = [System.Collections.ArrayList]@()

foreach ($TargetVMName in ($Config.TargetVMNames)) {
    $TargetVM = New-VMCloneFromSnapshot -SourceVMName $Config.SourceVMName -SourceSnapshotName $Config.SourceSnapshotName -TargetVMName $TargetVMName
    Move-VM -VM $TargetVM -InventoryLocation $TargetVMDestination | Out-Null
    $TargetVMs.Add((Start-VM -VM $TargetVM)) | Out-Null
}

foreach ($TargetVMName in ($Config.TargetVMNames)) {
    Set-Network -VMName $TargetVMName -TargetNetworkName $Config.TargetNetworkName -VMNicIndex 0 | Out-Null
}
$TargetVMs
