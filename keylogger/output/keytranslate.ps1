function Convert-KeyToChar {
    param ($ascii, $API)

    $virtualKey = $API::MapVirtualKey($ascii, 3)
    $kbstate = New-Object -TypeName Byte[] -ArgumentList 256
    $null = $API::GetKeyboardState($kbstate)
    $mychar = New-Object -TypeName System.Text.StringBuilder
    $success = $API::ToUnicode($ascii, $virtualKey, $kbstate, $mychar, $mychar.Capacity, 0)

    if ($success) {
        return $mychar.ToString()
    } else {
        return $null
    }
}
