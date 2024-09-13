$ErrorActionPreference = "Stop" # Cause the container to fail (and restart if that's configured) if there is an issue.

# Get a timestamp that's in a format suitable for the Ecoflow HTTP API.
function Get-Timestamp {
    return [int64](([datetime]::UtcNow - [datetime]'1970-01-01').TotalMilliseconds)
}

# Get a nonce (random variable) that's in a format suitable for the Ecoflow HTTP API.
function Get-Nonce {
    return (Get-Random -Minimum 100000 -Maximum 999999).ToString()
}

# Flatten a hashtable in to a single layer suitable for processing by Format-SigningString.
function Merge-Hashtable {
    param (
        [hashtable]$Hashtable,
        [string]$Prefix = ''
    )

    if ($hashtable -eq $null) { return $null }

    $result = @{}

    foreach ($key in $Hashtable.Keys) {
        $value = $Hashtable[$key]
        $newKey = if ($Prefix) { "$Prefix.$key" } else { $key }

        if ($value -is [hashtable]) {
            $result += Merge-Hashtable -Hashtable $value -Prefix $newKey
        }
        elseif ($value -is [array]) {
            for ($i = 0; $i -lt $value.Length; $i++) {
                $result["$newKey[$i]"] = $value[$i]
            }
        }
        else {
            $result[$newKey] = $value
        }
    }

    return $result
}

# Format the signing string (the thing we must sign) in to a format suitable for the Ecoflow API.
# This could be parameters from a provided hashtable, parameters from the HTTP GET URL 
# but never both _OR_ it could be none of these, but we still need to return a suitable signing string.
function Format-SigningString {
    param (
        [hashtable]$params,
        [string]$url_params,
        [string]$EcoflowAccessKey,
        [string]$nonce,
        [string]$timestamp
    )

    # Initialise the signable string
    $signableString = ""

    if ($params) {
        # If there are parameters, sort them by key (name) in ASCII order and concatenate them into a string
        $sortedParams = ($params.GetEnumerator() | Sort-Object Name | ForEach-Object {
                "$($_.Key)=$($_.Value)"
            }) -join "&"
        
        # Build the signable string with sorted parameters
        $signableString = "$sortedParams&accessKey=$EcoflowAccessKey&nonce=$nonce&timestamp=$timestamp"
    }
    elseif ($url_params) {
        # If no parameters were provided but URL parameters exist, use them
        $signableString = "$url_params&accessKey=$EcoflowAccessKey&nonce=$nonce&timestamp=$timestamp"
    }
    else {
        # If neither parameters nor URL parameters are provided, build a signable string with just the basic keys
        $signableString = "accessKey=$EcoflowAccessKey&nonce=$nonce&timestamp=$timestamp"
    }

    return $signableString
}


# We sign the request (technically the stringToSign) using HMAC-SHA256.
function Get-Signature {
    param (
        [string]$stringToSign,
        [string]$access_key,
        [string]$secret_key,
        [string]$nonce,
        [string]$timestamp
    )
    
    # Create HMAC-SHA256 signature
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = [System.Text.Encoding]::UTF8.GetBytes($secret_key)
    $signBytes = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringToSign))  
    $signature = -join ($signBytes | ForEach-Object { "{0:x2}" -f $_ })
    
    return $signature
}

