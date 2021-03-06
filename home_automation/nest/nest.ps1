#region Support
<#
.SYNOPSIS
    Gather temperature and setpoint metrics from Nest thermostats and write them to a SQL database
.DESCRIPTION
    This script uses the Nest APIs to poll setpoint and temperature metrics from a list of thermostats
    defined in the side-by-side .\nest.xml. To use, populate the relevant fields in the nest.xml config
    file, including the API authorization code, list of thermostat UIDs, OpenWeather API Key, and 
    U.S. zip code for outside temperature.
.EXAMPLE
    PS C:\scripts\ > .\nest.ps1
#>
#region Variables
$path = Split-Path -Parent $MyInvocation.MyCommand.Definition
$xmlconf = New-Object xml
$xmlconf.Load("$($path)\nest.xml")
$auth_code = $xmlconf.auth_code
$tstats = $xmlconf.tstats.Split(',')
$owkey = $xmlconf.owkey
$zipcode = $xmlconf.zipcode
$sqlserver = $xmlconf.sqlserver
$headers = @{}
$headers.Add("Content-Type", 'application/json')
$headers.Add("Authorization", "Bearer $auth_code")
#endregion 
#region Main
$response = Invoke-WebRequest "https://developer-api.nest.com/devices" -Headers $headers -Method Get -MaximumRedirection 0 
if ($response.StatusCode -eq '307')
{
	Start-Sleep -Seconds 2
	$nestdevices = Invoke-RestMethod $response.Headers.Location -Headers $headers -Method Get -MaximumRedirection 0 
}
else { $nestdevices = $response }
$currentweather = Invoke-RestMethod "http://api.openweathermap.org/data/2.5/weather?zip=$zipcode,us&APPID=$owkey&units=imperial"
foreach ($tstat in $tstats)
{
    $tstatobj = New-Object -TypeName PSObject
    Add-Member -InputObject $tstatobj -Type NoteProperty -Name 'Name' -Value $nestdevices.thermostats.$tstat.name
    Add-Member -InputObject $tstatobj -Type NoteProperty -Name 'Humidity' -Value $nestdevices.thermostats.$tstat.humidity
    Add-Member -InputObject $tstatobj -Type NoteProperty -Name 'Temperature' -Value $nestdevices.thermostats.$tstat.ambient_temperature_f
    Add-Member -InputObject $tstatobj -Type NoteProperty -Name 'Target' -Value $nestdevices.thermostats.$tstat.target_temperature_f
	Add-Member -InputObject $tstatobj -Type NoteProperty -Name 'Outside Temp' -Value $currentweather.main.temp
	Add-Member -InputObject $tstatobj -Type NoteProperty -Name 'Outside Humidity' -Value $currentweather.main.humidity
    $tstatobj | Write-ObjectToSQL -Server $sqlserver -Database $dbname -TableName $tablename
}
#endregion