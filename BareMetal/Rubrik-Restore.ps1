<#
.SYNOPSIS
    Rubrik Bare-Metal Recovery (BMR) Automation Assistant for WinPE
.DESCRIPTION
    Streamlines Steps 21 through 32 of the official Rubrik BMR recovery guide
    ("Restoring a volume group using BMR"):
      1. Parses the 'Restore Script Path' copied from Rubrik Console (Live Mount "No Host").
      2. Verifies WireGuard tunnel connectivity and port 445 on the Rubrik cluster node.
      3. Establishes the authenticated SMB session and maps drive Z: per Step 28.
      4. Detects/prompts for partition layout (-BcdbootAll $true support).
      5. Executes RubrikBMR.ps1 directly via UNC path with ExecutionPolicy Bypass.
      6. Handles clean post-restore drive unmapping.
#>

[CmdletBinding()]
param()

$Host.UI.RawUI.WindowTitle = "Rubrik Bare-Metal Recovery Assistant"

Clear-Host
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "               Rubrik Bare-Metal Recovery (BMR) Assistant                      " -ForegroundColor White
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This assistant guides you through Steps 24-32 of the official Rubrik BMR process." -ForegroundColor Gray
Write-Host "Ensure you have completed the 'Live Mount (No Host)' step in the Rubrik Console." -ForegroundColor Gray
Write-Host ""

# -----------------------------------------------------------------------------
# Step 1: Input & Parse Restore Script Path (Rubrik Step 24-25)
# -----------------------------------------------------------------------------
Write-Host "[Step 1/3] Enter Restore Script Path from Rubrik Console" -ForegroundColor Yellow
Write-Host "In RSC/CDM: Windows Volumes -> Live Mounts -> Copy 'Restore Script Path'" -ForegroundColor Gray
Write-Host "Example: \\x.x.x.x\LiveMount_83f912ab\with_layout\RubrikBMR.ps1" -ForegroundColor DarkGray
Write-Host ""

$rawInput = ""
while ([string]::IsNullOrWhiteSpace($rawInput)) {
    $rawInput = Read-Host "Paste Restore Script Path"
    if ($rawInput) {
        $rawInput = $rawInput.Trim().Trim('"').Trim("'")
    }
}

# Regex to parse server, share, and optional script subpath
if ($rawInput -match '^\\\\([^\\]+)\\([^\\]+)(?:\\(.*))?$') {
    $ServerNode = $matches[1]
    $ShareName  = $matches[2]
    $SubPath    = $matches[3]
    $ShareRoot  = "\\$ServerNode\$ShareName"
    
    if ($SubPath -and $SubPath.ToLower().EndsWith("rubrikbmr.ps1")) {
        $ScriptPath = $rawInput
    } else {
        $ScriptPath = "$ShareRoot\with_layout\RubrikBMR.ps1"
    }
} else {
    Write-Host "[-] Invalid UNC path format: $rawInput" -ForegroundColor Red
    Write-Host "    Expected format: \\<Node_IP>\<Share_Name>\with_layout\RubrikBMR.ps1" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "  [i] Rubrik Cluster Node IP : $ServerNode" -ForegroundColor Cyan
Write-Host "  [i] SMB Share Path         : $ShareRoot" -ForegroundColor Cyan
Write-Host "  [i] UNC Script Path        : $ScriptPath" -ForegroundColor Cyan
Write-Host ""

# -----------------------------------------------------------------------------
# Step 2: WireGuard Tunnel Pre-flight Check (Rubrik Step 21)
# -----------------------------------------------------------------------------
Write-Host "Verifying WireGuard tunnel connectivity to Rubrik Node ($ServerNode)..." -NoNewline
$ping = Test-Connection -ComputerName $ServerNode -Count 2 -Quiet -ErrorAction SilentlyContinue
if ($ping) {
    Write-Host " [OK (Ping)]" -ForegroundColor Green
} else {
    Write-Host " [Ping Timed Out]" -ForegroundColor Yellow
    Write-Host "  Testing TCP port 445 (SMB) across tunnel..." -NoNewline
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $iar = $tcp.BeginConnect($ServerNode, 445, $null, $null)
        $wait = $iar.AsyncWaitHandle.WaitOne(2000, $false)
        if ($wait) {
            $tcp.EndConnect($iar)
            $tcp.Close()
            Write-Host " [OK (Port 445 Open)]" -ForegroundColor Green
        } else {
            $tcp.Close()
            Write-Host " [FAILED]" -ForegroundColor Red
            Write-Host "[-] Could not reach $ServerNode:445 over the WireGuard tunnel." -ForegroundColor Red
            Write-Host "    Verify the WireGuard tunnel is running ('wg show')." -ForegroundColor Yellow
            $cont = Read-Host "Do you want to continue anyway? (Y/N) [N]"
            if ($cont -ne "Y" -and $cont -ne "y") { exit 1 }
        }
    } catch {
        Write-Host " [FAILED]" -ForegroundColor Red
        Write-Host "[-] Error testing SMB port: $_" -ForegroundColor Red
    }
}
Write-Host ""

# -----------------------------------------------------------------------------
# Step 3: Map Drive Z: & Establish Credentials (Rubrik Step 28-29)
# -----------------------------------------------------------------------------
Write-Host "[Step 2/3] Authenticate SMB Session & Map Drive Z: (Rubrik Step 28)" -ForegroundColor Yellow
Write-Host "Enter the temporary SMB credentials configured in the Live Mount wizard." -ForegroundColor Gray
Write-Host ""

