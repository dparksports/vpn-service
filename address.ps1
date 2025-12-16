# Configuration
$AdapterName = "VPN Connection Name" # <--- UPDATE THIS to your VPN name
$TargetHost = "8.8.8.8"

Write-Host "Waiting for $AdapterName to connect..." -ForegroundColor Cyan

# 1. Wait for Connection
Do {
    $status = Get-NetAdapter -Name $AdapterName -ErrorAction SilentlyContinue
    if ($status.Status -ne "Up") {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 1
    }
} Until ($status.Status -eq "Up")

Write-Host "`nConnected! Gathering IP configuration..." -ForegroundColor Green
Start-Sleep -Seconds 3 # Give DHCP a moment to finalize

# 2. Get IP Details
try {
    $ipInfo = Get-NetIPAddress -InterfaceAlias $AdapterName -AddressFamily IPv4 -ErrorAction Stop
    $myIP = $ipInfo.IPAddress
    
    # Try to get Gateway (VPNs sometimes don't have a standard gateway if split-tunneling)
    $config = Get-NetIPConfiguration -InterfaceAlias $AdapterName -ErrorAction SilentlyContinue
    $gateway = $config.IPv4DefaultGateway.NextHop
    if (-not $gateway) { $gateway = "Split-Tunnel / No Gateway" }
}
catch {
    $myIP = "Unknown"
    $gateway = "Unknown"
}

# 3. Measure Latency
Write-Host "Measuring latency to $TargetHost..."
$ping = Test-Connection -ComputerName $TargetHost -Count 4
$avgLatency = [math]::Round(($ping.ResponseTime | Measure-Object -Average).Average, 0)

# 4. Build Notification Text
$title = "VPN Connected: $AdapterName"
$msg = "IP: $myIP`nGateway: $gateway`nLatency: $avgLatency ms"

# 5. Send Notification
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText04) # Text04 allows 3 lines of text
$textNodes = $template.GetElementsByTagName("text")
$textNodes[0].AppendChild($template.CreateTextNode($title)) > $null
$textNodes[1].AppendChild($template.CreateTextNode("IP: $myIP")) > $null
$textNodes[2].AppendChild($template.CreateTextNode("Latency: $avgLatency ms")) > $null

$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Network Monitor")
$notification = [Windows.UI.Notifications.ToastNotification]::new($template)
$notifier.Show($notification)

Write-Host "Notification Sent."
Write-Host "-------------------"
Write-Host $msg -ForegroundColor Yellow
