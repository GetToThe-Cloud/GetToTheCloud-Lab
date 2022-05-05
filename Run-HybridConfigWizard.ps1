$ExchangeServer = $env:Computername
$ExchangeServer = (Get-ADComputer $ExchangeServer).DNSHostname
$OutputFolder = "C:\ExchangeDownload"
$EdgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$EdgeUri = "https://msedge.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/e4600c98-19d4-4707-8c4a-32d674a082c5/MicrosoftEdgeEnterpriseX64.msi"

Write-Host "[INFO] Connecting to $($ExchangeServer) ..."
## connection to exchange
$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$ExchangeServer/Powershell -Authentication Kerberos 
Import-PSSession $Session -DisableNameChecking -AllowClobber

If (!(Get-Pssession | where-Object { $_.ConfigurationName -eq "Microsoft.Exchange" })) {
    Write-Host "[ERROR] not connected to $($ExchangeServer)" -ForegroundColor Red
    break
}

Write-Host "[INFO] Checking if Edge is allready installed ..."
If (!(Test-path $EdgePath)){
    Write-Host "[WARNING] Edge is not yet installed... Downloading now" -ForegroundColor Yellow
    $name = $Edgeuri.Split("/")
    $Number = $name.count -1
    $name = $Name[$number]
    Invoke-WebRequest -Uri $EdgeUri -OutFile "$Outputfolder\$name"
    if (!(Test-Path "$Outputfolder\$name")){
        Write-Host "[ERROR] Something went wrong downloading Microsoft Edge" -ForegroundColor Red
        break
    }
    MsiExec.exe /i "$Outputfolder\$name" /qn
    Write-Host "[INFO] waiting for installation to complete"
    Do {
        $Test = Test-Path $EdgePath
        Start-Sleep 10
    }
    Until ($Test -eq $True)
    Write-Host "[SUCCESS] Microsoft Edge is succesfully installed" -ForegroundColor Green
}
else {
    Write-Host "[INFO] Microsoft Edge is allready installed..."
}

Write-Host "[INFO] Enabling MRSProxy ...."
Get-WebServicesVirtualDirectory -ADPropertiesOnly | Where {$_.MRSProxyEnabled -ne $true} | Set-WebServicesVirtualDirectory -MRSProxyEnabled $true

Write-Host "[INFO] Starting Hybrid Config Wizard ..."
Start-Sleep 3
Start-Process $EdgePath https://aka.ms/HybridWizard