# --- CONFIGURATION ---
$AdapterName = "VPN Connection Name"  # <--- REPLACE with your interface name
$TargetHost  = "2606:4700:4700::1111" # Cloudflare IPv6 DNS (Good for v6 latency test)
# Fallback to Google IPv4 if v6 fails:
$TargetHostv4 = "8.8.8.8" 

Clear-Host
Write-Host "Monitoring $AdapterName for dual-stack connectivity..." -ForegroundColor Cyan

# 1. WAIT FOR CONNECTION
Do {
    $status = Get-NetAdapter -Name $AdapterName -ErrorAction SilentlyContinue
    if ($status.Status -ne "Up") {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 1
    }
} Until ($status.Status -eq "Up")

Write-Host "`nInterface Up! Negotiating IP addresses..." -ForegroundColor Green
Start-Sleep -Seconds 4 # Allow extra time for IPv6 Router Advertisement (RA)

# 2. FETCH CONFIGURATION
$ip4 = "N/A"
$ip6 = "N/A"
$gw  = "N/A"

try {
    # Get IPv4
    $v4Obj = Get-NetIPAddress -InterfaceAlias $AdapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($v4Obj) { $ip4 = $v4Obj.IPAddress }

    # Get IPv6 (Filter out fe80:: Link-Local addresses to find the Public/Global one)
    $v6Obj = Get-NetIPAddress -InterfaceAlias $AdapterName -AddressFamily IPv6 -ErrorAction SilentlyContinue | Where-Object { $_.PrefixOrigin -ne 'LinkLocal' }
    if ($v6Obj) { $ip6 = $v6Obj.IPAddress }
    
    # Get Gateway
    $conf = Get-NetIPConfiguration -InterfaceAlias $AdapterName -ErrorAction SilentlyContinue
    if ($conf.IPv4DefaultGateway) { $gw = $conf.IPv4DefaultGateway.NextHop }
} catch {
    Write-Host "Error fetching IP details." -ForegroundColor Red
}

# 3. MEASURE LATENCY (Dual Mode)
Write-Host "Testing Latency..."
# Try IPv6 Ping first
if ($ip6 -ne "N/A") {
    $latObj = Test-Connection -ComputerName $TargetHost -Count 4 -ErrorAction SilentlyContinue
    $pingTarget = "v6"
} 
# Fallback to IPv4 Ping
if (-not $latObj -and $ip4 -ne "N/A") {
    $latObj = Test-Connection -ComputerName $TargetHostv4 -Count 4 -ErrorAction SilentlyContinue
    $pingTarget = "v4"
}

if ($latObj) {
    $avgLat = [math]::Round(($latObj.ResponseTime | Measure-Object -Average).Average, 0)
    $latMsg = "$avgLat ms ($pingTarget)"
} else {
    $latMsg = "Timeout"
}

# 4. CONSOLE OUTPUT (Full Detail)
Write-Host "------------------------------------------------" -ForegroundColor Gray
Write-Host "IPv4 Address : $ip4" -ForegroundColor White
Write-Host "IPv6 Address : $ip6" -ForegroundColor Yellow
Write-Host "Gateway      : $gw"
Write-Host "Latency      : $latMsg" -ForegroundColor Green
Write-Host "------------------------------------------------" -ForegroundColor Gray

# 5. SEND NOTIFICATION (Toast)
# ToastText04 template = 1 Header, 2 Lines of text
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText04)

$textNodes = $template.GetElementsByTagName("text")
$textNodes[0].AppendChild($template.CreateTextNode("$AdapterName Connected")) > $null
$textNodes[1].AppendChild($template.CreateTextNode("v4: $ip4")) > $null
# Note: IPv6 is long, so we put it on its own line. Latency is appended to the header or v4 line if needed, but here we prioritize IP visibility.
$textNodes[2].AppendChild($template.CreateTextNode("v6: $ip6")) > $null

$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("NetMonitor")
$notif = [Windows.UI.Notifications.ToastNotification]::new($template)
$notifier.Show($notif)