function Get-HttpData {
    # We use some parameter sets to ensure that we get the variables we need during execution of a 
    # particular RequestType. We need the secret, access and api host each time for every request.
    [CmdletBinding(DefaultParameterSetName = 'DeviceList')]
    param (      
        [Parameter(ParameterSetName = 'SpecificQuota', Mandatory = $true)]
        [Parameter(ParameterSetName = 'GetAllQuota', Mandatory = $true)]
        [Parameter(ParameterSetName = 'DeviceList', Mandatory = $true)]
        [ValidateSet("GetAllQuota", "DeviceList", "SpecificQuota")]
        [string]$RequestType,

        [Parameter(ParameterSetName = 'GetAllQuota', Mandatory = $true)]
        [string]$DeviceSerialNo,

        [Parameter(ParameterSetName = 'SpecificQuota', Mandatory = $true)]
        [hashtable]$params,

        [Parameter(ParameterSetName = 'SpecificQuota', Mandatory = $true)]
        [Parameter(ParameterSetName = 'GetAllQuota', Mandatory = $true)]
        [Parameter(ParameterSetName = 'DeviceList', Mandatory = $true)]
        [string]$EcoflowAccessKey,

        [Parameter(ParameterSetName = 'SpecificQuota', Mandatory = $true)]
        [Parameter(ParameterSetName = 'GetAllQuota', Mandatory = $true)]
        [Parameter(ParameterSetName = 'DeviceList', Mandatory = $true)]
        [string]$EcoflowSecretKey,

        [Parameter(ParameterSetName = 'SpecificQuota', Mandatory = $true)]
        [Parameter(ParameterSetName = 'GetAllQuota', Mandatory = $true)]
        [Parameter(ParameterSetName = 'DeviceList', Mandatory = $true)]
        [string]$EcoflowApiHost
    )

    $nonce = Get-Nonce
    $timestamp = Get-Timestamp

    # base URL for querying the HTTP API
    $baseUrl = "$EcoflowApiHost/iot-open/sign/device/"
    
    # Concatenate the base URL with the additional required path based on the RequestType
    $reqTarget = switch ($RequestType) {
        'GetAllQuota' { "quota/all?sn=$DeviceSerialNo" } # GET but needs the serial including and signing!
        'DeviceList' { 'list' } # GET but just needs the basic signing information.
        'SpecificQuota' { 'quota' } # POST but needs the body parameters flattening and then signing.
        Default {}
    }
    $url = $baseUrl + $reqTarget

    # If there are URL parameters (like in a GetAllQuota request, these must be included in the signing key)
    $urlParameters = $url -split "[?]" -like "*=*"

    # Here we format the signing string - we're not signing it, just formatting it. Part of that means flattening (Merge-Hashtable) the params, if included.
    # One or both of -params or -url_params will be $null, depending on the request type.
    $signingString = Format-SigningString -params (Merge-Hashtable $params) -url_params $urlParameters -EcoflowAccessKey $EcoflowAccessKey -nonce $nonce -timestamp $timestamp
    
    # Let's sign everything for the request.
    $sign = Get-Signature -stringToSign $signingString -access_key $EcoflowAccessKey -secret_key $EcoflowSecretKey -nonce $nonce -timestamp $timestamp

    $headers = @{
        "accessKey" = $EcoflowAccessKey
        "nonce"     = $nonce
        "timestamp" = $timestamp
        "sign"      = $sign
    }
    
    # Let's send the request to the API.
    try {
        # Send the request, depending on the type as either a POST or a GET. The headers are needed whatever type of request we're sending.
        if ($RequestType -in @('DeviceList', 'GetAllQuota')) {
            $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
        }
        else {
            # To send a POST request to this API, we must define the Content-Type header as...well...that --->
            $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body ($params | ConvertTo-Json) -ContentType 'application/json;charset=UTF-8' -StatusCodeVariable sc -ResponseHeadersVariable hdr
        }

        # Check for a successful response (HTTP 200 OK)
        if ($sc -ne 200) {
            throw "Request failed with status code $($sc): $($hdr | ConvertTo-Json -Depth 5)"
        }
        
        # If everything is successful, return the response
        return $response
    }
    catch {
        Write-Error "Failed to invoke REST method for RequestType '$RequestType': $_"
        return $null
    }
}
# Path to options.json file - this is the file that's placed/mapped/linked in to the running container.
$OPTIONS_FILE = '/data/options.json'
# Read and convert the JSON file to a PowerShell object - we'll use these to get data from the user for use later.
$OPTIONS = Get-Content $OPTIONS_FILE | ConvertFrom-Json

