# Now wait for on-demand script starts.
while ($true) {
    $filenames = Read-Host
    Write-Output $filenames -NoEnumerate

    $files = $filenames | ConvertFrom-Json
    $files

    $defaultScriptPath = '/share/pwsh/'

    foreach ($script in $files.filenames) {
        $scriptPath = "{0}{1}" -f $defaultScriptPath, $script
    
        if (Test-Path $scriptPath) {    
            try {
                Start-Process -FilePath 'pwsh' -ArgumentList "-File `"$scriptPath`""
            }
            catch {
                Write-Host "Error executing command: $_"
            }
        }
        else { 'No file named: {0}' -f $scriptPath }
    }
    Start-Sleep -Seconds 5
}