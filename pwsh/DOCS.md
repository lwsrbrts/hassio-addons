# Documentation

## How does it work?

As per the README, there are two modes:

 - **Declared** - script file names you set in the configuration.
 - **On-demand** - script file names you send to the add-on.

The add-on is just a Docker container with PowerShell installed which, when started, kicks off a PowerShell script that executes your **Declared** scripts by their name and path as specified in the `Configuration > Scripts` section as threaded jobs.

**Declared** scripts are executed as PowerShell threaded jobs using `Start-ThreadJob`. The jobs are regularly checked for any output and "received" (`Receive-Job`) by the parent process, such that you can get logs from your scripts without jumping through hoops.

**On-Demand** scripts are run using `Start-Process` calling only the PowerShell binary `pwsh` and supplying the `-File <path>` argument to the process.

## Why does it only run my script once or the add-on keep stopping?

If your script would start, do stuff and then return you to a PowerShell prompt when run on your own computer, that's exactly what it will do in this add-on too. If you need your scripts to run at arbitrary times, enable the `On-Demand` feature and use Home Assistant's `hassio.addon_stdin` Action as discussed in the **Info** tab. If your script finishes, the add-on's logs will tell you that the job has been removed and its state at that point.

If you need your script to run continuously at set intervals, don't just spam the `On-Demand` feature, consider wrapping it in an appropriate loop (`while`, `do-while`, `do-until`, `for`, `foreach` etc.) just as you would to have it run continuously on your own computer, but be aware that if using a `while`, `do-while` or `do-until` loop that you should include a suitable `Start-Sleep` with a *sensible* delay at the end or beginning of the loop, or this add-on will consume all available container resources - **_don't say I didn't warn you!_**

Here's a looping example that allows you to control when the script stops.

```powershell
$stopFile = "/share/pwsh/One-Minute/stop"
do {
    "Hi"
    Start-Sleep -Seconds 60
} while (-not (Test-Path $stopFile))
Write-Output "Stop file found. Exiting."
```

If the add-on is stopping, then it either has no scripts to run, it has finished running the scripts, something failed or the `On-Demand` feature isn't enabled. Obviously these are *YOUR* scripts, the add-on is just running them using `Start-ThreadJob` for **Declared** scripts or using `Start-Process` for **On-Demand** scripts.

If your script isn't working, please don't ask me to fix it or ask me why it isn't working. Take it back to your computer and try running it as a threaded job (see [Start-ThreadJob](https://learn.microsoft.com/en-us/powershell/module/threadjob/start-threadjob?view=powershell-7.4)) to see what happens. If you believe you found the reason and it could be related to the threading script and it can probably be fixed, please feel free to let me know.

## How do I provide arguments to my scripts?

In this iteration, you can't. That will come in due course, but at this time, you would need to add or declare all your arguments as variables and store them within the script. See the section on passwords below for another idea...

## How do I use passwords?

That's up to you. The easy way is to just put them in your script, however, it is worth mentioning that the container has access to its own add-on folder which is mapped to the `/config/` folder in the add-on's environment.

You can place files in the `\\{HASS}\addon_configs\{random-chars}_pwsh` folder that you could use to store your passwords, away from the relative free-for-all of the `/share` folder.

As an example, to store passwords for a specific script, I might use a JSON file format as follows:

```json
{
  "accounts": [
    {
      "key": "EmailAccount",
      "username": "user@example.com",
      "password": "examplePassword123"
    },
    {
      "key": "BankAccount",
      "username": "bankUser",
      "password": "bankPassword456"
    },
    {
      "key": "SocialMedia",
      "username": "socialUser",
      "password": "socialPassword789"
    }
  ]
}
```

Assuming you save this in a file called `passwords.json` within the `\\{HASS}\addon_configs\{random-chars}_pwsh` folder, you could access it as follows within your script.

```powershell
$content = Get-Content '/config/passwords.json' -Raw | ConvertFrom-Json # Get the JSON file as an object.
$content.accounts # Show all the "accounts" in the file.
$emailAccount = $content.accounts | Where-Object { $_.key -eq 'EmailAccount' } # Get the content for the EmailAccount
$emailAccount.username # The username for the EmailAccount account.
$emailAccount.password # The password for the EmailAccount account.
```

Realistically, this isn't technically any more secure than putting your passwords in your scripts but then, even your `secrets.yaml` file is just as accessible. 

Remember that only admin role holders should really be able to access your Home Assistant `/share/` or `/addon_configs/` folders, or even be running scripts with this add-on.

For a more secure approach, you could consider making use of the [SecretManagement module](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.secretmanagement/?view=ps-modules)

## How do I use my own/PowerShell Gallery modules?

With this add-on being a container, you must consider how you handle modules across upgrades since installing modules with `Install-Module` will work, but when you upgrade, the new container image won't have those modules installed. It's the same reason you store your scripts outside of the container in `share` or `addon_configs`.

