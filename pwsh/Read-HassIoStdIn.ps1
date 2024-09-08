# Now wait for on-demand script starts.
while ($true) {
    $fromHassIo = Read-Host

    $inputJSON = $fromHassIo | ConvertFrom-Json -ErrorAction Continue
    $scripts = $inputJSON.scripts

    $defaultScriptPath = '/share/pwsh/'

    $red = $PSStyle.Foreground.Red
    $reset = $PSStyle.Reset

    foreach ($script in $scripts) {
        $scriptPath = if ($script.path) { $script.path } else { $defaultScriptPath }
        $fullScriptPath = "{0}{1}" -f $scriptPath, $script.filename
    
        if (Test-Path $fullScriptPath) {    
            try {
                Write-Output "$($red)On demand:$($reset) Attempting to run $fullScriptPath..."
                Start-Process -FilePath 'pwsh' -ArgumentList "-File `"$fullScriptPath`""
            }
            catch {
                Write-Host "Error executing script: $_"
            }
        }
        else { 'No file named: {0}' -f $fullScriptPath }
    }
    Start-Sleep -Seconds 1
}