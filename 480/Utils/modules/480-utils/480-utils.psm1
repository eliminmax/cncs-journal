function Show-480Banner {
    <#
    .SYNOPSIS
    Show a welcoming banner with one of the course identifiers for the class.
    .DESCRIPTION
    Show one of 3 welcome banners for SYS/NET/SEC480, chosen randomly
    The banners contain one of the 4 course identifiers in block letters (pre-generated with figlet)
    #>
    $courseBannerChoice = Get-Random -Minimum 1 -Maximum 3 
    $courseBanners = @(
@"
   ______  __________ ___  ___      ___           ____         
  / __/\ \/ / __/ / /( _ )/ _ \____/ _ \___ _  __/ __ \___  ___
 _\ \   \  /\ \/_  _/ _  / // /___/ // / -_) |/ / /_/ / _ \(_-<
/___/   /_/___/ /_/ \___/\___/   /____/\__/|___/\____/ .__/___/
    SYS/NET/SEC-480 DevOps S23 Champlain College    /_/        
"@,
@"
   _________________ ___  ___      ___           ____         
  / __/ __/ ___/ / /( _ )/ _ \____/ _ \___ _  __/ __ \___  ___
 _\ \/ _// /__/_  _/ _  / // /___/ // / -_) |/ / /_/ / _ \(_-<
/___/___/\___/ /_/ \___/\___/   /____/\__/|___/\____/ .__/___/
    SYS/NET/SEC-480 DevOps S23 Champlain College   /_/        
"@,
@"
   _  ________________ ___  ___      ___           ____         
  / |/ / __/_  __/ / /( _ )/ _ \____/ _ \___ _  __/ __ \___  ___
 /    / _/  / / /_  _/ _  / // /___/ // / -_) |/ / /_/ / _ \(_-<
/_/|_/___/ /_/   /_/ \___/\___/   /____/\__/|___/\____/ .__/___/
    SYS/NET/SEC-480 DevOps S23 Champlain College     /_/        
"@
        )
    $courseBanner = $courseBanners[$courseBannerChoice]
    Write-Host $courseBanner
}

function Connect-480VIServer {
    <#
    .SYNOPSIS
    A wrapper around Connect-VIServer that only works if a connection is not already established
    .DESCRIPTION
    If already connected to $Server, then it prints out an informational message noting that fact.
    If not already connected, it calls the Connect-VIServer cmdlet, passing along the -Server argument.
    It returns the connection as an object.
    #>
    Param (
        # The server to connect to
        [Parameter(Mandatory=$True)] [String] $Server        
    )
    # check if already connected to the server
    if ($Global:DefaultVIServer.Name -eq $Server) {
        $msg = "Already connected to: {0}" -f $Server
        Write-Host -ForegroundColor Green $msg
        return $Global:DefaultVIServer
    }
    $conn = Connect-VIServer -Server $Server
    return $conn
}

