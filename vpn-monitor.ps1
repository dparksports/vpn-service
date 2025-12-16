# --- CONFIGURATION ---
$AdapterName = "VPN Connection Name"  # <--- Name of your WAN Miniport adapter
$PeerIP      = "10.0.0.1"             # <--- The IP of the remote peer/gateway you want to check

# Setup
$lastState = "Init"
Clear-Host
$host.UI.RawUI.WindowTitle = "Peer Link Monitor: $PeerIP"
Write-Host "Monitoring P2P Link to $PeerIP on interface [$AdapterName]..." -ForegroundColor Cyan

# --- NOTIFICATION FUNCTION ---
function Send-Notify ($Title, $Message, $Color) {
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
    $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
    $textNodes = $template.GetElementsByTagName("text")
    $textNodes[0].AppendChild($template.CreateTextNode($Title)) > $null
    $textNodes[1].AppendChild($template.CreateTextNode($Message)) > $null
    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("PeerMonitor")
    $notifier.Show([Windows.UI.Notifications.ToastNotification]::new($template))
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Title - $Message" -ForegroundColor $Color
}

# --- MAIN LOOP ---
while ($true) {
    # 1. Get the Source IP of our Adapter
    # We need this to force the ping through the tunnel
    $sourceIPObj = Get-NetIPAddress -InterfaceAlias $AdapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue
    
    if ($null -eq $sourceIPObj) {
        $currentState = "InterfaceDown"
    }
    else {
        $myIP = $sourceIPObj.IPAddress
        
        # 2. Ping the Peer *FROM* our specific Adapter IP
        # This confirms the tunnel is actually carrying traffic
        try {
            # -Source is the key: It binds the request to the VPN interface
            $test = Test-Connection -ComputerName $PeerIP -Source $myIP -Count 1 -ErrorAction SilentlyContinue
            
            if ($test) {
                $currentState = "PeerReachable"
                $latency = $test.ResponseTime
            }
            else {
                $currentState = "PeerUnreachable"
            }
        }
        catch {
            $currentState = "PeerUnreachable"
        }
    }

    # 3. Handle State Changes
    if ($currentState -ne $lastState) {
        switch ($currentState) {
            "InterfaceDown" { 
                Send-Notify "LINK DOWN" "Interface $AdapterName is disconnected." "Red" 
            }
            "PeerUnreachable" { 
                Send-Notify "PEER LOST" "Interface is Up, but $PeerIP is unreachable." "Yellow" 
            }
            "PeerReachable" { 
                Send-Notify "LINK ESTABLISHED" "Peer $PeerIP is responding ($latency ms)." "Green" 
            }
        }
        $lastState = $currentState
    }

    # 4. Visual Heartbeat
    if ($currentState -eq "PeerReachable") { Write-Host "." -NoNewline -ForegroundColor DarkGray }
    elseif ($currentState -eq "PeerUnreachable") { Write-Host "!" -NoNewline -ForegroundColor Yellow }
    else { Write-Host "x" -NoNewline -ForegroundColor Red }

    Start-Sleep -Seconds 1
}
