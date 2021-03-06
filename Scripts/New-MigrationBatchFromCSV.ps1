###########################################################################################
#############             MIGRATION SCRIPT EXCHANGE CROSS FOREST              #############
###########################################################################################

## PREPARING USERS TO MIGRATE
$ExchangeServer = $env:Computername
$ExchangeServer = (Get-ADComputer $ExchangeServer).DNSHostname
$TargetDeliveryDomain = ""

Write-Host "[INFO] Connecting to $($ExchangeServer) ..."
## connection to exchange
$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$ExchangeServer/Powershell -Authentication Kerberos 
Import-PSSession $Session -DisableNameChecking -AllowClobber

If (!(Get-Pssession | where-Object { $_.ConfigurationName -eq "Microsoft.Exchange" })) {
    Write-Host "[ERROR] not connected to $($ExchangeServer)" -ForegroundColor Red
    break
}

$migrationEndpoint = Get-MigrationEndpoint

$Batches = Get-Childitem C:\Temp | Where-Object { $_.Name -like “batch*.txt” }
$Batches = $batches.Split(“.”)[0];
ForEach ($Batch in $Batches) {
    $Users = Get-Content "C:\Temp\$Batch.txt"
    $Batch = New-MigrationBatch -Name $Batch -SourceEndpoint $MigrationEndpoint.Identity -TargetDeliveryDomain $TargetDeliveryDomain -CSVData ([System.IO.File]::ReadAllBytes("C:\temp\$Batch.csv"))
    Start-MigrationBatch -Identity $Batch.Identity
}
