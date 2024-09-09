# Now wait for on-demand script starts.
while ($true) {
    $fromHassIo = Read-Host

    $inputJSON = $fromHassIo | ConvertFrom-Json -ErrorAction Continue
    $scripts = $inputJSON.scripts
    
    $redfg = $PSStyle.Foreground.Red
    $reset = $PSStyle.Reset
    
    if (-not $scripts) {
        Write-Output @"
${redfg}###############################################
#             ! ON-DEMAND ERROR !             #
# The supplied "scripts" value is empty!      #
# Ensure you're sending a properly formatted  #
# list! eg.                                   #
# action: hassio.addon_stdin                  #
# data:                                       #
#   addon: $($env:HOSTNAME -Replace('-', '_'))                      #
#   input:                                    #
#     scripts:                                #
#       - filename: On-Demand.ps1             #
###############################################${reset}
"@
        Continue
    }

    $defaultScriptPath = '/share/pwsh/'

    foreach ($script in $scripts) {
        $scriptPath = if ($script.path) { $script.path } else { $defaultScriptPath }
        $fullScriptPath = Join-Path $scriptPath $script.filename
    
        if (Test-Path $fullScriptPath) {    
            try {
                Write-Output "$($redfg)ON-DEMAND:$($reset) Attempting to run $fullScriptPath..."
                Start-Process -FilePath 'pwsh' -ArgumentList "-File `"$fullScriptPath`""
            }
            catch {
                Write-Error "Error executing script: $_" -ErrorAction Continue
            }
        }
        else { 'No file named: {0}' -f $fullScriptPath }
    }
    Start-Sleep -Seconds 1
}