param ([switch]$ExchangeOnline, [string]$Outputpath, [string]$DomainController, [string]$ExchangeServer)

#region kills
if ($ExchangeOnline -eq $false) {
    Write-Host "No exchange online inventory" -ForegroundColor Yellow
    $ExchangeOnline = $false
    continue
}
else {
    Write-Host "INFO: connecting to exchange online" 
    $CheckIfExchangeCanBeLoaded = Import-Module -Name ExchangeOnlineManagement -ErrorAction SilentlyContinue
    If (!($CheckIfExchangeCanBeLoaded)) {
        $PackageExchangeOnline = Get-Module | Where-Object { $_.Name -eq "ExchangeOnlineManagement" }
        If (!($PackageExchangeOnline)) {
            Write-Host "- Exchange Online Management is not installed. Installing now ..."  -ForegroundColor Yellow
            Try {
                Install-Module -Name ExchangeOnlineManagement -Force -ErrorAction SilentlyContinue
                Write-Host "- Exchange Online Management is installed." -ForegroundColor Green
                Import-Module ExchangeOnlineManagement -ErrorAction SilentlyContinue
                Write-Host "- Exchange Online Management module is loaded" -ForegroundColor Green
                
            }
            catch {
                Write-Host "- There was an error installing Exchange Online Management"  -ForegroundColor Red
                break
            }
        }
        Else {
            Write-Host "- Exchange Online Management is allready installed" -ForegroundColor Green
            Write-Host "- Exchange Online Management module is loaded"  -ForegroundColor Green
        }
    }
    Else {
        Write-Host "- Exchange OnlineManagement module is loaded" -ForegroundColor Green
    }
    Try {
        Connect-ExchangeOnline -ShowBanner:$False
        $ExchangeOnline = $true
    }
    catch {
        Write-Host "- There was an error" -ForegroundColor Red
    }
}

if ($Outputpath -eq $null) {
    Write-Host "ERROR: No Outputpath was provided"  -ForegroundColor Red
    Write-Host "INFO: Use .\Get-ExchangeInventory.ps1 -OutputPath [YOURPATH]"
    break
}
else {
    Write-Host "INFO: Outputpath provided is $($Outputpath)" 
    Write-Host "INFO: Testing if exists..."

    $TestPath = Test-Path -path $Outputpath  
    If (!($TestPath)) {
        Write-Host "ERROR: Path does not exists" -ForegroundColor Red
        break
    }
    else {
        #do nothing
    }
}

If ($DomainController -eq $null) {
    Write-host "WARNING: No domain controller was provided" -ForegroundColor Yellow
    Write-Host "INFO: Selecting a domain controller"

    $DomainController = (Get-ADDomainController).HostName

    Write-Host "INFO: using $($DomainController) for the script"
}
else {
    #do nothing
}

if ($ExchangeServer -eq $null) {
    Write-Host "ERROR: No Exchange server was provided"  -ForegroundColor Red
    break
}
else {
    Write-Host "INFO: Connecting exchange server ($($ExchangeServer) with current credentials" -ForegroundColor Yellow
    Try {
        $session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$ExchangeServer/Powershell -Authentication Kerberos
        Import-PSSession $Session -DisableNameChecking -AllowClobber    
    }
    Catch {
        Write-Host "ERROR: Cannot connect to Exchange Server" -ForegroundColor Red
        Write-Host "$($_.ErrorDetails)" -ForegroundColor RED
    }
}
#endregion kills

#region preparing for results

$RecipientType = 'RoomMailbox', 'LinkedRoomMailbox', 'EquipmentMailbox', 'SchedulingMailbox', 
'LegacyMailbox', 'LinkedMailbox', 'UserMailbox', 'MailContact', 'DynamicDistributionGroup', 'MailForestContact', 'MailNonUniversalGroup', 'MailUniversalDistributionGroup', 'MailUniversalSecurityGroup', 
'RoomList', 'MailUser', 'GuestMailUser', 'GroupMailbox', 'DiscoveryMailbox', 'PublicFolder', 'TeamMailbox', 'SharedMailbox', 'RemoteUserMailbox', 'RemoteRoomMailbox', 'RemoteEquipmentMailbox', 
'RemoteTeamMailbox', 'RemoteSharedMailbox', 'PublicFolderMailbox', 'SharedWithMailUser'

