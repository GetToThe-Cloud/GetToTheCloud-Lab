#Requesting UserInput






##########################################################################################################################################################
# DO NOT EDIT BELOW !!!!                                                                                                                                 #
##########################################################################################################################################################
## getting credentials for virtual machines
$Username = "LabAdmin"
$Password = "Welkom01!!"
$Cred = $Password | ConvertTo-SecureString -Force -AsPlainText
$Credential = New-Object -TypeName PSCredential -ArgumentList ($Username, $Cred)
$DomainName = "TestDomain.local"
$Domain = $DomainName.Split(".")[0]
$DomainUser = $domain + "\" + $Username
$DomainCredential = New-Object -TypeName PSCredential -ArgumentList ($DomainUser, $Cred)
$PSRemoteUri = "https://raw.githubusercontent.com/GetToThe-Cloud/GetToTheCloud-Lab/main/Set-PowershellRemoting.ps1"

Write-Host "  ___       _   _____     _____  _           ___  _                _ "
Write-Host " / __| ___ | |_|_   _|___|_   _|| |_   ___  / __|| | ___  _  _  __| |"
Write-Host "| (_ |/ -_)|  _| | | / _ \ | |  | ' \ / -_)| (__ | |/ _ \| || |/ _` |"
Write-Host " \___|\___| \__| |_| \___/ |_|  |_||_|\___| \___||_|\___/ \_,_|\__,_| "
Write-Host "                                                                     "
Write-Host ""
Write-Host "[INFO] Building a testlab on Azure"
Write-Host ""

#checking ps version
if ($PSVersionTable.PSVersion.Major -ne "7") {
    Write-Host "[ERROR] Powershell 7.x is needed for running this script..." -ForegroundColor Red
    break
}
else {
    Write-Host "[INFO] Powershell $($PSVersionTable.PSVersion.Major).x is found" -ForegroundColor green
}

## installing Azure Module in Powershell 7.1.4
$CheckifModuleExist = Get-InstalledModule | Where-Object {$_.name -eq "AZ"}
if (!($CheckifModuleExist)) {
    Write-Host "[WARNING] installing powershell module AZ" -ForegroundColor Yellow
    Try {
        Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force
        Write-Host "[SUCCESS] powershell module is installed" -ForegroundColor green
    }
    catch {
        Write-host "[ERROR] unable to install powershell module" -ForegroundColor red
    }
}

$TimeStart = Get-Date
Write-Host "[INFO] Start time of script $($TimeStart)"

Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

## connecting to Azure
Connect-AzAccount -InformationAction SilentlyContinue | out-Null

## creating network
$LocationName = "westeurope"
$ResourceGroupName = "TestDomain"
$VMSize = "Standard_B2s"
$NetworkName = "TestDomain-TestLab"
$SubnetName = "TestLab"
$SubnetAddressPrefix = "10.10.0.0/24"
$VnetAddressPrefix = "10.10.0.0/24"

## creating resource group
Try {
    $newGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $LocationName -InformationAction SilentlyContinue
    Write-host "[SUCCESS] Resource Group is created with the name $($ResourceGroupName)" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Creating Resource group" -ForegroundColor Red
}

$SingleSubnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
$Vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet


function New-TestLabVirtualMachine {
    # Parameter help description
    param ([string]$ComputerName, [string]$VMName, [string]$PublisherName, [string]$Offer, [string]$Skus)

    $NICName = -join ("NIC-", $VMName)
    $NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $Vnet.Subnets[0].Id 
    $VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
    $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
    $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
    $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $PublisherName -Offer $Offer -Skus $Skus -Version latest
    $VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -Disable
    Try {
        Write-Host "[INFO] Creating a vm with the name $($VMName)"
        $NewVM = New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine
    }
    Catch {
        Write-Host "[ERROR] Something went wrong creating vm: $($Vmname)" -ForegroundColor Red
    }
}
Function Add-TestLabPublicIP {
    param ([string]$VMName, [string]$NICName, [string]$ResourceGroupName, [string]$NetworkName)

    $NewIP = New-AzPublicIpAddress -Name "$($VMName)PublicIP" -ResourceGroupName $ResourceGroupName -AllocationMethod Dynamic -Location $LocationName -InformationAction SilentlyContinue | out-Null

    $vnet = Get-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -InformationAction SilentlyContinue 
    $subnet = Get-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $vnet -InformationAction SilentlyContinue 
    $NicName = (Get-AzNetworkInterface | where-Object { $_.Name -like "*$vmname*" }).Name
    $nic = Get-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -InformationAction SilentlyContinue 
    $pip = Get-AzPublicIpAddress -Name "$($VMName)PublicIP" -ResourceGroupName $ResourceGroupName -InformationAction SilentlyContinue 
    $nic | Set-AzNetworkInterfaceIpConfig -Name ipconfig1 -PublicIPAddress $pip -Subnet $subnet -InformationAction SilentlyContinue 
    $nic | Set-AzNetworkInterface -InformationAction SilentlyContinue 
}
Function Add-ScriptExtension {
    param ([string]$fileuri, [string]$VMName)

    $number = $fileuri.Split("/").Count - 1
    $Script = $fileuri.Split("/")[$number]

    $run = Set-AzVMCustomScriptExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Location $LocationName -FileUri $FileUri -Run  $Script -Name $Script -InformationAction SilentlyContinue

    $Check = Get-AzVMCustomScriptExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -name $Script
    if ($Check.ProvisioningState -eq "Succeeded") {
        Write-Host "[SUCCESS] Script extension $($Script) succesfull deployed" -ForegroundColor Green
        $State = "OK"
    }
    else {
        Write-Host "[ERROR] Script extension $($Script) was not deployed" -ForegroundColor Red
    }
    if ($State -eq "OK"){
        $run = Remove-AzVMCustomScriptExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Name $Script -Force -InformationAction SilentlyContinue
        Write-Host "[INFO] $($Script) is deleted as custom script extention but was executed"
    }
}

$IP = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content

## create domain controller server
$ComputerName = "DC01"
$VMName = "DC01"
$DC = $VMName
$NICDC = "NIC-" + $VMName
$PublisherName = "MicrosoftWindowsServer"
$Offer = "WindowsServer"
$Skus = "2019-datacenter-gensecond"
$NICName = -join ("NIC-", $VMName)

New-TestLabVirtualMachine -ComputerName $Computername -VMName $VMName -PublisherName $PublisherName -Offer $Offer -Skus $Skus  | out-Null
$Check = Get-AzVM -Name $VMName
if ($Check) {
    Write-Host "[SUCCESS] Virtual Machine with the name $($VMName) is created" -ForegroundColor Green
}
else {
    Write-Host "[ERROR] Something went wrong creating a Virtual Machine with the name $($VMName)" -ForegroundColor Red
    break
}
Add-TestLabPublicIP -VMName $Vmname -ResourceGroupName $ResourceGroupName -NICName $NicName -NetworkName $NetworkName | out-Null
$SecGroupname = -Join ($vmname, "NetworkSecurityGroup")
try {
    $newGroup = New-AZNetworkSecurityGroup -Name $SecGroupname -ResourceGroupName $ResourceGroupName -Location $LocationName -InformationAction SilentlyContinue
    Write-Host "[SUCCESS] Network Security group with the name $($SecGroupname) is created" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Something went wrong creating a Network Security group with the name $($SecGroupname)" -ForegroundColor RED
    break
}
$NSG = Get-AZNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $SecGroupname -InformationAction SilentlyContinue
$vNIC = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name $NicName -InformationAction SilentlyContinue
$vNIC.NetworkSecurityGroup = $NSG
try {
    $vNIC | Set-AzNetworkInterface -InformationAction SilentlyContinue | out-Null
    Write-Host "[SUCCESS] $($SecGroupname) is set to $($NicName)" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] There was a problem setting $($SecGroupname) to $($NicName)" -ForegroundColor Red
    break
}
Try {   
    Write-host "[INFO] adding security rule to $($SecGroupname)"
    $nsg | Add-AzNetworkSecurityRuleConfig -Name WINRM -Description "Allow WINRM port" -Access Allow `
        -Protocol * -Direction Inbound -Priority 100 -SourceAddressPrefix $IP -SourcePortRange * `
        -DestinationAddressPrefix * -DestinationPortRange 5985 -InformationAction SilentlyContinue | out-Null
    Write-Host "[SUCCESS] security rule is added to $($SecGroupname)" -ForegroundColor Green
}
Catch {
    Write-Host "[ERROR] there was a problem adding a security rule to $($SecGroupname)" -ForegroundColor Red
}
        
$nsg | Set-AzNetworkSecurityGroup -InformationAction SilentlyContinue | out-Null

#vm extension

Write-Host "[INFO] enabling Remote powershell to $($Vmname)"
Add-ScriptExtension -FileUri $PSRemoteUri -VMName $VMName

## create exchange server
$ComputerName = "AD01"
$VMName = "AD01"
$VMSize = "Standard_B2ms"
$EX = $VMname
$PublisherName = "MicrosoftWindowsServer"
$Offer = "WindowsServer"
$Skus = "2019-datacenter-gensecond"
$NICName = -join ("NIC-", $VMName)

New-TestLabVirtualMachine -ComputerName $Computername -VMName $VMName -PublisherName $PublisherName -Offer $Offer -Skus $Skus  | out-Null
$Check = Get-AzVM -Name $VMName
if ($Check) {
    Write-Host "[SUCCESS] Virtual Machine with the name $($VMName) is created" -ForegroundColor Green
}
else {
    Write-Host "[ERROR] Something went wrong creating a Virtual Machine with the name $($VMName)" -ForegroundColor Red
}
Add-TestLabPublicIP -VMName $Vmname -ResourceGroupName $ResourceGroupName -NICName $NicName -NetworkName $NetworkName | out-Null
$SecGroupname = -Join ($vmname, "NetworkSecurityGroup")
try {
    $newGroup = New-AZNetworkSecurityGroup -Name $SecGroupname -ResourceGroupName $ResourceGroupName -Location $LocationName -InformationAction SilentlyContinue
    Write-Host "[SUCCESS] Network Security group with the name $($SecGroupname) is created" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Something went wrong creating a Network Security group with the name $($SecGroupname)" -ForegroundColor RED
}
$NSG = Get-AZNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $SecGroupname -InformationAction SilentlyContinue
$vNIC = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name $NicName -InformationAction SilentlyContinue
$vNIC.NetworkSecurityGroup = $NSG
try {
    $vNIC | Set-AzNetworkInterface -InformationAction SilentlyContinue | out-Null
    Write-Host "[SUCCESS] $($SecGroupname) is set to $($NicName)" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] There was a problem setting $($SecGroupname) to $($NicName)" -ForegroundColor Red
}
Try {
    Write-host "[INFO] adding security rule to $($SecGroupname)"
    $nsg | Add-AzNetworkSecurityRuleConfig -Name WINRM -Description "Allow WINRM port" -Access Allow `
        -Protocol * -Direction Inbound -Priority 100 -SourceAddressPrefix $IP -SourcePortRange * `
        -DestinationAddressPrefix * -DestinationPortRange 5985 -InformationAction SilentlyContinue | out-Null
    Write-host "[SUCCESS] added WINRM port bind to $IP to $($SecGroupname)"  -ForegroundColor Green
    $nsg | Add-AzNetworkSecurityRuleConfig -Name SMTP -Description "Allow SMTP port" -Access Allow `
        -Protocol * -Direction Inbound -Priority 101 -SourceAddressPrefix "*" -SourcePortRange * `
        -DestinationAddressPrefix * -DestinationPortRange 25  -InformationAction SilentlyContinue | out-Null
    Write-host "[SUCCESS] added SMTP port to $($SecGroupname)"  -ForegroundColor Green
    $nsg | Add-AzNetworkSecurityRuleConfig -Name HTTPS -Description "Allow HTTPS port" -Access Allow `
        -Protocol * -Direction Inbound -Priority 102 -SourceAddressPrefix "*" -SourcePortRange * `
        -DestinationAddressPrefix * -DestinationPortRange 443  -InformationAction SilentlyContinue | Out-Null    
    Write-host "[SUCCESS] added HTTPS port to $($SecGroupname)"  -ForegroundColor Green
    $nsg | Add-AzNetworkSecurityRuleConfig -Name HTTP -Description "Allow HTTP port" -Access Allow `
        -Protocol * -Direction Inbound -Priority 103 -SourceAddressPrefix "*" -SourcePortRange * `
        -DestinationAddressPrefix * -DestinationPortRange 80  -InformationAction SilentlyContinue | out-Null
    Write-host "[SUCCESS] added HTTP port to $($SecGroupname)"  -ForegroundColor Green
    Write-Host "[SUCCESS] security rule is added to $($SecGroupname)" -ForegroundColor Green
}
Catch {
    Write-Host "[ERROR] there was a problem adding a security rule to $($SecGroupname)" -ForegroundColor Red
}
$nsg | Set-AzNetworkSecurityGroup -InformationAction SilentlyContinue | out-Null

#vm extension

Write-Host "[INFO] enabling Remote powershell to $($Vmname)"
Add-ScriptExtension -FileUri $PSRemoteUri -VMName $VMName

## create windows 11 
$ComputerName = "WIN11"
$VMName = "WIN11"
$VMSize = "Standard_B2s"
$PublisherName = "microsoftwindowsdesktop"
$Offer = "windows-11"
$Skus = "win11-21h2-pron"
$NICName = -join ("NIC-", $VMName)

New-TestLabVirtualMachine -ComputerName $Computername -VMName $VMName -PublisherName $PublisherName -Offer $Offer -Skus $Skus  | out-Null
$Check = Get-AzVM -Name $VMName
if ($Check) {
    Write-Host "[SUCCESS] Virtual Machine with the name $($VMName) is created" -ForegroundColor Green
}
else {
    Write-Host "[ERROR] Something went wrong creating a Virtual Machine with the name $($VMName)" -ForegroundColor Red
}
Add-TestLabPublicIP -VMName $Vmname -ResourceGroupName $ResourceGroupName -NICName $NicName -NetworkName $NetworkName | out-Null
$SecGroupname = -Join ($vmname, "NetworkSecurityGroup")
try {
    $newGroup = New-AZNetworkSecurityGroup -Name $SecGroupname -ResourceGroupName $ResourceGroupName -Location $LocationName -InformationAction SilentlyContinue
    Write-Host "[SUCCESS] Network Security group with the name $($SecGroupname) is created" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Something went wrong creating a Network Security group with the name $($SecGroupname)" -ForegroundColor RED
}
$NSG = Get-AZNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $SecGroupname -InformationAction SilentlyContinue 
$vNIC = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name $NicName -InformationAction SilentlyContinue 
$vNIC.NetworkSecurityGroup = $NSG
try {
    $vNIC | Set-AzNetworkInterface -InformationAction SilentlyContinue | out-Null
    Write-Host "[SUCCESS] $($SecGroupname) is set to $($NicName)" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] There was a problem setting $($SecGroupname) to $($NicName)" -ForegroundColor Red
}
        
Try {
    Write-host "[INFO] adding security rule to $($SecGroupname)"
    $nsg | Add-AzNetworkSecurityRuleConfig -Name RDP -Description "Allow RDP port" -Access Allow `
        -Protocol * -Direction Inbound -Priority 100 -SourceAddressPrefix $IP -SourcePortRange * `
        -DestinationAddressPrefix * -DestinationPortRange 3389 -InformationAction SilentlyContinue | out-Null
    Write-Host "[SUCCESS] security rule for RDP is added to $($SecGroupname)" -ForegroundColor Green
}
Catch {
    Write-Host "[ERROR] there was a problem adding a security rule to $($SecGroupname)" -ForegroundColor Red
}

$nsg | Set-AzNetworkSecurityGroup -InformationAction SilentlyContinue | out-Null


#region Azure VM Extention
#vm extension
$VMName = $DC
$Pip = $VMName + "PublicIP"
$fileUri = "https://raw.githubusercontent.com/GetToThe-Cloud/GetToTheCloud-Lab/main/01-DC-SetupDomainController.ps1"
$IP = (Get-AZPublicIPAddress -Name $Pip).IpAddress

Write-Host "[INFO] Connecting to $($VMName) with IP $IP for installing Domain Controller"
Invoke-Command -Computername $IP -ScriptBlock {
    Param ($fileuri)
    $OutputFolder = "C:\Temp"
    if (Test-Path -path $OutputFolder) {
        #do nothing
    }
    else {
        $Location = $OutputFolder.Split("\")
        New-Item -Path "$($Location[0])\" -Name $Location[1] -ItemType Directory
    }

    $Script = (Invoke-WebRequest -Uri $fileUri -UseBasicParsing).Content
    $Script | Out-File C:\Temp\script.ps1
    powershell C:\temp\script.ps1
    Remove-Item C:\Temp\script.ps1 -force
} -Credential $Credential -ArgumentList $fileUri

$VMName = $EX
$Pip = $VMName + "PublicIP"
$fileUri = "https://raw.githubusercontent.com/GetToThe-Cloud/GetToTheCloud-Lab/main/02-EXC-DownloadExchange.ps1"
$IP = (Get-AZPublicIPAddress -Name $Pip).IpAddress
Write-Host "[INFO] Connecting to $($VMName) with IP $IP for downloading Exchange software"

Invoke-Command -Computername $IP -ScriptBlock {
    Param ($fileuri)
    $OutputFolder = "C:\Temp"
    if (Test-Path -path $OutputFolder) {
        #do nothing
    }
    else {
        $Location = $OutputFolder.Split("\")
        New-Item -Path "$($Location[0])\" -Name $Location[1] -ItemType Directory
    }
    $Script = (Invoke-WebRequest -Uri $fileUri -UseBasicParsing).Content
    $Script | Out-File C:\Temp\script.ps1
    powershell C:\temp\script.ps1
    Remove-Item C:\Temp\script.ps1 -force
    $Download = (Invoke-WebRequest -uri "https://raw.githubusercontent.com/GetToThe-Cloud/GetToTheCloud-Lab/main/04-EXC-ConfigureExchange.ps1" -UseBasicParsing).Content
    $Download | Out-File C:\ExchangeDownload\04-EXC-ConfigureExchange.ps1
    $Download = (Invoke-WebRequest -uri "https://raw.githubusercontent.com/GetToThe-Cloud/GetToTheCloud-Lab/main/Scripts/Replace-OAuthCertificate.ps1" -UseBasicParsing).Content
    $Download | Out-File C:\ExchangeDownload\Replace-OAuthCertificate.ps1
    $Download = (Invoke-WebRequest -uri "https://raw.githubusercontent.com/GetToThe-Cloud/GetToTheCloud-Lab/main/Scripts/Run-HybridConfigWizard.ps1" -UseBasicParsing).Content
    $Download | Out-File C:\ExchangeDownload\Run-HybridConfigWizard.ps1
    $Download = (Invoke-WebRequest -uri "https://raw.githubusercontent.com/GetToThe-Cloud/GetToTheCloud-Lab/main/Scripts/GetToTheCloudFunctions.psm1" -UseBasicParsing).Content
    $Download | Out-File C:\ExchangeDownload\GetToTheCloudFunctions.psm1
} -Credential $Credential -ArgumentList $fileUri

$VMName = $EX
$Pip = $VMName + "PublicIP"
$fileUri = "https://raw.githubusercontent.com/GetToThe-Cloud/GetToTheCloud-Lab/main/011-EXC-NetworkSettings.ps1"
$IP = (Get-AZPublicIPAddress -Name $Pip).IpAddress
$EXIP = $IP
Write-Host "[INFO] Connecting to $($VMName) with IP $IP for setting Network Settings Exchange server"

Invoke-Command -Computername $IP -ScriptBlock {
    Param ($fileuri)
    $Script = ""
    $OutputFolder = "C:\Temp"
    if (Test-Path -path $OutputFolder) {
        #do nothing
    }
    else {
        $Location = $OutputFolder.Split("\")
        New-Item -Path "$($Location[0])\" -Name $Location[1] -ItemType Directory
    }
    $Script = (Invoke-WebRequest -Uri $fileUri -UseBasicParsing).Content
    $Script | Out-File C:\Temp\script.ps1
    powershell C:\temp\script.ps1
    Remove-Item C:\Temp\script.ps1 -force
} -Credential $Credential -ArgumentList $fileUri

Write-Host "[INFO] Restarting $($Vmname) now"
Restart-AZVM -ResourceGroupName $ResourceGroupName -Name $VMName 

$VMName = $DC
$Pip = $VMName + "PublicIP"
$FileUri = "https://raw.githubusercontent.com/GetToThe-Cloud/GetToTheCloud-Lab/main/03-DC-ConfigureActiveDirectory.ps1"
$IP = (Get-AZPublicIPAddress -Name $Pip).IpAddress

Write-Host "[INFO] Connecting to $($VMName) with IP $IP for Creating Domain structure"
Invoke-Command -Computername $IP -ScriptBlock {
    Param ($fileuri)
    $OutputFolder = "C:\Temp"
    if (Test-Path -path $OutputFolder) {
        #do nothing
    }
    else {
        $Location = $OutputFolder.Split("\")
        New-Item -Path "$($Location[0])\" -Name $Location[1] -ItemType Directory
    }

    $Script = (Invoke-WebRequest -Uri $fileUri -UseBasicParsing).Content
    $Script | Out-File C:\Temp\script.ps1
    powershell C:\temp\script.ps1
    Remove-Item C:\Temp\script.ps1 -force
} -Credential $DomainCredential -ArgumentList $fileUri


# $VMName = $EX
# $Pip = $VMName + "PublicIP"
# $fileUri = "https://raw.githubusercontent.com/GetToThe-Cloud/TUT01-BuildingATestLab/main/Final/03-EXC-InstallExchangeServer.ps1"
# $IP = (Get-AZPublicIPAddress -Name $Pip).IpAddress
# Write-Host "[INFO] Connecting to $($VMName) with IP $IP for Installing Exchange Server 2019"

# Invoke-Command -Computername $IP -ScriptBlock {
#     Param ($fileuri)
#     $OutputFolder = "C:\Temp"
#     if (Test-Path -path $OutputFolder) {
#         #do nothing
#     }
#     else {
#         $Location = $OutputFolder.Split("\")
#         New-Item -Path "$($Location[0])\" -Name $Location[1] -ItemType Directory
#     }
#     $Script = (Invoke-WebRequest -Uri $fileUri -UseBasicParsing).Content
#     $Script | Out-File C:\Temp\script.ps1
#     Start-Process powershell -verb runas -ArgumentList "powershell c:\temp\script.ps1"
#     #powershell C:\temp\script.ps1
#     Remove-Item C:\Temp\script.ps1 -force
# } -Credential $DomainCredential -ArgumentList $fileUri

# Write-Host "[INFO] Restarting $($Vmname) now"
# Restart-AZVM -ResourceGroupName $ResourceGroupName -Name $VMName

# $VMName = $EX
# $Pip = $VMName + "PublicIP"
# $fileUri = "https://raw.githubusercontent.com/GetToThe-Cloud/TUT01-BuildingATestLab/main/Final/04-EXC-ConfigureExchange.ps1"
# $IP = (Get-AZPublicIPAddress -Name $Pip).IpAddress
# Write-Host "[INFO] Connecting to $($VMName) with IP $IP for Configuring Exchange Server 2019"

# Invoke-Command -Computername $IP -ScriptBlock {
#     Param ($fileuri)
#     $OutputFolder = "C:\Temp"
#     if (Test-Path -path $OutputFolder) {
#         #do nothing
#     }
#     else {
#         $Location = $OutputFolder.Split("\")
#         New-Item -Path "$($Location[0])\" -Name $Location[1] -ItemType Directory
#     }
#     $Script = (Invoke-WebRequest -Uri $fileUri -UseBasicParsing).Content
#     $Script | Out-File C:\Temp\script.ps1
#     powershell C:\temp\script.ps1
#     Remove-Item C:\Temp\script.ps1 -force
# } -Credential $Credential -ArgumentList $fileUri

$EndTime = Get-Date
Write-Host "[INFO] End time of script $($Time)"

Clear

Write-Host "  ___       _   _____     _____  _           ___  _                _ "
Write-Host " / __| ___ | |_|_   _|___|_   _|| |_   ___  / __|| | ___  _  _  __| |"
Write-Host "| (_ |/ -_)|  _| | | / _ \ | |  | ' \ / -_)| (__ | |/ _ \| || |/ _` |"
Write-Host " \___|\___| \__| |_| \___/ |_|  |_||_|\___| \___||_|\___/ \_,_|\__,_| "
Write-Host "                                                                     "
Write-Host ""
Write-Host "[INFO] Building a testlab on Azure"
Write-Host ""
Write-Host "Deployment was started at $TimeStart"
write-Host "Deployment was finished at $EndTime"
Write-Host ""
Write-host "-DC01 internal IP: 10.10.0.4"
Write-Host "-AD01 internal IP: 10.10.0.5"
Write-Host "-WIN11 internal IP: 10.10.0.6"
Write-Host ""
Write-Host "Open ports for EX01: 25,80,443"
Write-Host "IP to use for External DNS: $EXIP"
Write-Host ""
Write-Host ""