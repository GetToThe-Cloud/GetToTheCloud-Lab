##### Getting Windows Powershell 7.x
$repo = "PowerShell/PowerShell"
$releases = "https://api.github.com/repos/$repo/releases"

Write-Host "[INFO] Determining latest release"
$tag = (Invoke-WebRequest $releases | ConvertFrom-Json)[0].tag_name

$file = "Powershell-"+ $Tag.Split("v")[1] + "-win-x64.msi"
$fileuri = "https://github.com/$repo/releases/download/$tag/$file"
$name = $fileuri.Split("/")
$Count = $Name.Count - 1
$name = $name[$count]
$OutputFolder = $env:temp
$ProgressPreference = 'SilentlyContinue'
$versionfolder = $tag.split("v")[1].split(".")[0]
$Path = "C:\Program Files\PowerShell\$versionfolder\pwsh.exe"

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
if (Test-Path -path $path) {
    $version = (get-item $path).VersionInfo.fileversion.Split(".")
    $version = $version[0] + "." + $version[1] + "." + $version[2]
    Write-Host "[ERROR] allready found a version with number $version" -ForegroundColor Red
    Write-Host "[INFO] checking if newer version is requested "
    if ($($name.Split("-")[1]) -eq $version) {
        Write-Host "[INFO] same version is requested"
        break
    }
    elseif ($version -gt $($name.Split("-")[1])) {
        Write-Host "[WARNING] a newer version is allready installed" -ForegroundColor Yellow
        break
    }
    elseif ($version -lt $($name.Split("-")[1])) {
        Write-Host "[WARNING] a newer version will be installed $($name.Split("-")[1])" -ForegroundColor Yellow
       
    } 
}
else {
    Write-Host "[INFO] PWSH.EXE is not found. Downloading now ..." -ForegroundColor green
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
$File = $checkiffileexists | where-Object { $_.Name -eq $name }
if (!($File)) {
    Write-Host "[ERROR] there is no file like $($name)" -ForegroundColor Red
    break
}
else {
    Write-Host "[INFO] installing $($Name)"
    MsiExec.exe /i "$Outputfolder\$name" /qn
    Do {
        $test = Test-Path $path
        Write-Host "[INFO] Waiting for completion ... "
        Start-Sleep 2
    }
    until ($Test)
    Write-Host "[SUCCESS] $($File) is installed" -ForegroundColor Green
}