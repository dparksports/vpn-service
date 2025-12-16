# --- CONFIGURATION ---
$AdapterName = "VPN Connection Name" # <--- UPDATE THIS
$TargetHost  = "8.8.8.8"             # Google DNS
$Timeout     = 1000                  # Ping timeout in milliseconds

# Setup
$pingSender = [System.Net.NetworkInformation.Ping]::new()
$lastState  = "Init"
$uimsg      = ""

Clear-Host
$host.UI.RawUI.WindowTitle = "Service Monitor: $AdapterName"
Write-Host "Monitoring Service Availability on [$AdapterName]..." -ForegroundColor Cyan

# --- NOTIFICATION FUNCTION ---
function Send-Notify ($Title, $Message, $Color) {
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
    $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
    $textNodes = $template.GetElementsByTagName("text")
    $textNodes[0].AppendChild($template.CreateTextNode($Title)) > $null
    $textNodes[1].AppendChild($template.CreateTextNode($Message)) > $null
    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("WanMonitor")
    $notifier.Show([Windows.UI.Notifications.ToastNotification]::new($template))
    
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Title - $Message" -ForegroundColor $Color
}

# --- MAIN LOOP ---
while ($true) {
    # 1. Check Interface Status
    $adapter = Get-NetAdapter -Name $AdapterName -ErrorAction SilentlyContinue
    
    if ($null -eq $adapter -or $adapter.Status -ne "Up") {
        $currentState = "Disconnected"
        $color = "Red"
    }
    else {
        # 2. Check Internet Reachability (Only if Interface is Up)
        try {
            $reply = $pingSender.Send($TargetHost, $Timeout)
            if ($reply.Status -eq "Success") {
                $currentState = "Online"
                $color = "Green"
                $latency = $reply.RoundtripTime
            }
            else {
                $currentState = "NoService" # Connected, but ping failed
                $color = "Yellow"
            }
        }
        catch {
            $currentState = "NoService"
            $color = "Yellow"
        }
    }

    # 3. Handle State Changes
    if ($currentState -ne $lastState) {
        switch ($currentState) {
            "Disconnected" { 
                Send-Notify "SERVICE LOST" "$AdapterName is down." "Red" 
            }
            "NoService" { 
                Send-Notify "NO INTERNET" "Connected to VPN, but cannot reach Internet." "Yellow" 
            }
            "Online" { 
                Send-Notify "SERVICE RESTORED" "Internet available ($latency ms)." "Green" 
            }
        }
        $lastState = $currentState
    }

    # 4. Heartbeat (Visual indicator that script is running)
    if ($currentState -eq "Online") { Write-Host "." -NoNewline -ForegroundColor DarkGray }
    elseif ($currentState -eq "NoService") { Write-Host "!" -NoNewline -ForegroundColor Yellow }
    else { Write-Host "x" -NoNewline -ForegroundColor Red }

    Start-Sleep -Seconds 1
}