# If the user specifies, we can set the culture so dates and times look correct.
$LANGUAGESETTING = $OPTIONS.language
try {
    if ($LANGUAGESETTING) {
        $CultureInfo = [System.Globalization.CultureInfo]::GetCultureInfo($LANGUAGESETTING, $true)
    }
    else {
        $CultureInfo = [System.Globalization.CultureInfo]::InvariantCulture
    }
}
catch {
    $message = @"
Improper culture/language code ("$LANGUAGESETTING") specified.
To get a suitable culture/language code, use:
[System.Globalization.CultureInfo]::GetCultures([System.Globalization.CultureTypes]::AllCultures)
in a PowerShell session.
Using InvariantCulture instead.
"@
    Write-Error $message
    $CultureInfo = [System.Globalization.CultureInfo]::InvariantCulture
}
finally {
    [System.Threading.Thread]::CurrentThread.CurrentCulture = $CultureInfo
    [System.Threading.Thread]::CurrentThread.CurrentUICulture = $CultureInfo
}

# The $EF_API_HOST is provided in the Developer Portal @ https://developer-eu.ecoflow.com/us/document/generalInfo
$EF_API_HOST = $OPTIONS.efhost

# These are the AccessKey and SecretKey which you must generate @ https://developer-eu.ecoflow.com/us/security
$EF_ACCESS_KEY = $OPTIONS.accesskey
$EF_SECRET_KEY = $OPTIONS.secretkey

# Set the SHP Serial.
$SHP_SERIAL = $OPTIONS.shpserial

# Set the sensor names
$HASS_ENERGY_SENSOR_NAME = $OPTIONS.energysensor
$HASS_EPS_SENSOR_NAME = $OPTIONS.epssensor
$HASS_CHARGING_LIMIT_SENSOR_NAME = $OPTIONS.charginglimitsensor
$HASS_DISCHARGING_LIMIT_SENSOR_NAME = $OPTIONS.discharginglimitsensor

# Set the polling frequency
$POLLING_FREQUENCY = $OPTIONS.polling

# Get the logging state required.
$LOGGING = $OPTIONS.logging

# Define the Home Assistant API URL and the sensor name
$homeAssistantBaseUrl = "http://supervisor/core/api/states/"
$homeAssistantToken = $env:SUPERVISOR_TOKEN

$osRelease = Get-Content '/etc/os-release' | ConvertFrom-StringData

Write-Output '--------------------'
"$($PSStyle.Background.Black)Container OS Name: {0}$($PSStyle.Reset)" -f $osRelease.PRETTY_NAME
"$($PSStyle.Background.Black)Container OS Version: {0}$($PSStyle.Reset)" -f $osRelease.VERSION_ID
"$($PSStyle.Background.Black)PowerShell Version: {0} {1}$($PSStyle.Reset)" -f $PSVersionTable.PSEdition, $PSVersionTable.PSVersion
"$($PSStyle.Background.Black)PowerShell Platform: {0}$($PSStyle.Reset)" -f $PSVersionTable.Platform

"$($PSStyle.Foreground.Magenta){0}$($PSStyle.Reset)" -f "Warnings and errors will be output below...."
"$($PSStyle.Foreground.Magenta){0}$($PSStyle.Reset)" -f "Entering the loop..."
Write-Output '⬇️⬇️⬇️⬇️⬇️'

