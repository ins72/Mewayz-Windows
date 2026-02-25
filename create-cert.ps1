#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Creates a self-signed code-signing certificate for Mewayz.
    Run this once on your build machine. Outputs mewayz-codesign.pfx.

.NOTES
    Self-signed certs are trusted only on machines where you install them.
    End users will see a Windows SmartScreen warning unless you buy a cert
    from a trusted CA (DigiCert, Sectigo, etc.).
#>

$ErrorActionPreference = 'Stop'

# ── Configuration ────────────────────────────────────────────────────────────
$Subject    = "CN=Mewayz Global Corp, O=Mewayz Global Corp, C=US"
$FriendlyName = "Mewayz Code Signing"
$PfxPath    = Join-Path $PSScriptRoot "mewayz-codesign.pfx"
$CertStore  = "Cert:\LocalMachine\My"
# ─────────────────────────────────────────────────────────────────────────────

# Prompt for PFX password
$Password = Read-Host -AsSecureString "Enter a password to protect the PFX file"

Write-Host "`nCreating self-signed code-signing certificate..." -ForegroundColor Cyan

$cert = New-SelfSignedCertificate `
    -Subject           $Subject `
    -FriendlyName      $FriendlyName `
    -Type              CodeSigning `
    -KeyUsage          DigitalSignature `
    -KeyAlgorithm      RSA `
    -KeyLength         4096 `
    -HashAlgorithm     SHA256 `
    -CertStoreLocation $CertStore `
    -NotAfter          (Get-Date).AddYears(5)

Write-Host "  Certificate created: $($cert.Thumbprint)" -ForegroundColor Green

# Export PFX (private key + cert)
Export-PfxCertificate -Cert $cert -FilePath $PfxPath -Password $Password | Out-Null
Write-Host "  PFX exported to:     $PfxPath" -ForegroundColor Green

# Trust the cert locally (so signtool timestamp validation passes on this machine)
$rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store(
    [System.Security.Cryptography.X509Certificates.StoreName]::Root,
    [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine
)
$rootStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
$rootStore.Add($cert)
$rootStore.Close()
Write-Host "  Added to Trusted Root CA store (local machine)" -ForegroundColor Green

# Print the thumbprint for reference
$thumbprint = $cert.Thumbprint

$signCmd = "signtool.exe sign /sha1 $thumbprint /tr http://timestamp.digicert.com /td sha256 /fd sha256 `$f"

Write-Host @"

────────────────────────────────────────────────────────────────
 Certificate thumbprint: $thumbprint
────────────────────────────────────────────────────────────────

Build the SIGNED installer with this exact command
(run from the project folder):

  ISCC.exe /DSIGN=1 "/Ssigntool=$signCmd" testt.iss

Or to sign an existing EXE manually:

  signtool.exe sign /sha1 $thumbprint /tr http://timestamp.digicert.com /td sha256 /fd sha256 Output\mewayz.exe

NOTE: Recipients will see a SmartScreen warning because this is
      a self-signed certificate. To suppress SmartScreen warnings
      for end users you need a commercially issued OV or EV cert.
"@ -ForegroundColor Yellow
