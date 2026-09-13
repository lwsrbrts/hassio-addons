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

## Making the sensor persistent

One caveat with the example above: a state created via `POST /api/states/...` is **not backed by a real entity in Home Assistant**. It's fine for a quick test, but it's gone after a Home Assistant restart. If your script is updating a sensor you want to keep, declare a simple template sensor in your `configuration.yaml` that just mirrors the raw state your script posts to. No changes to your script are needed.

Add something like the following to your `configuration.yaml`:

```yaml
template:
  - sensor:
      - name: "PowerShell Test Script"
        state: "{{ states('sensor.pwsh_test_script') }}"
        attributes:
          last_execution: "{{ state_attr('sensor.pwsh_test_script', 'last_execution') }}"
```

A template sensor re-renders whenever the data it references changes, so the example above keeps updating it every time it posts to `sensor.pwsh_test_script`. The new sensor's entity_id is derived from its `name` (so `sensor.powershell_test_script` in this case), and because it's declared in your configuration it survives a restart — it'll just show `unknown` until your script runs again and posts the first update.

NB:

- The template sensor has its own `name`, so the `friendly_name` attribute in the example above is redundant (though harmless).
- If your value is numeric, add `unit_of_measurement` (and `state_class` where relevant) to the template sensor so Home Assistant treats it as a proper numeric sensor for history and graphs. Your script needs to post a numeric state in that case.
- If you need a specific entity_id rather than the one derived from the `name`, use `default_entity_id`.

After saving, either restart Home Assistant or reload the template integration (Developer Tools → Actions → `template.reload`).