# Loop forever
while ($true) {
    
    # Define the parameters we send to the API, these will be flattened and then signed.
    $params = @{
        sn     = $SHP_SERIAL # We need to set this here because we aren't using the URL parameters (stuff after ? ie. "?name1=value1&name2=value2").
        params = @{
            quotas = @('backupLoadWatt.watth', 'mainsLoadWatt.watth', 'epsModeInfo.eps', 'backupChaDiscCfg.forceChargeHigh', 'backupChaDiscCfg.discLower')
        }
    }

    # Send the request with the parameters defined above.
    $ef_request = Get-HttpData -RequestType SpecificQuota -params $params -EcoflowAccessKey $EF_ACCESS_KEY -EcoflowSecretKey $EF_SECRET_KEY -EcoflowApiHost $EF_API_HOST
    if ($null -eq $ef_request) {
        throw 'Encountered an error calling the REST API. Sorry, probably dying...'
    }

    # We got a successful result from the API, let's send it to Home Assistant.
    if ($ef_request.code -eq '0') {

        # Prepare the ENERGY data to send to Home Assistant
        $energy_data = @{
            state      = 'OK' # This could be something else here.
            attributes = @{
                friendly_name  = "Smart Home Panel Energy Data"
                battery_usage  = $ef_request.data.'backupLoadWatt.watth'
                grid_usage     = ($ef_request.data.'mainsLoadWatt.watth')
                last_execution = [int](Get-Date -UFormat %s)
            }
        } | ConvertTo-Json -Depth 5

        # Send the ENERGY data to Home Assistant
        $ha_response = Invoke-RestMethod -Uri "$homeAssistantBaseUrl$HASS_ENERGY_SENSOR_NAME" -Method Post -Headers @{
            "Authorization" = "Bearer $homeAssistantToken"
            'Content-Type'  = 'application/json'
        } -Body $energy_data

        # Prepare the EPS data to send to Home Assistant
        $energy_data = @{
            state      = $ef_request.data.'epsModeInfo.eps' -eq $true ? 'ON' : 'OFF'
            attributes = @{
                friendly_name  = "Smart Home Panel EPS Status"
                eps_state      = $ef_request.data.'epsModeInfo.eps'
                last_execution = [int](Get-Date -UFormat %s)
            }
        } | ConvertTo-Json -Depth 5

        # Send the EPS state data to Home Assistant
        $ha_response = Invoke-RestMethod -Uri "$homeAssistantBaseUrl$HASS_EPS_SENSOR_NAME" -Method Post -Headers @{
            "Authorization" = "Bearer $homeAssistantToken"
            'Content-Type'  = 'application/json'
        } -Body $energy_data

        # Prepare the CHARGING LIMIT data to send to Home Assistant
        $charginglimit = @{
            state      = [int]$ef_request.data.'backupChaDiscCfg.forceChargeHigh' # This could be something else here.
            attributes = @{
                friendly_name  = "Smart Home Panel Charging Limit"
                last_execution = [int](Get-Date -UFormat %s)
            }
        } | ConvertTo-Json -Depth 5

        # Send the ENERGY data to Home Assistant
        $ha_response = Invoke-RestMethod -Uri "$homeAssistantBaseUrl$HASS_CHARGING_LIMIT_SENSOR_NAME" -Method Post -Headers @{
            "Authorization" = "Bearer $homeAssistantToken"
            'Content-Type'  = 'application/json'
        } -Body $charginglimit

        # Prepare the DISCHARGING LIMIT data to send to Home Assistant
        $discharginglimit = @{
            state      = [int]$ef_request.data.'backupChaDiscCfg.discLower' # This could be something else here.
            attributes = @{
                friendly_name  = "Smart Home Panel Discharging Limit"
                last_execution = [int](Get-Date -UFormat %s)
            }
        } | ConvertTo-Json -Depth 5

        # Send the ENERGY data to Home Assistant
        $ha_response = Invoke-RestMethod -Uri "$homeAssistantBaseUrl$HASS_DISCHARGING_LIMIT_SENSOR_NAME" -Method Post -Headers @{
            "Authorization" = "Bearer $homeAssistantToken"
            'Content-Type'  = 'application/json'
        } -Body $discharginglimit

        if ($LOGGING) {
            $utcDateTime = $ha_response.last_reported
            $utcDateTimeObj = [DateTime]::Parse($utcDateTime)
            Write-Output "Last HA Push: $utcDateTimeObj"
        }
    }
    else {
        Write-Output "Error from Ecoflow's REST API:", $response.message
    }

    # Either provided by the user as an environment variable or we default to 5 minutes.
    # This data doesn't change often enough to warrant anything more frequent.
    Start-Sleep -Seconds ($POLLING_FREQUENCY ? $POLLING_FREQUENCY : 300)
}
