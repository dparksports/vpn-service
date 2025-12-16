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

# 2. FETCH IP, MTU & DNS
try {
    # Get Adapter Object for MTU
    $adapterObj = Get-NetAdapter -Name $AdapterName
    $mtu = $adapterObj.MtuSize

    # Get IPv4
    $ip4 = (Get-NetIPAddress -InterfaceAlias $AdapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
    
    # Get IPv6 (Global Only)
    $ip6 = (Get-NetIPAddress -InterfaceAlias $AdapterName -AddressFamily IPv6 -ErrorAction SilentlyContinue | Where-Object {$_.PrefixOrigin -ne 'LinkLocal'}).IPAddress
    
    # Get DNS Servers (Filter for IPv4 to save space, or remove filter to see all)
    $dnsObj = Get-DnsClientServerAddress -InterfaceAlias $AdapterName
    $dns = $dnsObj.ServerAddresses -join ", "
    # Grab just the first DNS server for the small notification popup
    $shortDns = $dnsObj.ServerAddresses[0]
} catch {
    $ip4 = "Err"; $mtu = "Err"; $dns = "Err"
}

# 3. CONNECTION QUALITY TEST
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

# 4. CONSOLE REPORT (Detailed)
Write-Host "------------------------------------------------" -ForegroundColor Gray
Write-Host "IPv4       : $ip4"
Write-Host "IPv6       : $ip6"
Write-Host "DNS Server : $dns" -ForegroundColor Cyan
Write-Host "MTU Size   : $mtu Bytes" -ForegroundColor Yellow
Write-Host "Latency    : $avgLat ms" -ForegroundColor Green
Write-Host "Pkt Loss   : $lossPct %" -ForegroundColor Red
Write-Host "------------------------------------------------" -ForegroundColor Gray

# 5. RICH NOTIFICATION (Compact)
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText04)

$textNodes = $template.GetElementsByTagName("text")
# Line 1: Title
$textNodes[0].AppendChild($template.CreateTextNode("$AdapterName Connected")) > $null
# Line 2: IP and DNS (Combined for space)
$textNodes[1].AppendChild($template.CreateTextNode("IP: $ip4 | DNS: $shortDns")) > $null
# Line 3: Latency and MTU
$textNodes[2].AppendChild($template.CreateTextNode("Lat: $avgLat ms | MTU: $mtu")) > $null

$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("NetMonitor")
$notif = [Windows.UI.Notifications.ToastNotification]::new($template)
$notifier.Show($notif)
