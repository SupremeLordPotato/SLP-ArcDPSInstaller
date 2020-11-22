function Write-Log {
    param ($Message, $Status = $LogInfo)

    trap [Exception] {Write-Host "Critical - Unable to use logging system: " + $_.Exception.Message; Stop }
    $timestamp = get-date -uformat "%d/%m/%Y-%T"
    Write-Host "$timestamp " -NoNewline
    
    switch($Status) {
        "DISP" { 
            Write-Host -ForegroundColor Green "[OK] " -NoNewline
            }
        "INFO" { 
            Write-Host -ForegroundColor Green "[OK] " -NoNewline
            Add-Content $LogFile "$timestamp [OK] $Message"
            }
        "WARN" { 
            Write-Host -ForegroundColor Yellow "[WARNING] " -NoNewline
            Add-Content $LogFile "$timestamp [WARNING] $Message"
            } 
        "ERROR" { 
            Write-Host -ForegroundColor Red "[ERROR] " -NoNewline
            Add-Content $LogFile "$timestamp [ERROR] $Message"
            } 
         default { 
            Write-Host -ForegroundColor Green "[$Status] " -NoNewline
            Add-Content $LogFile "$timestamp [$Status] $Message"
            }
        }
    Write-Host $Message
}

#log file location
$LogFile = join-Path(Split-Path $MyInvocation.MyCommand.Path) $MyInvocation.MyCommand.Name.Replace(".ps1", ".log")
$LogInfo = "INFO"
$LogError = "ERROR"
$LogWarning = "WARN"
$LogDisplay = "DISP"

if(Test-Path $LogFile) { Clear-Content $LogFile }
Write-Log "--------------------------------------------------------------" $LogInfo
Write-Log "                        _____ __    ____                      " $LogInfo
Write-Log "                       / ___// /   / __ \                     " $LogInfo
Write-Log "                       \__ \/ /   / /_/ /                     " $LogInfo
Write-Log "                      ___/ / /___/ ____/                      " $LogInfo
Write-Log "                     /____/_____/_/                           " $LogInfo
Write-Log "--------------------------------------------------------------" $LogInfo
Write-Log "Initializing..." $LogInfo

if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Log "Insufficient permissions to run this script. Open the PowerShell console as an administrator and run this script again." $LogError
    Write-Log "This script needs administrator permissions to create Scheduled tasks for the update component." $LogError
    Write-Log "redirecting to an elevated Powershell window. you may need to press enter twice dependend on the focused window" $LogError
    Pause
    $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
    Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
    Exit
}
else {
    Write-Log "Script is running as administrator, continuing the script!" $LogInfo
}

Write-Log "Finding GW2 installation, hang on..." $LogInfo

$ArcDPSfileURL = "https://www.deltaconnected.com/arcdps/x64/d3d9.dll"
$ArcDPSCheckSumFileURL = "https://www.deltaconnected.com/arcdps/x64/d3d9.dll.md5sum"

#Getting the installation 
$GW2InstallationPath
if(!(Test-Path -Path "$env:ProgramFiles\Guild Wars 2")){
    Write-Log "Guild Wars 2 is not installed in the default directory, checking the other program files folder" $LogInfo
    if(!(Test-Path -Path "${env:ProgramFiles(x86)}\Guild Wars 2")){
        Write-Log "Could not find a Guild wars 2 installation in the standard folders, please provide the installation path manually!" $LogInfo
        $GW2InstallationPath = Read-Host "Please enter the installation path for guild wars"
    }
    Else{
        Write-Log "found Gw2 installation in ${env:ProgramFiles(x86)}!" $LogInfo
        $GW2InstallationPath = "${env:ProgramFiles(x86)}\Guild Wars 2"
    }
}
Else{
    Write-Log "found Gw2 installation in $env:ProgramFiles!"
    $GW2InstallationPath = "$env:ProgramFiles\Guild Wars 2"
}
Write-Host (Split-Path $MyInvocation.MyCommand.Path)
$BinFolderPath = "$GW2InstallationPath\bin64"
#detecting Bin Folder
Write-Log "Verifying existence of bin folder..." $LogInfo
if(!(Test-Path -Path $BinFolderPath)){
    Write-Log "Could not find the bin64 folder in the GW2 installation folder!" $LogInfo
    Write-Log "Please make sure you have entered the folder name in which the GW2 executable is located" $LogInfo
    Write-Log "Aborting!" $LogInfo
    Exit
}
Else{
    Write-Log "Found the folder!" $LogInfo
}

#Checking if file exists
Write-Log "Checking for ArcDPS file" $LogInfo
if(Test-Path -Path "$BinFolderPath\d3d9.dll"){
    Write-Log "File already exists!" $LogInfo
    Write-Log "Skipping installation step..." $LogInfo
}
Else{
    Try{
        Write-Log "File not found, ArcDPS must not have been installed yet!" $LogInfo
        Write-Log "Lets change that!" $LogInfo
        Invoke-WebRequest -Uri $ArcDPSfileURL -OutFile "$BinFolderPath\d3d9.dll"
        Write-Log "Adding the checksum for good measure, please do not delete this file!" $LogInfo
        Invoke-WebRequest -Uri $ArcDPSCheckSumFileURL -OutFile "$BinFolderPath\d3d9.dll.md5sum"
    }
    catch{
        Write-Log "$_"
        Write-Log "Something went wrong."
    }
}

#installing auto-update feature
try {
    Write-Log "creating a folder containing the ArcDPS updater script" $LogInfo
    if(!(Test-Path -Path "$GW2InstallationPath\SLPScript")){
        mkdir -Path "$GW2InstallationPath\SLPScript"
    }
    Else{
        Write-Log "folder already exists!"
    }

    Write-Log "copying script to the destination folder" $LogInfo
    Copy-Item -Path "$(Split-Path $MyInvocation.MyCommand.Path)\ArcDPSUpdater.ps1" -Destination "$GW2InstallationPath\SLPScript"
}
catch {
    Write-Log "Something went wrong when creating the folder. Check access rights" $LogError
    Write-Log "This script will continue with the installation, please manually create a folder with the name SLPScript" $LogError
    Write-Log "and copy the ArcDPSUpdate.ps1 into that folder!" $LogError
    Write-Log "$_" $LogError
}

Write-Log "Setting up scheduled task" $LogInfo

    $TaskName = "SLP - ArcDPS Update"
    $taskExists = Get-ScheduledTask | Where-Object {$_.TaskName -like $taskName }
    
    if(!($taskExists)){
        $taskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -command `"& `'$GW2InstallationPath\SLPScript\ArcDPSUpdater.ps1`' -GW2InstallPath `'$GW2InstallationPath`'`""
        $taskTrigger = New-ScheduledTaskTrigger -AtLogOn

        $scheduledtask = New-ScheduledTask -Action $taskAction -Trigger $taskTrigger
        Write-Log "Registering scheduled task:..."
        try {
            Register-ScheduledTask -TaskName $TaskName -InputObject $scheduledtask
        }
        catch {
            Write-Log "$_" $LogInfo
        }
        Write-Log "task successfuly registered!"
    }
    Else{
        Write-Log "Task Already exists!"
    }
Write-Log "ArcDPS will now check and update if needed everytime you login."
Write-Log "To stop the auto-update, disable the scheduled task in the Task Scheduler, it should be called SLP - ArcDPS Update"
Write-Log "This log file is available at $LogFile"
Write-Log "This script was writen by SupremeLordPotato"
Pause