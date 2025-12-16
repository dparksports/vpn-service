# --- CONFIGURATION ---
$AdapterName = "VPN Connection Name" # <--- UPDATE THIS
$TargetHost  = "8.8.8.8"

Clear-Host
Write-Host "Monitoring $AdapterName..." -ForegroundColor Cyan

# 1. WAIT FOR CONNECTION
Do {
    $status = Get-NetAdapter -Name $AdapterName -ErrorAction SilentlyContinue
    if ($status.Status -ne "Up") { Write-Host "." -NoNewline; Start-Sleep -Seconds 1 }
} Until ($status.Status -eq "Up")

Write-Host "`nConnected! Analyzing link parameters..." -ForegroundColor Green
Start-Sleep -Seconds 3

# 2. FETCH IP & CONFIGURATION
try {
    # Get Adapter Object for MTU
    $adapterObj = Get-NetAdapter -Name $AdapterName
    $mtu = $adapterObj.MtuSize

    # Get IPv4 & IPv6
    $ip4 = (Get-NetIPAddress -InterfaceAlias $AdapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
    $ip6 = (Get-NetIPAddress -InterfaceAlias $AdapterName -AddressFamily IPv6 -ErrorAction SilentlyContinue | Where-Object {$_.PrefixOrigin -ne 'LinkLocal'}).IPAddress
    
    # Get DNS Servers (Crucial for leak checking)
    $dns = (Get-DnsClientServerAddress -InterfaceAlias $AdapterName).ServerAddresses -join ", "
} catch {
    $ip4 = "Err"; $mtu = "Err"
}

# 3. CONNECTION QUALITY TEST (Latency + Packet Loss)
Write-Host "Testing Quality to $TargetHost..."
$test = Test-Connection -ComputerName $TargetHost -Count 5 -ErrorAction SilentlyContinue
if ($test) {
    $avgLat = [math]::Round(($test.ResponseTime | Measure-Object -Average).Average, 0)
    $lossCount = 5 - $test.Count
    $lossPct = ($lossCount / 5) * 100
} else {
    $avgLat = "TIMEOUT"
    $lossPct = "100"
}

# 4. CONSOLE REPORT
Write-Host "------------------------------------------------" -ForegroundColor Gray
Write-Host "IPv4       : $ip4"
Write-Host "IPv6       : $ip6"
Write-Host "MTU Size   : $mtu Bytes" -ForegroundColor Yellow
Write-Host "DNS Servers: $dns" -ForegroundColor Cyan
Write-Host "Latency    : $avgLat ms" -ForegroundColor Green
Write-Host "Pkt Loss   : $lossPct %" -ForegroundColor Red
Write-Host "------------------------------------------------" -ForegroundColor Gray

# 5. RICH NOTIFICATION
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText04)

$textNodes = $template.GetElementsByTagName("text")
$textNodes[0].AppendChild($template.CreateTextNode("$AdapterName Connected (MTU: $mtu)")) > $null
$textNodes[1].AppendChild($template.CreateTextNode("IP: $ip4")) > $null
$textNodes[2].AppendChild($template.CreateTextNode("Lat: $avgLat ms | Loss: $lossPct%")) > $null

$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("NetMonitor")
$notif = [Windows.UI.Notifications.ToastNotification]::new($template)
$notifier.Show($notif)
