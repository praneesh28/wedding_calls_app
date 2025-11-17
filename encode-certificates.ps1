# PowerShell script to encode certificates and provisioning profiles to Base64
# This is for Windows users who need to prepare files for GitHub Actions secrets

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Certificate & Profile Base64 Encoder" -ForegroundColor Cyan
Write-Host "For GitHub Actions iOS Build Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to encode a file to Base64
function Encode-FileToBase64 {
    param(
        [string]$FilePath,
        [string]$FileType
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "Error: File not found: $FilePath" -ForegroundColor Red
        return $null
    }
    
    try {
        $bytes = [IO.File]::ReadAllBytes($FilePath)
        $base64 = [Convert]::ToBase64String($bytes)
        
        Write-Host "✓ Successfully encoded $FileType" -ForegroundColor Green
        Write-Host ""
        Write-Host "Base64 encoded string:" -ForegroundColor Yellow
        Write-Host $base64 -ForegroundColor White
        Write-Host ""
        
        # Save to file
        $outputFile = "$FilePath.base64.txt"
        $base64 | Out-File -FilePath $outputFile -Encoding ASCII
        Write-Host "✓ Saved to: $outputFile" -ForegroundColor Green
        Write-Host ""
        
        return $base64
    }
    catch {
        Write-Host "Error encoding file: $_" -ForegroundColor Red
        return $null
    }
}

# Main menu
Write-Host "What would you like to encode?" -ForegroundColor Yellow
Write-Host "1. Certificate (.p12 file)" -ForegroundColor White
Write-Host "2. Provisioning Profile (.mobileprovision file)" -ForegroundColor White
Write-Host "3. Both" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Enter your choice (1-3)"

switch ($choice) {
    "1" {
        $certPath = Read-Host "Enter path to .p12 certificate file"
        Encode-FileToBase64 -FilePath $certPath -FileType "Certificate"
    }
    "2" {
        $profilePath = Read-Host "Enter path to .mobileprovision file"
        Encode-FileToBase64 -FilePath $profilePath -FileType "Provisioning Profile"
    }
    "3" {
        $certPath = Read-Host "Enter path to .p12 certificate file"
        $profilePath = Read-Host "Enter path to .mobileprovision file"
        
        Write-Host ""
        Write-Host "Encoding Certificate..." -ForegroundColor Cyan
        Encode-FileToBase64 -FilePath $certPath -FileType "Certificate"
        
        Write-Host ""
        Write-Host "Encoding Provisioning Profile..." -ForegroundColor Cyan
        Encode-FileToBase64 -FilePath $profilePath -FileType "Provisioning Profile"
    }
    default {
        Write-Host "Invalid choice!" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Copy the Base64 string(s) above" -ForegroundColor White
Write-Host "2. Go to GitHub → Settings → Secrets → Actions" -ForegroundColor White
Write-Host "3. Add new secrets:" -ForegroundColor White
Write-Host "   - CERTIFICATE_BASE64 (for .p12 file)" -ForegroundColor White
Write-Host "   - PROVISIONING_PROFILE_BASE64 (for .mobileprovision file)" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan

