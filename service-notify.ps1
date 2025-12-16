# Configuration: The name of your WAN Miniport or VPN adapter
$AdapterName = "VPN Connection Name" # <--- CHANGE THIS to your exact adapter name
$TargetHost = "8.8.8.8"               # Google DNS (good for latency testing)

Write-Host "Monitoring for $AdapterName..." -ForegroundColor Cyan

# 1. Loop until the adapter is "Up"
Do {
    $status = Get-NetAdapter -Name $AdapterName -ErrorAction SilentlyContinue
    if ($status.Status -ne "Up") {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 1
    }
} Until ($status.Status -eq "Up")

# 2. Connection detected: Wait 2s for routes to stabilize
Write-Host "`n$AdapterName is connected! Measuring latency..." -ForegroundColor Green
Start-Sleep -Seconds 2

# 3. Measure Latency
$ping = Test-Connection -ComputerName $TargetHost -Count 4
$avgLatency = ($ping.ResponseTime | Measure-Object -Average).Average

# 4. Send Desktop Notification
$notificationTitle = "VPN Service Available"
$notificationText = "Connection established. Average Latency: $avgLatency ms"

# Create the popup notification
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
$textNodes = $template.GetElementsByTagName("text")
$textNodes[0].AppendChild($template.CreateTextNode($notificationTitle)) > $null
$textNodes[1].AppendChild($template.CreateTextNode($notificationText)) > $null
$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Network Monitor")
$notification = [Windows.UI.Notifications.ToastNotification]::new($template)
$notifier.Show($notification)

Write-Host "Done. $notificationText"