For simplicity, my suggestion is that you use `Save-PSResource` ( `Save-Module` is an alias of `Save-PSResource`) and specify the location where you want to store the module. Copy something like this in to a script and configure the add-on to run it as an On-Demand script:

```powershell
New-Item -Path '/share/pwsh/psmodules' -Type Directory
$moduleName = 'MySuperModule'
Save-PSResource -Name $moduleName -Repository PSGallery -Path '/share/pwsh/psmodules'
```

Then when you want to use the module in a different script, you can `Import-Module` from the location you saved it to, like this:

```powershell
$moduleName = 'MySuperModule'
Import-Module -Name /share/psmodules/$moduleName/ -Verbose
```

If you want to use a specific version of the module, adjust your save and/or import commands as appropriate.

## I want to export/import some data to/from a file.

For reference, using the Samba add-on, navigate to the network location for your Home Assistant instance.

* The add-on has read/write access to the `share` folder and all of its sub-folders.
* The add-on also has read-only access to its own `addon_configs` folder.
* The add-on _cannot_ read Home Assistant `config` since it (currently) doesn't need to.

This _does_ mean that you can use Home Assistant's Network Storage feature to mount a network folder from eg. a NAS and have your PowerShell script dropping or retrieving anything, like logs, from there that you want it to.

For something that should be slightly more private, like a passwords.json file as discussed above, you could place that (using the Samba add-on) in to the ``\\{HASS}\addon_configs\{random-chars}_pwsh` folder.

Here's a very basic example.

```powershell
# I set the culture to British English, since I'm British.
$CultureInfo = New-Object System.Globalization.CultureInfo("en-GB")
[System.Threading.Thread]::CurrentThread.CurrentCulture = $CultureInfo
[System.Threading.Thread]::CurrentThread.CurrentUICulture = $CultureInfo

Get-Date | Out-File -FilePath /share/pwsh/On-Demand.txt -Append # -FilePath could be anywhere in /share/
Start-Sleep -Seconds 10 # This isn't needed, just an example.
```

## I want to read/create sensors in Home Assistant.

This example shows how to use PowerShell to integrate with the Home Assistant REST API to create or update a sensor. Note that we refer to the Home Assistant REST API by its internal/docker name, rather than an IP address or how you might access it yourself on your own network.

We also use an environment variable `$env:SUPERVISOR_TOKEN` that contains a long-lived token which is automatically supplied to the add-on by the Supervisor when the add-on is started. We must use the token to authenticate the API request.

In this example we use a `while` loop to run the activities for creating/updating the sensor. We also check for the existence of a file which allows us to escape from the `while` loop when we need to.

```powershell
# The container defaults to US style date and time format which you can override as follows:
# I'm British so I set the culture appropriately for THIS session.
$CultureInfo = New-Object System.Globalization.CultureInfo("en-GB")
[System.Threading.Thread]::CurrentThread.CurrentCulture = $CultureInfo
[System.Threading.Thread]::CurrentThread.CurrentUICulture = $CultureInfo

$homeAssistantSensor = 'sensor.pwsh_test_script' # The sensor I'm creating/updating.
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

	Start-Sleep -Seconds 10 # This is important or the REST API will be hammered.
}

'Stop file found. Exiting.'
```

This is just an example, obviously there is no error checking in the example above.

## How does logging work?

### for **Declared** scripts...

...logs are output to the `Log` section of the add-on. Logs are colour highlighted to aid visibility and easy association with the script. The colour of the highlight remains the same for that specific script per-session, which means that the next time the add-on is started, the associated highlight colour could be different

TIP: Use `Write-Output` in your scripts.

NB: If you use `Write-Host` you will receive the output immediately in the `Log` section of the add-on, but the output would not be associated with any script, unless you do that yourself.

For a script called `TEST.ps1` and declared in the Scripts section as `- filename: TEST.ps1`, logging might look something like this.

![Logging example](../resources/pwsh/images/logging.png)

### for **On-Demand** scripts...

...logging is *usually* output to the `Log` section but, depending on how your script is outputting log data, you may not see it there. You might consider it better to handle logging to a `.log` file yourself.

## Ugh! PowerShell?!

Yes. It's an open-source (MIT License) scripting language that you can actually do quite a lot with and this add-on simply enables another option for Home Assistant users to automate their home.

### Well, I can do all that with Python/Shell Script/Go...etc.

Like me, others might be more confident with PowerShell than any of the other options, and even as ubiquitous as Python is, not everyone has the skills.

## I'm dubious about this container, what's it doing?

The code for the add-on is freely available on Github. You can only add the add-on from a suitable public Git repository so, if you're concerned, feel free to fork the code to your own repo, inspect it, add your own repo to Home Assistant and use that as the add-on's source instead.

The add-on is using the base Home Assistant add-on Alpine Linux image which the latest version of PowerShell and its dependencies are installed to. The threading script and stdin listening scripts are then added and that's all. If you want to know more, review the `Dockerfile` in the repository.