$ExportResult = ""   
$ExportResults = @()  

$OutputOnPremCSV = "$Outputpath\ONPREM-EmailAddressesReport_$((Get-Date -format yyyy-MMM-dd).ToString()).csv"
$OutputOnLineCSV = "$Outputpath\Online-EmailAddressesReport_$((Get-Date -format yyyy-MMM-dd).ToString()).csv"

#endregion preparing for results

#region getting recipients 
$Count = 0
Get-Recipient -ResultSize Unlimited | ForEach-Object {
    $Count++
    $DisplayName = $_.DisplayName
    Write-Progress -Activity "`n     Retrieving email addresses of $DisplayName.."`n" Processed count: $Count"
    $RecipientTypeDetails = $_.RecipientTypeDetails
    $PrimarySMTPAddress = $_.PrimarySMTPAddress
    $SamAccountName = $_.SamAccountName
    $Alias = ($_.EmailAddresses | Where-Object { $_ -clike "smtp:*" } | ForEach-Object { $_ -replace "smtp:", "" }) -join ","
    If ($Alias -eq "") {
        $Alias = "-"
    }
    $ExportResult = @{'Display Name' = $DisplayName; 'Recipient Type Details' = $RecipientTypeDetails;  'SamAccountName' = $SamAccountName;'Primary SMTP Address' = $PrimarySMTPAddress; 'Alias' = $Alias }
    $ExportResults = New-Object PSObject -Property $ExportResult  
    $ExportResults | Select-Object 'Display Name', 'Recipient Type Details', 'Primary SMTP Address', 'Alias' | Export-Csv -Path $OutputOnPremCSV -Notype -Append
}
If ($Count -eq 0) {
    Write-Host No objects found
}
else {
    Write-Host `nThe output file contains $Count records
    if ((Test-Path -Path $OutputOnPremCSV) -eq "True") {
        Write-Host `nThe Output file availble in $OutputOnPremCSV -ForegroundColor Green
        $Prompt = New-Object -ComObject wscript.shell   
        $UserInput = $Prompt.popup("Do you want to open output file?",`   
            0, "Open Output File", 4)   
        If ($UserInput -eq 6) {   
            Invoke-Item "$OutputOnPremCSV"   
        } 
    }
}

if ($ExchangeOnline -eq $True) {
    $Count = 0
    Get-EXORecipient -ResultSize Unlimited -RecipientTypeDetails $RecipientType | ForEach-Object {
        $Count++
        $DisplayName = $_.DisplayName
        Write-Progress -Activity "`n     Retrieving email addresses of $DisplayName.."`n" Processed count: $Count"
        $RecipientTypeDetails = $_.RecipientTypeDetails
        $PrimarySMTPAddress = $_.PrimarySMTPAddress
        $Alias = ($_.EmailAddresses | Where-Object { $_ -clike "smtp:*" } | ForEach-Object { $_ -replace "smtp:", "" }) -join ","
        If ($Alias -eq "") {
            $Alias = "-"
        }
        $ExportResult = @{'Display Name' = $DisplayName; 'Recipient Type Details' = $RecipientTypeDetails; 'Primary SMTP Address' = $PrimarySMTPAddress; 'Alias' = $Alias }
        $ExportResults = New-Object PSObject -Property $ExportResult  
        $ExportResults | Select-Object 'Display Name', 'Recipient Type Details', 'Primary SMTP Address', 'Alias' | Export-Csv -Path $OutputOnLineCSV -Notype -Append
    }
    If ($Count -eq 0) {
        Write-Host No objects found
    }
    else {
        Write-Host `nThe output file contains $Count records
        if ((Test-Path -Path $OutputOnLineCSV) -eq "True") {
            Write-Host `nThe Output file availble in $OutputOnLineCSV -ForegroundColor Green
            $Prompt = New-Object -ComObject wscript.shell   
            $UserInput = $Prompt.popup("Do you want to open output file?",`   
                0, "Open Output File", 4)   
            If ($UserInput -eq 6) {   
                Invoke-Item "$OutputOnLineCSV"   
            } 
        }
    }
    Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore -ErrorAction SilentlyContinue
}
else {
    continue
}
#endregion getting recipients  
