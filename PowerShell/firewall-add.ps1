New-NetFirewallRule -RemoteAddress 192.168.100.0/24 -DisplayName "Trusted Subnet" -Direction inbound -Profile Any -Action Allow
