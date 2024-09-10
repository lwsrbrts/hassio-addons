# Interacting with Home Assistant

## Create/update a sensor

This example shows how to use PowerShell to integrate with the Supervisor API to create or update a sensor. Note that we refer to the Supervisor by its internal/docker name, rather than an IP address or how you might access it yourself on your own network.

We also use an environment variable `$env:SUPERVISOR_TOKEN` that contains a long-lived token, automatically supplied to the add-on by the Supervisor, which we use to authenticate the request.

Then we use a `while` loop to run the activities for creating/updating the sensor. We also check for the existence of a file which allows us to escape from the `while` loop when we need to.

```powershell
# The container defaults to US style date and time format.
# I'm British so I set the culture appropriately for this session.
$CultureInfo = New-Object System.Globalization.CultureInfo("en-GB")
[System.Threading.Thread]::CurrentThread.CurrentCulture = $CultureInfo
[System.Threading.Thread]::CurrentThread.CurrentUICulture = $CultureInfo

$homeAssistantSensor = 'sensor.pwsh_test_script'
$homeAssistantToken = $env:SUPERVISOR_TOKEN

# Define the Home Assistant API URL and the sensor name
$homeAssistantUrl = "http://supervisor/core/api/states/$homeAssistantSensor"

# Use this to specifically stop this job/script or it'll run forever.
$stopFile = "/share/pwsh/TEST/stop"

while (-not (Test-Path $stopFile)) {
	
    $body = @{
        state      = 'OK' # This could be something else here.
        attributes = @{
            friendly_name  = "Test Script"
            last_execution = [int](Get-Date -UFormat %s)
        }
    } | ConvertTo-Json -Depth 5

    # Send the data to Home Assistant
    $ha_response = Invoke-RestMethod -Uri $homeAssistantUrl -Method Post -Headers @{
        "Authorization" = "Bearer $homeAssistantToken"
        'Content-Type'  = 'application/json'
    } -Body $body

    # From the response, we get the last_reported date/time value and output it.
    $utcDateTime = $ha_response.last_reported
    $utcDateTimeObj = [DateTime]::Parse($utcDateTime)

    'Last HA POST: {0}' -f $utcDateTimeObj

	Start-Sleep -Seconds 10
}

'Stop file found. Exiting.'
```

This is just an example, obviously there is no error checking in the example above. Add it as required.