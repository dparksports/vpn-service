# --- CONFIGURATION ---
$AdapterName = "VPN Connection Name"  # <--- UPDATE THIS
$TargetHost  = "8.8.8.8"
$CheckInterval = 1 # Seconds between checks

Clear-Host
$host.UI.RawUI.WindowTitle = "Active Network Monitor: $AdapterName"
Write-Host "Monitoring $AdapterName for state changes..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop." -ForegroundColor Gray

# Initialize State Variables
$lastStatus = "Initial"
$lastIP     = "Initial"
$lastDNS    = "Initial"

# --- HELPER FUNCTION: SEND NOTIFICATION ---
function Send-Toast {
    param ($Title, $Line1, $Line2)
    $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText04)
    $textNodes = $template.GetElementsByTagName("text")
    $textNodes[0].AppendChild($template.CreateTextNode($Title)) > $null
    $textNodes[1].AppendChild($template.CreateTextNode($Line1)) > $null
    $textNodes[2].AppendChild($template.CreateTextNode($Line2)) > $null
    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("NetWatcher")
    $notifier.Show([Windows.UI.Notifications.ToastNotification]::new($template))
}

# --- MAIN LOOP ---
while ($true) {
    # 1. FETCH CURRENT STATUS
    $adapter = Get-NetAdapter -Name $AdapterName -ErrorAction SilentlyContinue
    
    if ($adapter.Status -eq "Up") {
        $currentStatus = "Up"
        
        # Fetch Details
        $ip4 = (Get-NetIPAddress -InterfaceAlias $AdapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
        $dnsObj = Get-DnsClientServerAddress -InterfaceAlias $AdapterName
        $dns = $dnsObj.ServerAddresses -join ", "
        
        # Detect Changes (Logic: If Status OR IP OR DNS is different from last loop)
        if ($currentStatus -ne $lastStatus -or $ip4 -ne $lastIP -or $dns -ne $lastDNS) {
            
            # Change Detected -> Measure Latency NOW
            Write-Host "`n[CHANGE DETECTED] $(Get-Date -Format 'HH:mm:ss') - Re-scanning..." -ForegroundColor Yellow
            $ping = Test-Connection -ComputerName $TargetHost -Count 2 -ErrorAction SilentlyContinue
            
            if ($ping) {
                $lat = [math]::Round(($ping.ResponseTime | Measure-Object -Average).Average, 0)
                $latMsg = "$lat ms"
            } else {
                $latMsg = "Timeout"
            }

            # Print to Console
            Write-Host "  STATUS : Connected" -ForegroundColor Green
            Write-Host "  IP     : $ip4"
            Write-Host "  DNS    : $dns"
            Write-Host "  LATENCY: $latMsg"
            
            # Send Notification
            Send-Toast -Title "Network Change: $AdapterName" -Line1 "IP: $ip4 ($latMsg)" -Line2 "DNS: $dns"
            
            # Update State
            $lastStatus = "Up"
            $lastIP     = $ip4
            $lastDNS    = $dns
        }
    }
    else {
        # Adapter is DOWN
        $currentStatus = "Down"
        
        if ($currentStatus -ne $lastStatus) {
            Write-Host "`n[CHANGE DETECTED] $(Get-Date -Format 'HH:mm:ss') - Connection LOST" -ForegroundColor Red
            Send-Toast -Title "Network Alert" -Line1 "$AdapterName Disconnected" -Line2 "Waiting for reconnection..."
            
            # Update State
            $lastStatus = "Down"
            $lastIP     = "0.0.0.0"
            $lastDNS    = "None"
        }
    }

    # Heartbeat (Optional: Remove if you want a silent console)
    Write-Host "." -NoNewline -ForegroundColor DarkGray
    
    Start-Sleep -Seconds $CheckInterval
}
