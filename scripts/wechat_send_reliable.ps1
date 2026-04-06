[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Contact,
    
    [Parameter(Mandatory=$true)]
    [string]$Message,

    [string]$WeChatExe = 'C:\Program Files\Tencent\WeChat\WeChat.exe'
)

$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms

function Send-Keys-Safe {
    param([string]$Keys, [int]$DelayMs = 300)
    [System.Windows.Forms.SendKeys]::SendWait($Keys)
    Start-Sleep -Milliseconds $DelayMs
}

function Get-WeChatWindow {
    $proc = Get-Process -Name Weixin -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -eq '微信' } | Select-Object -First 1
    if ($null -eq $proc) {
        throw "WeChat window not found"
    }
    return $proc
}

function Enter-WeChatSearch {
    Send-Keys-Safe '^{f}' 300
}

function Search-Contact {
    param([string]$Name)
    [System.Windows.Forms.Clipboard]::SetText($Name)
    Start-Sleep -Milliseconds 200
    Send-Keys-Safe '^v' 300
    Send-Keys-Safe '{ENTER}' 500
}

function Send-Message {
    param([string]$Text)
    [System.Windows.Forms.Clipboard]::SetText($Text)
    Start-Sleep -Milliseconds 200
    Send-Keys-Safe '^v' 300
    Send-Keys-Safe '{ENTER}' 300
}

try {
    $wechat = Get-WeChatWindow
    $hwnd = $wechat.MainWindowHandle
    
    Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);' -Name WinAPI -Namespace StdCall -PassThru
    [StdCall.WinAPI]::SetForegroundWindow($hwnd) | Out-Null
    Start-Sleep -Milliseconds 500

    Enter-WeChatSearch
    Search-Contact -Name $Contact
    Send-Message -Text $Message

    Write-Output "OK: Message sent to $Contact"
    exit 0
} catch {
    Write-Error "Failed: $_"
    exit 1
}
