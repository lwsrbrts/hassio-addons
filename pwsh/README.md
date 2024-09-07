# Home Assistant Add-on: PowerShell for Home Assistant

Run PowerShell scripts as threaded jobs in Home Assistant with logging.

![Supports amd64 Architecture][amd64-shield]

## About

This add-on is intended to allow you to run arbitrary PowerShell scripts that YOU create. The scripts should be placed in the `\\{HASS}\share\pwsh` folder of Home Assistant and then declared in the `Scripts` section of the configuration with its full name. If the folder doesn't exist, you can either create it, or the add-on will create it for you. Once created, add files to the folder and declare the `Scripts` in the `Configuration` section as discussed below.

## How do I use it?

Install it, copy your scripts to `\\{HASS}\share\pwsh` (create it if you need to), then add the file names of the scripts to the `Scripts` section in `Configuration` as follows:

```yaml
- filename: My-AwesomeScript.ps1
- filename: My-OtherAwesomeScript.ps1
```

Start the add-on and review the Log to see any output.

## How does it work?

The add-on is just a container with PowerShell installed which kicks off a threading script that retrieves the scripts by their name as specified in the `Configuration > Scripts` section. Your scripts are executed as PowerShell threaded jobs using `Start-ThreadJob`. The jobs are regularly checked for any output and "received" by the parent threading process, such that you can get logs from your scripts.

## Why does it only run my script once or the add-on keep stopping?

If your script would start, do stuff and then return you to a PowerShell prompt when run on your own computer, that's exactly what it will do in this add-on too. It doesn't handle continual or scheduled executions. If your script finishes, the add-on's logs will tell you that the job has been removed and its state at that point.

If you need your script to run continuously, consider wrapping it in an appropriate loop (`while`, `until`, `for`, `foreach` etc.) just as you would to have it run continuously on your own computer, but be aware that if using a `while` or `until` loop that you include a suitable `Start-Sleep` with a *sensible* delay at the end of the while loop or this add-on will consume all available container resources - don't say I didn't warn you.

If the add-on is stopping, then it either has no scripts to run, it has finished running the scripts or something failed. Obviously these are your scripts, I'm just running them as a threaded job in this add-on. 

If your script isn't working, please don't ask me to fix it. Take it back to your computer and try running it as a threaded job there to see what happens. If you believe you found the reason and it could be related to the threading script, please feel free to let me know.

## How do I provide arguments to my scripts?

In this iteration, you can't. You would need to add or declare all your arguments as variables and store them within the script. Technically there's no reason why you can't have this add-on run a script that calls your other script but logging may not work as expected or you'll need to manage that in your script yourself.

## Logging

Logs are output to the `Log` section of the add-on, logs are colour highlighted and named according to the name of the script the log is associated. To achieve this, you should use `Write-Output` in your scripts or formatting.

NB: If you use `Write-Host` you will receive the output immediately in the Log section of the add-on, but the output would not be associated with any script, unless you do that yourself.

## I want to export/import some data to/from a file.

The container only has read/write access to the `/share` folder in Home Assistant. This _does_ mean that you can use Home Assistant's Network Storage feature to mount a network folder from eg. a NAS and have your PowerShell script dropping or retrieving anything from there that you want it to.

## Ugh! PowerShell?!

Yes. It's an open-source scripting language that you can actually do quite a lot with and this add-on simply enables another option for Home Assistant users to automate their home.

## I'm dubious about this container, what's it doing?

The code for the add-on is freely available on Github. You can only add the add-on from a Github repository so, if you're concerned, feel free to fork the code to your own repo, inspect it, add your own repo to Home Assistant and use that as the add-on's source instead.

The add-on is using the base Home Assistant add-on Alpine Linux image which the latest version of PowerShell and its dependencies are installed to. The threading script is then added and that's all. If you want to know more, review the `Dockerfile` in the repository.

[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg

