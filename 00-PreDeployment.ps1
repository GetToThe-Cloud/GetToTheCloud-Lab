##### Getting Windows Powershell 7.x

$fileuri = "https://github.com/PowerShell/PowerShell/releases/download/v7.2.3/PowerShell-7.2.3-win-x64.msi"
$name = $fileuri.Split("/")
$Count = $Name.Count -1
$name = $name[$count]
$OutputFolder = "C:\Temp"
$ProgressPreference = 'SilentlyContinue'

if (Test-Path -path $OutputFolder) {
    #do nothing
}
else {
    $Location = $OutputFolder.Split("\")
    try {
    $create = New-Item -Path "$($Location[0])\" -Name $Location[1] -ItemType Directory
    Write-Host "[SUCCESS] Folder $($OutputFolder) is created" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Cannot create folder $($OutputFolder)" -ForegroundColor Red
        break
    }
}

Write-Host "[INFO] downloading $($Name)"
Try {
    Invoke-Restmethod -uri $fileUri -OutFile "$Outputfolder\$name"
    Write-Host "[SUCCESS] file $($Name) is downloaded" -ForegroundColor green
}
Catch {
    Write-Host "[ERROR] something went wrong downloading $($Name)" -ForegroundColor Red
}

$checkiffileexists = Get-ChildItem $OutputFolder
$File = $checkiffileexists | where-Object {$_.Name -eq $name}
if (!($File)){
    Write-Host "[ERROR] there is no file like $($name)" -ForegroundColor Red
    break
}
else {
    Write-Host "[INFO] installing $($Name)"
    Start-Process "cmd.exe" -verb runas -ArgumentList "/c MsiExec.exe /i $Outputfolder\$name.msi /qn" 
}