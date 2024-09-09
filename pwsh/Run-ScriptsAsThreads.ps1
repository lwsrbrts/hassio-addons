# Set up some stuff we only need to do once.
# Set the culture to British English, since I'm British.
#$CultureInfo = New-Object System.Globalization.CultureInfo("en-GB")
#[System.Threading.Thread]::CurrentThread.CurrentCulture = $CultureInfo
#[System.Threading.Thread]::CurrentThread.CurrentUICulture = $CultureInfo

# Path to options.json file - this is the file that's placed/mapped/linked in to the running container.
$OPTIONS_FILE = '/data/options.json'

# Read and convert the JSON file to a PowerShell object - we'll use these to get data from the user for use later.
$OPTIONS = Get-Content $OPTIONS_FILE | ConvertFrom-Json -ErrorAction Stop

# Throttle Limit defines the number of scripts that will be started as threads by *this* script.
# Bear in mind that if the `Scripts` list's first n scripts run as infinite loops, any scripts over
# the Throttle Limit will never start (and will spam the logs too). So you'll either need to increase
# the Throttle Limit, or have the other scripts start (and complete) before your infinite looping scripts.
$ThreadThrottleLimit = [int]$OPTIONS.threads

# Colours for banner information during startup etc.
$green = $PSStyle.Foreground.Green
$red = $PSStyle.Foreground.Red
$reset = $PSStyle.Reset

# We still want to limit the number of scripts.
if ($OPTIONS.scripts.length -gt 10) {
    throw "Scripts are limited to a maximum of 10 at a single time."
}

# /mnt/data/supervisor/addons/data/local_pwsh is mapped from the host to the container as /data and where options.json lives.
# We want the share folder to map to the container so the user places their scripts there.
$defaultScriptLocation = '/share/pwsh/'
if (!(Test-Path $defaultScriptLocation)) {
    $FolderBanner = @"
${green}
#####################################
## Creating /share/pwsh folder...  ##
#####################################

########################################################
## Since the folder has just been created, the add-on ##
## will stop now. Add your scripts and configure the  ##
## add-on now.                                        ##
########################################################${reset}
"@
    $FolderBanner
    New-Item -Path $defaultScriptLocation -ItemType Directory > $null
    Exit 0
}

# Warn the user that on-demand is enabled.
$ondemand = $OPTIONS.ondemand
if ($ondemand) {
    $OnDemandBanner = @"
${red}
###############################################
##      ! ON-DEMAND MODE ENABLED !           ##
##                                           ##
##   When enabled, a thread job is created   ##
##   to stop the add-on from exiting after   ##
##   Declared scripts complete.              ##
##                                           ##
## Use hassio.addon_stdin to send filenames. ##
## Please review the README for more detail. ##
###############################################
${reset}
"@
    $OnDemandBanner
    Start-ThreadJob -ScriptBlock {while($true){Start-Sleep -Seconds 3600}} -Name 'On-Demand-Listener' -ErrorAction Stop -ThrottleLimit $ThreadThrottleLimit > $null
    Start-Process nohup 'pwsh -NoProfile -NoLogo -File /app/Read-HassIoStdIn.ps1'
}

# Doing this forces the user to know and set what scripts will run. Just banging them in a folder ain't good.
$scripts = $OPTIONS.scripts

# A way to understand what log is associated with what script.
$jobColours = @{}
$randomisedColours = $PSStyle.Background.PSObject.Properties.Name | Where-Object { $_ -notmatch "Bright" } | Sort-Object { Get-Random }
$i = 0

$scriptCount = $scripts.Count

if ($scriptCount -gt 0) {
    $StartupBanner = @"
${green}
###########################
## DECLARED SCRIPTS MODE ##
##                       ##
##    Starting up...     ##
##                       ##
##   PowerShell $($PSVersionTable.PSVersion.ToString())    ##
##   ThrottleLimit: $ThreadThrottleLimit    ##
##   $(Get-Date -UFormat '%Y-%m-%d %H:%M')    ##
###########################
${reset}
"@
    $StartupBanner
}

if (($scriptCount -eq 0) -and ($null -eq $ondemand)) {
    $NoScriptsBanner = @"
${green}
######################################
## No scripts were found in the     ##
## Configuration -> Scripts section ##
## of the add-on and On-Demand Mode ##
## is not enabled either. 🤦        ##
## Nothing else to do. Bye.         ##
######################################
${reset}
"@
    $NoScriptsBanner
    Exit 0
}