# Clear existing Z: mapping if present
if (Get-PSDrive -Name Z -ErrorAction SilentlyContinue) {
    Write-Host "  [i] Re-aligning existing drive Z: mapping..." -ForegroundColor DarkGray
    & net.exe use Z: /delete /y | Out-Null
}

$authSuccess = $false
while (-not $authSuccess) {
    $Username = Read-Host "  Enter SMB Username (e.g. admin or restore)"
    if ([string]::IsNullOrWhiteSpace($Username)) {
        Write-Host "  [-] Username cannot be blank." -ForegroundColor Red
        continue
    }

    $PasswordSecure = Read-Host "  Enter SMB Password" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PasswordSecure)
    $PasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

    Write-Host ""
    Write-Host "  Executing: net use z: $ShareRoot /user:$Username ********" -ForegroundColor DarkGray
    
    # Use net.exe directly to match Rubrik Step 28
    $netOutput = & net.exe use z: $ShareRoot "/user:$Username" "$PasswordPlain" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [+] Drive Z: successfully mapped to $ShareRoot" -ForegroundColor Green
        Write-Host "  [+] Authenticated SMB session established in Windows kernel." -ForegroundColor Green
        $authSuccess = $true
    } else {
        Write-Host "  [-] Authentication or Mount Failed:" -ForegroundColor Red
        $netOutput | ForEach-Object { Write-Host "      $_" -ForegroundColor Red }
        Write-Host ""
        $retry = Read-Host "  Retry credentials? (Y/N) [Y]"
        if ($retry -and ($retry -ne "Y" -and $retry -ne "y")) {
            Write-Host "[-] Aborting restore." -ForegroundColor Yellow
            exit 1
        }
    }
}

Write-Host ""
# Verify Script is Accessible on both Z: and UNC
Write-Host "Verifying Rubrik recovery script availability..." -NoNewline
if (Test-Path $ScriptPath) {
    Write-Host " [OK (Accessible via UNC)]" -ForegroundColor Green
} elseif (Test-Path "Z:\with_layout\RubrikBMR.ps1") {
    Write-Host " [OK (Found on Z:\with_layout\RubrikBMR.ps1)]" -ForegroundColor Green
    $ScriptPath = "$ShareRoot\with_layout\RubrikBMR.ps1"
} else {
    Write-Host " [WARNING]" -ForegroundColor Yellow
    Write-Host "[!] Could not locate RubrikBMR.ps1 at $ScriptPath" -ForegroundColor Yellow
    Write-Host "    Listing contents of Z:\ :" -ForegroundColor DarkGray
    Get-ChildItem -Path Z:\ -ErrorAction SilentlyContinue | Select-Object Name | Out-String | Write-Host -ForegroundColor DarkGray
}

Write-Host ""

# -----------------------------------------------------------------------------
# Step 4: Partition Layout & Script Arguments (Rubrik Step 29)
# -----------------------------------------------------------------------------
Write-Host "[Step 3/3] Target Partition Configuration (Rubrik Step 29)" -ForegroundColor Yellow
Write-Host "Does the target machine have a dedicated System-Reserved partition?" -ForegroundColor White
Write-Host "  [1] Yes - Standard partition layout (Default)" -ForegroundColor White
Write-Host "  [2] No  - No System-Reserved partition (Appends -BcdbootAll `$true)" -ForegroundColor White
Write-Host ""
$partChoice = Read-Host "Select option [1]"
if ([string]::IsNullOrWhiteSpace($partChoice)) { $partChoice = "1" }

$scriptArgs = @()
if ($partChoice -eq "2" -or $partChoice.ToUpper() -eq "N") {
    $scriptArgs += "-BcdbootAll"
    $scriptArgs += "`$true"
    $argDisplay = "-BcdbootAll `$true"
} else {
    $argDisplay = "(Standard / Default)"
}

Write-Host ""
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "READY TO COMMENCE RUBRIK BARE-METAL RESTORE" -ForegroundColor Green
Write-Host "  Script Path : $ScriptPath" -ForegroundColor White
Write-Host "  Parameters  : $argDisplay" -ForegroundColor White
Write-Host "  SMB Session : Authenticated via Z: ($ShareRoot)" -ForegroundColor White
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Rubrik's restoration engine will now take over this console window." -ForegroundColor Yellow
Write-Host "When the restore finishes, Rubrik will prompt: 'Enter Y to reboot'." -ForegroundColor Yellow
Write-Host "Ensure the WinPE ISO or USB boot media is unplugged before confirming the reboot." -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Press [Enter] to start restore (or Ctrl+C to cancel)"

# -----------------------------------------------------------------------------
# Step 5: Execute Rubrik Recovery Script (Rubrik Step 30)
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "Executing RubrikBMR.ps1 directly from UNC per official documentation..." -ForegroundColor Cyan
Write-Host ""

try {
    if ($scriptArgs.Count -gt 0) {
        & "$ScriptPath" -BcdbootAll $true
    } else {
        & "$ScriptPath"
    }
} catch {
    Write-Host "[-] Error invoking RubrikBMR.ps1: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "Rubrik Restore Session Finished." -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan
$cleanDrive = Read-Host "Would you like to disconnect drive Z: now? (Y/N) [Y]"
if ([string]::IsNullOrWhiteSpace($cleanDrive) -or $cleanDrive -eq "Y" -or $cleanDrive -eq "y") {
    & net.exe use Z: /delete /y | Out-Null
    Write-Host "[+] Drive Z: unmounted cleanly." -ForegroundColor Green
}
