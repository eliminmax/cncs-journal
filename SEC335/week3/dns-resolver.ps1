param($network, $server)

foreach($hostAddress in 1..254) {
    $ip = "$network" + "." + "$hostAddress"
    
    $i = (Resolve-DnsName -DnsOnly $ip -Server $server -ErrorAction Ignore)

    if ($i) {
        Write-Output "$ip $($i.NameHost.toString())"
    }
}