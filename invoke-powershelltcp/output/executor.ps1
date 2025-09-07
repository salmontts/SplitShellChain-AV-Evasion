function Execute-Command {
    param ($data)

    $commandError = $null
    try {
        $result = Invoke-Expression -Command $data 2>&1 | Out-String
    } catch {
        $commandError = $_
        Write-Warning "Something went wrong with execution of command on the target."
        Write-Error $commandError
        $result = $commandError | Out-String
    }

    return $result
}
