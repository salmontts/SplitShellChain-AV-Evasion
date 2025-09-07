function Receive-Command {
    param ($stream, $bytes)
    $i = $stream.Read($bytes, 0, $bytes.Length)
    if ($i -eq 0) { return $null }

    $encoding = New-Object -TypeName System.Text.ASCIIEncoding
    return ,@($encoding.GetString($bytes, 0, $i), $i)
}
