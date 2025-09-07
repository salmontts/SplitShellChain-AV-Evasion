if ($bindCondition) {
    $listener = [System.Net.Sockets.TcpListener]$Port
    $listener.start()
    $client = $listener.AcceptTcpClient()
}
# nie dotykac to moj projekt
. .\line016.ps1
Start-Sleep -Milliseconds 300
