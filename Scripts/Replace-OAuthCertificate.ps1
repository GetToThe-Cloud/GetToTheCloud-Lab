$ExchangeServer = $env:Computername
$ExchangeServer = (Get-ADComputer $ExchangeServer).DNSHostname

Write-Host "[INFO] Connecting to $($ExchangeServer) ..."
## connection to exchange
$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$ExchangeServer/Powershell -Authentication Kerberos 
Import-PSSession $Session -DisableNameChecking -AllowClobber

If (!(Get-Pssession | where-Object { $_.ConfigurationName -eq "Microsoft.Exchange" })) {
    Write-Host "[ERROR] not connected to $($ExchangeServer)" -ForegroundColor Red
    break
}

Write-Host "[INFO] Generating a new Exchange OAuth certificate ..."
Try {
    $Certificate = New-ExchangeCertificate -KeySize 2048 -PrivateKeyExportable $true -SubjectName "cn=Microsoft Exchange Server Auth Certificate" -FriendlyName "Microsoft Exchange Server Auth Certificate" -DomainName @() -force
    Write-host "[SUCCESS] New certificate is generated with thumbprint: $($Certificate.thumbprint)" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Cannot create a new certificate" -ForegroundColor ERROR
    Write-Host "$($_.ErrorDetails)" -ForegroundColor red
}
Write-Host "[INFO] Setting new certificate to OAuth config"
Try {
    Set-AuthConfig -NewCertificateThumbprint $($Certificate.thumbprint) -NewCertificateEffectiveDate (Get-Date) -force
    if (((Get-AuthConfig).CurrentCertiticateThumbPrint | Get-ExchangeCertificate).Thumbprint -eq $($Certificate.thumbprint)) {
        Write-host "[SUCCESS] Certificate is set to OAuth" -ForegroundColor Green
    }
}

catch {
    Write-Host "[ERROR] Certificate is not set" -ForegroundColor Red
    break
}

Set-AuthConfig -PublishCertificate
Set-AuthConfig -ClearPreviousCertificate

Write-Host "[INFO] Restarting Exchange Services Host services"
Restart-Service MSExchangeServiceHost
Restart-Service W3SVC
Write-Host "[INFO] Restarting WebAppPools ..."
Restart-WebAppPool MSExchangeOWAAppPool
Restart-WebAppPool MSExchangeECPAppPool

Write-Host "[SUCCESS] New OAuth certificate is set. Now wait for at least an hour!" -ForegroundColor Green

Get-PSSession | remove-PSSession 