function Get-480Config {
    <#
    .SYNOPSIS
    Load the configuration from the file specified with -ConfigPath
    .DESCRIPTION
    Load and return the configuration from the file specified with -ConfigPath
    Return $null if the file does not exist or is not able to be parsed (e.g. because it's not readable, or not valid JSON)
    #>
    Param (
        # Path to the 480.json file
        [Parameter(Mandatory=$True)] [String] $ConfigPath
    )
    $conf = $null
    if (Test-Path $ConfigPath) {
        Write-Host "Reading " $ConfigPath
        try {
            $json_data = Get-Content -Raw -Path $ConfigPath
        }
        catch {
            $msg = "Could not open file at {0}." -f $ConfigPath
            Write-Host -ForegroundColor "Yellow" $msg
        }
        if (Test-Json -Json $json_data) {
            $conf = ConvertFrom-Json -InputObject $json_data
            $msg = "Using configuration at {0}" -f $ConfigPath
            Write-Host -ForegroundColor "Green" $msg
        } else {
            $msg = "Could not parse content of {0}. Please ensure that it's valid JSON data." -f $ConfigPath
            Write-Host -ForegroundColor "Yellow" $msg
        }
    } else {
        $msg = "Could not find file at {0}" -f $ConfigPath
        Write-Host -ForegroundColor "Yellow" $msg
    }
    return $conf
}

function Select-VM {
    <#
    .SYNOPSIS
    Interactively select a VM from a given folder
    .DESCRIPTION
    Interactively select a VM from a given folder, defaulting to "vm" (the top-level folder for VMs)
    #>
    Param (
        # The folder to search
        [String] $Folder = "vm"
    )
    if (-Not $Global:DefaultVIServer) {
        Write-Error -Message "Not connected to a server" -ErrorAction Stop
    }
    # Let PowerCLI handle throwing the error if it's an invalid folder - don't just catch, only to throw a new error
    $VMs = Get-VM -Location $folder 
    # present list of available VMs
    for ($i = 0; $i -lt $VMs.Length; $i++) {
        Write-Host ("[{0}]:" -f $i) $VMs[$i]
    }
    $selection_index = Read-Host -Prompt "Index number [#] of the desired VM"
    return $VMs[$selection_index]
}

function New-VMCloneFromSnapshot {
    <#
    .SYNOPSIS
    Clone a VM snapshot to create a new VM
    #>
    param (
        # The name of the VM with the Snapshot to clone
        [Parameter(Mandatory=$True)] [String] $SourceVMName,
        # The name of the new VM
        [Parameter(Mandatory=$True)] [String] $TargetVMName,
        # The name of the snapshot to clone
        [String] $SourceSnapshotName="Base"
    )
    $SourceVM = Get-VM -Name $SourceVMName -ErrorAction Stop
    $SourceSnapshot = Get-Snapshot -Name $SourceSnapshotName -VM $SourceVM -ErrorAction Stop
    $VMHost = $SourceVM.VMHost
    $VMDatastore = Get-Datastore -VM $SourceVM -ErrorAction Stop
    $TargetVM = New-VM -Name $TargetVMName -LinkedClone -ReferenceSnapshot $SourceSnapshot -VM $SourceVM -VMHost $VMHost -Datastore $VMDatastore -ErrorAction Stop
    $NewSnapshot = New-Snapshot -VM $TargetVM -Name "Base" -ErrorAction Stop
    return $TargetVM
}

function New-480Network {
    <#
    .SYNOPSIS
    Create a Virtual Switch and Port Group together
    #>
    Param (
        [Parameter(Mandatory=$True)] [String] $Name,
        [String] $VMHost,
        [String] $Server
    )

    # Check if running in a sensible environment
    if ($Server) {
        if ([String] $Global:DefaultVIServer -ne $Server) { # refuse to run if connected to a server other than the one specified
            $errmsg = "Specified Server {0}, but already connected to {1}" -f $Server, $Global:DefaultVIServer
            Write-Error -Message $errmsg -ErrorAction stop
        } else {
            Connect-480VIServer -Server $Server
        }
    } else { 
        # handle an unspecified server - if one is already connected, we're good, otherwise, ask whether or not to connect to a server
        if ( -Not $Global:DefaultVIServer ) {
            Write-Host -ForegroundColor 'Yellow' "No server specified, and not already connected to a server."
            for (
                $answer = Read-Host "Connect to a server now? [Y/N]";
                (-Not (("Y", "N").Contains($answer.toUpper())));
                $answer = Read-Host -Prompt "Answer invalid. [Y/N]"
                ) {
                # Do nothing until the answer is valid
            }
            if ($answer -eq "Y") {
                $srv = Connect-480VIServer
                if ($srv -eq $null) {
                    # Failed to connect to the server, so refuse to continue.
                    Write-Error -Message "Could not connect to server." -ErrorAction Stop
                }
            } else {
                # no interest in connecting, so we can't continue
                Write-Error -Message "No server connected. Cannot create network." -ErrorAction Stop
            }
        }
    }
    # We've ensured that the server is valid, now on to the VMHost
    if ( -Not $VMHost ) {
        $availableHosts = Get-VMHost
        if ($availableHosts.length -eq 0) {
            Write-Error -Message "No VMHosts available" -ErrorAction Stop
        } elseif ($availableHosts.length -eq 1) {
            $VMHost = $availableHosts.Name
            Write-Host -ForegroundColor 'Green' "No VMHost Specified, but only one was available. Going with $VMHost."
        } else {
            Write-Host -ForegroundColor 'Green' "No VMHost Specified, and more than one VMHost available. Please choose one."
            for ($i = 0; $i -lt $availableHosts.Length; $i++) {
                Write-Host ("[{0}]:" -f $i) $availableHosts[$i]
            }
            for (
                $selectionIndex = Read-Host -Prompt "Index number [#] of the desired VMHost";
                ($selectionIndex -lt 0 -or $selectionIndex -ge $availableHosts.Length);
                $selectionIndex = Read-Host -Prompt "Invalid index. Please enter a valid index number") {
            # Do nothing until the answer is valid
            }
        $VMHost = $availableHosts[$selectionIndex].Name
        }
    }
    $vswitch = New-VirtualSwitch -VMHost $VMHost -Name "$Name"
    $vpg = New-VirtualPortGroup -VirtualSwitch $vswitch -Name "$Name"
    # thanks to StackOverflow users mrwaim and David Brabant - see https://stackoverflow.com/a/985001
    return New-Object PSObject -Property @{"VirtualSwitch" = $vswitch; "VirtualPortGroup" = $vpg}
}

function Get-VMNetworkInterface {
    <#
    .SYNOPSIS
    Get the first listed IP, Hostname, and MAC address from a VM's NIC.
    #>
    Param (
        [Parameter(Mandatory=$True)] [String] $VMName,
        [Int32] $NICIndex = 0
    )
    $VM = Get-VM -Name $VMName
    $Nic = $VM.Guest.Nics[$NICIndex]
    $IPAddress = $Nic.IPAddress[0]
    $Hostname = $VM.Guest.Hostname
    $MacAddress = $Nic.MacAddress
    return New-Object PSObject -Property @{"IPAddress" = $IPAddress; "Hostname" = $Hostname; "MacAddress" = $MacAddress}
}

function Get-VMIPInfo { 
    <#
    .SYNOPSIS
    Print the properties returned by Get-VMNetworkInterface formatted for ansible inventories
    #>
    Param (
        [Parameter(Mandatory=$True)] [String] $VMName
    )
    $VMInfo = Get-VMNetworkInterface -VMName $VMName
    $AnsibleVarsLine = "{0} hostname={1} mac={2}" -F $VMInfo.IPAddress, $VMInfo.Hostname, $VMInfo.MacAddress
    Write-Host $AnsibleVarsLine
}

function Start-VMs { 
    <#
    .SYNOPSIS
    Start all of the VMs listed in $VMNames
    #>
    Param (
        [Parameter(Mandatory=$True)] [String[]] $VMNames
    )
    foreach ($VMName in $VMNames) {
        Start-VM -VM $VMName
    }
}

function Set-Network {
    <#
    .SYNOPSIS
    Connect a virtual machine's NIC to a particular network
    #>
    Param (
        [Parameter(Mandatory=$True)] [String] $VMName,
        [Parameter(Mandatory=$True)] [String] $TargetNetworkName,
        [Int32] $VMNicIndex=0
    )
    $Nic = (Get-VM -Name $VMName).Guest.Nics[$VMNicIndex].Device
    Set-NetworkAdapter -NetworkAdapter $Nic -NetworkName $TargetNetworkName
}
