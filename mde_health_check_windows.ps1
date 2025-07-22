# Microsoft Defender for Endpoint Check Script - Simple Version
param(
    [switch]$Help,
    [switch]$BehaviorTest
)

# Check admin privileges
function Test-Admin {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($user)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Output function
function Write-Status {
    param($Level, $Message)
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = @{OK="Green"; WARNING="Yellow"; ERROR="Red"; INFO="Cyan"}[$Level]
    Write-Host "[$time] [$Level] $Message" -ForegroundColor $color
    Add-Content -Path $global:LogFile -Value "[$time] [$Level] $Message"
}

# Show help
if ($Help) {
    Write-Host "Usage: .\mde_check_simple.ps1 [-Help] [-BehaviorTest]"
    Write-Host "  -Help         Show this help"
    Write-Host "  -BehaviorTest Run behavior monitoring test"
    exit 0
}

# Check admin
if (-not (Test-Admin)) {
    Write-Host "ERROR: Run as Administrator" -ForegroundColor Red
    exit 1
}

# Setup log file
$global:LogFile = ".\mde_check_result_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
Write-Host "Microsoft Defender for Endpoint Check" -ForegroundColor Green
Write-Status "INFO" "Starting check..."

# Check if Defender module exists
try {
    Import-Module Defender -ErrorAction Stop
    Write-Status "OK" "Defender module loaded"
} catch {
    Write-Status "ERROR" "Defender module not available"
    exit 1
}

# 1. Real-time Protection Check
Write-Host "`n=== Real-time Protection Check ===" -ForegroundColor Blue
try {
    $status = Get-MpComputerStatus
    if ($status.RealTimeProtectionEnabled) {
        Write-Status "OK" "Real-time Protection: Enabled"
    } else {
        Write-Status "ERROR" "Real-time Protection: Disabled"
    }
    
    if ($status.AntivirusEnabled) {
        Write-Status "OK" "Antivirus Engine: Enabled"
    } else {
        Write-Status "ERROR" "Antivirus Engine: Disabled"
    }
} catch {
    Write-Status "ERROR" "Failed to check real-time protection: $($_.Exception.Message)"
}

# 2. Cloud Protection Check
Write-Host "`n=== Cloud Protection Check ===" -ForegroundColor Blue
try {
    $pref = Get-MpPreference
    
    switch ($pref.MAPSReporting) {
        0 { Write-Status "ERROR" "MAPS Reporting: Disabled" }
        1 { Write-Status "OK" "MAPS Reporting: Basic" }
        2 { Write-Status "OK" "MAPS Reporting: Advanced" }
        default { Write-Status "WARNING" "MAPS Reporting: Unknown ($($pref.MAPSReporting))" }
    }
    
    switch ($pref.SubmitSamplesConsent) {
        0 { Write-Status "WARNING" "Sample Submission: Always Prompt" }
        1 { Write-Status "OK" "Sample Submission: Send Safe Samples" }
        2 { Write-Status "WARNING" "Sample Submission: Never Send" }
        3 { Write-Status "OK" "Sample Submission: Send All Samples" }
        default { Write-Status "WARNING" "Sample Submission: Unknown ($($pref.SubmitSamplesConsent))" }
    }
} catch {
    Write-Status "ERROR" "Failed to check cloud protection: $($_.Exception.Message)"
}

# 3. Connectivity Check
Write-Host "`n=== Connectivity Check ===" -ForegroundColor Blue
try {
    $mpcmd = "$env:ProgramFiles\Windows Defender\MpCmdRun.exe"
    if (Test-Path $mpcmd) {
        Write-Status "OK" "MpCmdRun.exe found"
        
        $result = & $mpcmd -ValidateMapsConnection
        if ($LASTEXITCODE -eq 0) {
            Write-Status "OK" "MAPS Connectivity: Success"
        } else {
            Write-Status "ERROR" "MAPS Connectivity: Failed (Code: $LASTEXITCODE)"
        }
    } else {
        Write-Status "WARNING" "MpCmdRun.exe not found"
    }
} catch {
    Write-Status "ERROR" "Failed connectivity check: $($_.Exception.Message)"
}

# 4. Behavior Test (Optional)
if ($BehaviorTest) {
    Write-Host "`n=== Behavior Monitoring Test ===" -ForegroundColor Blue
    Write-Status "WARNING" "Running behavior test - may trigger alerts"
    
    try {
        $proc = Start-Process powershell -ArgumentList "-NoExit", "-Command", "powershell.exe hidden 12154dfe-61a5-4357-ba5a-efecc45c34c4" -PassThru -WindowStyle Hidden
        Start-Sleep 5
        
        if ($proc -and !$proc.HasExited) {
            $proc.Kill()
            Write-Status "WARNING" "Test process terminated manually"
        } else {
            Write-Status "OK" "Test process was blocked (good)"
        }
    } catch {
        Write-Status "ERROR" "Behavior test failed: $($_.Exception.Message)"
    }
}

# Summary
Write-Host "`n=== Summary ===" -ForegroundColor Blue
try {
    $status = Get-MpComputerStatus
    $pref = Get-MpPreference
    
    $score = 0
    $total = 3
    
    if ($status.RealTimeProtectionEnabled) { $score++ }
    if ($status.AntivirusEnabled) { $score++ }
    if ($pref.MAPSReporting -gt 0) { $score++ }
    
    if ($score -eq $total) {
        Write-Status "OK" "Overall Status: All systems operational ($score/$total)"
    } elseif ($score -gt 0) {
        Write-Status "WARNING" "Overall Status: Some issues detected ($score/$total)"
    } else {
        Write-Status "ERROR" "Overall Status: Critical issues detected ($score/$total)"
    }
} catch {
    Write-Status "ERROR" "Failed to generate summary"
}

Write-Host "`nCheck completed. Results saved to: $global:LogFile" -ForegroundColor Green