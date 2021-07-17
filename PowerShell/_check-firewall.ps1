# Run this script like: .\CheckFirewallOpenings.ps1 FirewallTests.csv
# NOTE: It presumes you're running the script on the machine you're checking access from. 
# (e.g. if you're checking Server1 --> Server2, you'd be running this script on Server1.)

param ($portFileName)

function GetResultObject
{
    param (
        [string]$Server,
        [int]$Port,
        [bool]$PortOpen,
        [string]$Notes,
        [string]$Purpose
    )

    $props = @{
                FromServer = $env:COMPUTERNAME
                ToServer = $Server
                Port = $Port
                PortOpen = $PortOpen
                Notes = $Notes
                Purpose = $Purpose
            }

    New-Object PsObject -Property $props
}

function TestPing
{
    param 
    (
        [string]$Server
    )

    return Test-Connection $Server -Count 1 -Quiet
}

function CheckOpenPortOnServer
{
    param (
        [string]$Server,
        [string]$PortToCheck
    )

    try {       
        $null = New-Object System.Net.Sockets.TCPClient -ArgumentList $Server,$PortToCheck
        return $true
    }

    catch {
        return $false
    }
}

function FirewallEntry
{
	param (
		[string]$Server,
		[string]$Port,
        [string]$Purpose
	)

	$props= @{
		RemoteServer = $Server
		RemotePort = $Port
        Purpose = $Purpose
        
	}

	return New-Object PsObject -Property $props
}

function RunPortCheck
{

  param (
   [String]$file #This is meant to be a CSV with Server, Port, and "Purpose" fields. Purpose describes why the port is needed, so that we can reason about things more easily.
  )

	$testsToRun = Import-Csv -Path $file

	$serversAndPorts = @()
	 
	foreach($test in $testsToRun)
	{
		$convertedItem = FirewallEntry -Server $test.ToServer -Port $test.Port -Purpose $test.Purpose
		$serversAndPorts = $serversAndPorts + $convertedItem
	}

	$results = @()
	foreach ($item in $serversAndPorts) 
	{
		If(TestPing -Server $item.RemoteServer)
		{
			$result = CheckOpenPortOnServer $item.RemoteServer $item.RemotePort
			$resultObj = GetResultObject -Server $item.RemoteServer -Port $item.RemotePort -PortOpen $result -Purpose $item.Purpose
		}
		Else
		{
			$resultObj = GetResultObject -Server $item.RemoteServer -Port $item.RemotePort -PortOpen $false -Notes 'Server did not respond to ping and may be down.' -Purpose $item.Purpose
		}

		$results = $results + $resultObj
	}
    
    $failedItems = $results | ? { $_.PortOpen -eq $false } | measure
    If ($failedItems.Count -gt 0)
    {
  		Write-Host "Womp womp, we failed."
		  Write-Host "Number of failures: " + $failedItems.Count
    }
    Else
    {
  		Write-Host "We're all good!"
    }

    foreach($result in $results)
    {
        $serverAndPort = $result.ToServer + ":" + $result.Port
        If($result.PortOpen -eq $true)
        {
            $status = "SUCCESS"
        }
        Else
        {
            $status = "FAILURE"
        }

        $statusMessage = "Status: ($status) -- Purpose: " + $result.Purpose
    		Write-Host $statusMessage
    }

	Write-Host "Full Results below: "
	$results | Format-Table -AutoSize
}

RunPortCheck -file $portFileName