# Loop through each script and start a thread job for each one
foreach ($script in $scripts) {
    
    if ($null -eq $script.path) { $scriptLocation = $defaultScriptLocation }
    else { $scriptLocation = $script.path }

    $scriptFullPath = Join-Path $scriptLocation $script.filename

    $validPath = Test-Path -Path $scriptFullPath -PathType Leaf

    if ($validPath) {
        $thisScript = Get-Item -Path $scriptFullPath
        try {
            $job = Start-ThreadJob -FilePath $thisScript.FullName -Name $thisScript.BaseName -StreamingHost $Host -ErrorAction Continue -ThrottleLimit $ThreadThrottleLimit

            $randomColour = $randomisedColours[$i]
            $jobColours[$job.Name] = $randomColour  # Store the job name and its associated colour
            "$($PSStyle.Background.$randomColour)$($job.Name)$($PSStyle.Reset) {0}." -f 'created'
            $i++
            if ($i -eq 8) { $i = 0 }
        }
        catch {
            "$($PSStyle.Foreground.Red)Unable to start the thread for: {0}{1}$($PSStyle.Reset)" -f $scriptLocation, $script.filename
            $i++
            if ($i -eq 8) { $i = 0 }
        }
    }
    else {
        "$($PSStyle.Foreground.Red)Unable to find path: {0}{1}$($PSStyle.Reset)" -f $scriptLocation, $script.filename
    }
}

$jobCount = (Get-Job).Count

if ($jobCount -eq 0) {
    $NoJobsBanner = @"
${green}
#############################################
## No thread jobs were added and On-Demand ##
## Mode is not enabled/running. Did you    ##
## forget to add your scripts in the       ##
## right place?                            ##
## Nothing else to do. Bye.                ##
#############################################
${reset}
"@
    $NoJobsBanner
    Exit 0
}
else {
    $JobsRunningBanner = @"
${green}
########################################
## On-Demand Mode / Declared scripts  ##
## running...                         ##
##                                    ##
## ThrottleLimit: $ThreadThrottleLimit                   ##
## $(Get-Date -UFormat '%Y-%m-%d %H:%M')                   ##
########################################
${reset}
"@
    $JobsRunningBanner

    # Deals with the case where we receive multiple lines or a single line of output from Receive-Job.
    function Out-JobData {
        param (
            [Parameter(Mandatory = $true)]
            $data,
            
            [Parameter(Mandatory = $true)]
            [string]$jobName,
    
            [Parameter(Mandatory = $true)]
            [string]$jobColour
        )
        if ($data -is [array]) {
            for ($i = 0; $i -lt $data.Count; $i++) {
                "$($PSStyle.Background.$jobColour)$($jobName)$($PSStyle.Reset): {0}" -f $data[$i]
            }
        }
        else {
            "$($PSStyle.Background.$jobColour)$($jobName)$($PSStyle.Reset): {0}" -f $data
        }
    }
}

while ($jobs = Get-Job) {
    foreach ($job in $jobs) {

        # No point processing anything if it's the On-Demand-Listener job.
        if ($job.Name -eq 'On-Demand-Listener') { Continue }

        $jobColour = $jobColours[$job.Name]
        switch ($job.State) {
            { ($_ -eq 'Completed') -or ($_ -eq 'Stopped') -or ($_ -eq 'Failed') } {
                if ($job.HasMoreData) {
                    $data = Receive-Job -Job $job
                    Out-JobData -data $data -jobName $job.Name -jobColour $jobColour
                }
                else {
                    "$($PSStyle.Background.$jobColour)$($job.name)$($PSStyle.Reset): {0}{1}{2}" -f 'Done. Removing this ', $job.State.ToUpper(), " job."
                    Remove-Job -Job $job > $null
                }            
            }
            'Running' {
                if ($job.HasMoreData) {
                    $data = Receive-Job -Job $job
                    Out-JobData -data $data -jobName $job.Name -jobColour $jobColour
                }

            }
            'NotStarted' {
                "$($PSStyle.Background.$jobColour)$($job.name)$($PSStyle.Reset): {0}" -f "This job hasn't started yet, waiting for a job slot (Throttle Limit!)..."
                Continue
            }
            Default {
                if ($job.HasMoreData) {
                    $data = Receive-Job -Job $job
                    Out-JobData -data $data -jobName $job.Name -jobColour $jobColour
                }
                else {
                    "$($PSStyle.Background.$jobColour)$($job.name)$($PSStyle.Reset): {0}{1}{2}" -f 'Stopping this ', $job.State.ToUpper(), " job."
                    Stop-Job -Job $job > $null
                } 
            }
        }
    }
    Start-Sleep -Seconds 10
}

$CompleteBanner = @"
${green}#######################
##  HASS PowerShell  ##
## All jobs complete ##
## $(Get-Date -UFormat '%Y-%m-%d %H:%M')  ##
#######################${reset}
"@

$CompleteBanner