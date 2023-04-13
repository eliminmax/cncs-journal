Connect-480VIServer -Server vcenter.eli.local | Out-Null

Get-VM | Where-Object { $_.Name.StartsWith('ubuntu') -and $_.Name.Length -eq 7 } | ForEach-Object {if ( $_.PowerState -eq 'PoweredOn' ) { Stop-VM -Kill -VM $_ -Confirm:$false | Out-Null }; Remove-Vm -VM $_ -DeleteFromDisk -Confirm:$false -Verbose}
