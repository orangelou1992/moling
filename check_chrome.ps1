Get-Process -Name chrome | ForEach-Object {
    $id = $_.Id
    $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$id").CommandLine
    [PSCustomObject]@{Id=$id; CommandLine=$cmd}
} | Format-Table -AutoSize
