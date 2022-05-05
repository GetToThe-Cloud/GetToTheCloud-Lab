function Load-Module ($m) {

    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m}) {
        write-host "[INFO] Module $m is already imported."
    }
    else {

        # If module is not imported, but available on disk then import
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
            if ($M -eq "MSOnline"){
            Import-Module $m  -UseWindowsPowershell 
            }
            else {
                Import-Module $m
            }
        }
        else {

            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $m | Where-Object {$_.Name -eq $m}) {
                Install-Module -Name $m -Force -Verbose -Scope CurrentUser
                Import-Module $m 
            }
            else {

                # If the module is not imported, not available and not in the online gallery then abort
                write-host "Module $m not imported, not available and not in an online gallery, exiting."
                EXIT 1
            }
        }
    }
}

Load-Module "ExchangeOnlineManagement" 
Load-Module "MSOnline"
Load-Module "AZ"


#remove groups


Write-Host "[INFO] Connecting Azure ..."
Connect-AzAccount | out-Null
Write-Host "[INFO] Connecting Exchange Online  ..."
Connect-ExchangeOnline -ShowBanner:$false -ShowProgress $false
Write-Host "[INFO] Connecting Microsoft Online Services  ..."
Connect-MSOLService

Write-Host "[INFO] Setting MsolDirSync to Disabled"
Try {
    Set-MsolDirSyncEnabled -EnableDirSync $false -force
    if (!((Get-MsolCompanyInformation).DirectorySynchronizationEnabled)){
        Write-Host "[SUCCESS] MsolDirSync is Disabled" -ForegroundColor Green
    }
    else {
        Write-Host "[ERROR] Something went wrong" -ForegroundColor red
        break
    }
}
catch {
    #do nothing
}

$Groups = Get-AZAdGroup | Where-Object {$_.Displayname -like "A-*" -or $_.DisplayName -like "GG-*" -or $_.DisplayName -Like "DG-*" -or $_.DisplayName -like "UG-*"} 
$Users = Get-MSOLUser | Where-Object {$_.immutableID -ne $null}

Write-Host "[INFO] there are $($Goups.Count) groups to be deleted and $($users.count) users"
Write-Host "[INFO] Deleting synced groups ..."
ForEach ($Group in $Groups){
   if (Get-DistributionGroup $Group.DisplayName){
       $group | Remove-DistributionGroup -confirm:$false
       Write-Host "[WARNING] $($Group.Displayname) was a Distribution Group and is deleted" -ForegroundColor Yellow
   }
   Else {
       $Group | Remove-AzADGroup
       Write-Host "[WARNING] $($Group.Displayname) was a Security Group and is deleted" -ForegroundColor Yellow
   }
}

Write-Host "[INFO] Deleting synced users ..."
ForEach ($User in $Users){
    $user | Remove-MSOLUser -Force
    Write-Host "[WARNING] $($User.DisplayName) is deleted" -ForegroundColor Yellow
}
$ResourceGroupName = Get-AZResourceGroup | Where-Object {$_.ResourceGroupName -like "GetToTheCloud*"}
Write-Host "[INFO] Deleting everything in resourcegroup: $($ResourceGroupName.ResourceGroupName)" -ForegroundColor Yellow
$ResourceGroupName | Remove-AZResourceGroup -Force

Write-Host "[INFO] Checking if everything is deleted"
$Groups = Get-AZAdGroup | Where-Object {$_.Displayname -like "A-*" -or $_.DisplayName -like "GG-*" -or $_.DisplayName -Like "DG-*" -or $_.DisplayName -like "UG-*"} 
$Users = Get-MSOLUser | Where-Object {$_.immutableID -ne $null}
$ResourceGroupName = Get-AZResourceGroup | Where-Object {$_.ResourceGroupName -like "GetToTheCloud*"}
if (!($Groups)){
    Write-Host "[SUCCESS] all groups related to testlab is deleted" -ForegroundColor green
}
if (!($users)){
    Write-Host "[SUCCESS] all users related to testlab is deleted" -ForegroundColor green
}
if (!($ResourceGroupName)){
    Write-Host "[SUCCESS] all Resources related to testlab is deleted" -ForegroundColor green
}
