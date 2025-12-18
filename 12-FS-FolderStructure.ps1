# PowerShell script to create a traditional file share folder structure
# for Projects, Departments, and Home Folders

# Define the root path for the file share
$rootPath = "C:\FileShare"

# Create root directory
New-Item -Path $rootPath -ItemType Directory -Force | Out-Null

# Create main folders
$mainFolders = @("Projects", "Departments", "HomeFolders")

foreach ($folder in $mainFolders) {
    New-Item -Path "$rootPath\$folder" -ItemType Directory -Force | Out-Null
    Write-Host "Created: $rootPath\$folder" -ForegroundColor Green
}

# Create sample project folders
$projects = @("Project_Alpha", "Project_Beta", "Project_Gamma", "Project_Archive")
foreach ($project in $projects) {
    $projectPath = "$rootPath\Projects\$project"
    New-Item -Path $projectPath -ItemType Directory -Force | Out-Null
    
    # Create subfolders within each project
    $projectSubFolders = @("Documents", "Data", "Reports", "Resources")
    foreach ($subFolder in $projectSubFolders) {
        New-Item -Path "$projectPath\$subFolder" -ItemType Directory -Force | Out-Null
    }
    Write-Host "Created: $projectPath with subfolders" -ForegroundColor Green
}

# Create department folders
$departments = @("Finance", "HR", "IT", "Marketing", "Operations", "Sales")
foreach ($dept in $departments) {
    $deptPath = "$rootPath\Departments\$dept"
    New-Item -Path $deptPath -ItemType Directory -Force | Out-Null
    
    # Create subfolders within each department
    $deptSubFolders = @("Shared", "Templates", "Archives", "Reports")
    foreach ($subFolder in $deptSubFolders) {
        New-Item -Path "$deptPath\$subFolder" -ItemType Directory -Force | Out-Null
    }
    Write-Host "Created: $deptPath with subfolders" -ForegroundColor Green
}

# Create sample home folders (typically named by username)
$users = @("jdoe", "asmith", "bwilliams", "mjohnson", "slee")
foreach ($user in $users) {
    $homePath = "$rootPath\HomeFolders\$user"
    New-Item -Path $homePath -ItemType Directory -Force | Out-Null
    
    # Create personal subfolders
    $homeSubFolders = @("Documents", "Desktop", "Downloads")
    foreach ($subFolder in $homeSubFolders) {
        New-Item -Path "$homePath\$subFolder" -ItemType Directory -Force | Out-Null
    }
    Write-Host "Created: $homePath with subfolders" -ForegroundColor Green
}

Write-Host "`nFolder structure created successfully at: $rootPath" -ForegroundColor Cyan
Write-Host "To view the structure, run: tree $rootPath /F" -ForegroundColor Yellow
