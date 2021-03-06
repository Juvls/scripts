#region Support
<#
.SYNOPSIS
    Synchronize the setpoints of multiple Nest thermostats using the APIs
.DESCRIPTION
    This script uses the Nest APIs to poll setpoints from a list of thermostats as 
	defined in the side-by-side .\nest.xml, and synchronize them between the specified hours, 
	which is hardcoded from 8-5PM in this script. To use, populate the relevant fields in the 
	nest.xml config file, including the API authorization code, list of thermostat UIDs, & structure UID.
.EXAMPLE
    PS C:\scripts\ > .\nest_sync.ps1
#>
#endregion
function CallNest ($url, $headers, $method, $body)
{
	if ($method -eq 'Put')
	{
		$response = Invoke-WebRequest $url -Headers $headers -Method $method -Body $body -MaximumRedirection 0
		if ($response.StatusCode -eq '307')
		{
			Start-Sleep -Seconds 3
			Invoke-WebRequest $response.Headers.Location -Headers $headers -Method $method -MaximumRedirection 0 -Body $body
		}
	}
	else 
	{ 
		$response = Invoke-WebRequest $url -Headers $headers -Method $method -MaximumRedirection 0 
		if ($response.StatusCode -eq '307')
		{
			Start-Sleep -Seconds 3
			Invoke-RestMethod $response.Headers.Location -Headers $headers -Method $method -MaximumRedirection 0 
		}
	}
		
}
#region Variables
$path = Split-Path -Parent $MyInvocation.MyCommand.Definition
$xmlconf = New-Object xml
$xmlconf.Load("$($path)\nest.xml")
$auth_code = $xmlconf.auth_code
$tstats = $xmlconf.tstats.Split(',')
$structure = $xmlconf.structure
#endregion
#region Main
[int]$hour = get-date -format HH
If($hour -gt 8 -and $hour -lt 17)
{ 
	
	$headers = @{}
	$headers.Add("cache-control", 'no-cache')
	$headers.Add("content-type", 'application/json')
	$headers.Add("authorization", "Bearer $auth_code")

	$baseURL = "https://developer-api.nest.com/"

	$devices = CallNest ($baseURL + "devices") $headers "Get"
	Start-Sleep -Seconds 5
	$structures = CallNest ($baseURL + "structures") $headers "Get"

	$upstairs = $tstats[0]
	$downstairs = $tstats[1]

	If ($structures.$structure.away -eq 'home' -and `
	$devices.thermostats.$downstairs.target_temperature_f -ne $devices.thermostats.$upstairs.target_temperature_f -and `
	$devices.thermostats.$downstairs.hvac_mode -eq 'cool' -and 
	$devices.thermostats.$upstairs.hvac_mode -eq 'cool')
	{		
		Start-Sleep -Seconds 2
		$body = @{ target_temperature_f = $devices.thermostats.$upstairs.target_temperature_f }
		$body = $body | ConvertTo-Json	
		CallNest ($baseURL + "devices/thermostats/$downstairs") $headers "Put" $body		
	}
}
#endregion