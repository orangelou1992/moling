[Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
param(
    [string]$Contact = "晓楼",
    [string]$Message = "墨瞳测试"
)

Add-Type -AssemblyName System.Windows.Forms

function SendKeysSafe {
    param([string]$keys)
    [System.Windows.Forms.SendKeys]::SendWait($keys)
    Start-Sleep -Milliseconds 300
}

$proc = Get-Process Weixin | Where-Object { $_.MainWindowTitle -eq '微信' } | Select-Object -First 1
if (-not $proc) {
    Write-Output "ERROR: WeChat window not found"
    exit 1
}

Write-Output "Activating WeChat..."
[void] [System.Windows.Forms.Application]::Yield
Start-Sleep -Milliseconds 500

# Step 1: Open search
Write-Output "Opening search (Ctrl+F)..."
SendKeysSafe '^{f}'

# Step 2: Search for contact
Write-Output "Searching for: $Contact"
[System.Windows.Forms.Clipboard]::SetText($Contact)
Start-Sleep -Milliseconds 200
SendKeysSafe '^v'
Start-Sleep -Milliseconds 300

# Step 3: Open chat
Write-Output "Opening chat..."
SendKeysSafe '{ENTER}'
Start-Sleep -Milliseconds 500

# Step 4: Type message
Write-Output "Typing message: $Message"
[System.Windows.Forms.Clipboard]::SetText($Message)
Start-Sleep -Milliseconds 200
SendKeysSafe '^v'
Start-Sleep -Milliseconds 300

# Step 5: Send
Write-Output "Sending..."
SendKeysSafe '{ENTER}'

Write-Output "OK: Message sent to $Contact"
