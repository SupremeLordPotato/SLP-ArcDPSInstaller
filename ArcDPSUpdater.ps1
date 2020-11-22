param (
    [Parameter(Mandatory = $true)]
    [String]
    $GW2InstallPath
)

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

Write-Log "Initializing Updater" $LogInfo


$ArcDPSfileURL = "https://www.deltaconnected.com/arcdps/x64/d3d9.dll"
$ArcDPSCheckSumFileURL = "https://www.deltaconnected.com/arcdps/x64/d3d9.dll.md5sum"

$BinFolderPath = "$GW2InstallPath\bin64\"

Write-Log "Parameters:"
Write-Log "`tUrl ArcDPS file:...........$ArcDPSfileURL"
Write-Log "`tUrl ArcDPS checksum file:..$ArcDPSCheckSumFileURL"
Write-Log "`tGuild Wars 2 install path:.$GW2InstallPath"

function installArcDPS{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]
        $InstallFolder
    )
    Write-Log ('Start of function {0}.' -f $MyInvocation.MyCommand) $LogInfo
    
    Write-Log "downloading Arc DPS file" $LogInfo
    Invoke-WebRequest -Uri $ArcDPSfileURL -OutFile "$InstallFolder\Bin64\d3d9.dll"
    
    Write-Log "Downloading Arc DPS checksum file" $LogInfo
    Invoke-WebRequest -Uri $ArcDPSCheckSumFileURL -OutFile "$InstallFolder\Bin64\d3d9.dll.md5sum"
    Write-Log ('End of function {0}.' -f $MyInvocation.MyCommand) $LogInfo
}

function compare-ArcDPSCheckSum{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]
        $InstallFolder,
        # Uri to ArcDPS checksum file
        [Parameter()]
        [String]
        $ArcDPSCheckSumURI = "https://www.deltaconnected.com/arcdps/x64/d3d9.dll.md5sum",
        # Current directory for temporary files
        [Parameter(mandatory)]
        [String]
        $InvocationFolder
    )
    $bIsSame = $false

    Write-Log ('Start of function {0}' -f $MyInvocation.MyCommand) $LogInfo

    Write-Log "Using the following values for parameters:"
        Write-Log "`tInstall Folder:......$InstallFolder"
        Write-Log "`tArcDPSCheckSumURI:...$ArcDPSCheckSumURI"
        Write-Log "`tInvocationFolder:....$InvocationFolder"

    Write-Log "Getting CheckSum from the local installation"
        $installedCheckSum = Get-Content "$InstallFolder\bin64\d3d9.dll.md5sum"

    Write-Log "Getting CheckSum from the server"
        $tempCheckSumPath = "$InvocationFolder\validationCheckSum.md5sum"
        Invoke-WebRequest -Uri $ArcDPSCheckSumURI -OutFile $tempCheckSumPath
        $serverCheckSum = Get-Content $tempCheckSumPath

    Write-Log "Comparing CheckSums:"
        Write-Log "`tCheckSum from server:...............$serverCheckSum"
        Write-Log "`tCheckSum from Local Installation:...$installedCheckSum"

    if($installedCheckSum -eq $serverCheckSum){
        Write-log "Versions are the same"
        $bIsSame = $true
    }
    else{
        Write-Log "Versions are not the same"
        $bIsSame= $false 
    }

    Remove-Item "$tempCheckSumPath"
    Write-Log ('End of function {0}' -f $MyInvocation.MyCommand) $LogInfo
    return $bIsSame
}

#returns true if server date is less than the local file date
#meaning the arc installation is up to date
function compare-ArcCreationTime{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]
        $InstallFolder,
        # Uri to ArcDPS file
        [Parameter()]
        [String]
        $ArcDPSURI = "https://www.deltaconnected.com/arcdps/x64/d3d9.dll"
    )
    Write-Log ('Start of function {0}' -f $MyInvocation.MyCommand) $LogInfo

    Write-Log "Getting the creation date of the server file"
    $ArcServerFileDate = [DateTime](Invoke-WebRequest -Uri $ArcDPSURI).Headers.'Last-Modified'
    
    Write-Log "Getting the creation date of the local file"
    $ArcLocalFileDate = (Get-ChildItem -Path "$InstallFolder\bin64\d3d9.dll").CreationTime

    Write-Log "Verifying creation dates:"
    Write-Log "`tServer File:....$ArcServerFileDate"
    Write-Log "`tLocal File:.....$ArcLocalFileDate"

    if($ArcServerFileDate -lt $ArcLocalFileDate){
        Write-Log ('End of function {0}' -f $MyInvocation.MyCommand) $LogInfo
        return $true
    }
    else{
        Write-Log ('End of function {0}.' -f $MyInvocation.MyCommand) $LogInfo
        return $false
    }
}

Write-Log "checking if checksum file exists" $LogInfo
Try{
    if(!(Test-Path -Path "$BinFolderPath\d3d9.dll.md5sum")){
        Write-Log "if file does not exist check for the dll file instead" $LogInfo
        if(!(Test-Path -Path "$BinFolderPath\d3d9.dll")){
            Write-Log "arcDPS is not installed, installing ArcDPS!" $LogInfo
            installArcDPS -InstallFolder $GW2InstallPath
        }
        else{
            Write-Log "using the creation date of the ArcDPS file. Not the most reliable way, but it will do" $LogInfo
            if(!(compare-ArcCreationTime -InstallFolder $GW2InstallPath)){
                Write-Log "server version is newer, retrieving server file" $LogInfo
                installArcDPS -InstallFolder $GW2InstallPath
            }
            Else{
                Write-Log "ArcDPS is up to date!"
            }
        }
    }
    Else{
        Write-Log "checksum is present, checking if versions match" $LogInfo
        if(!(compare-ArcDPSCheckSum -InstallFolder $GW2InstallPath -InvocationFolder "$(Split-Path $MyInvocation.MyCommand.Path)")){
            Write-Log "versions are not the same we'll need to retrieve the new files!" $LogInfo
            installArcDPS -InstallFolder $GW2InstallPath
        }
        Else{
            Write-Log "ArcDPS is up to date"
        }
    }
}
Catch{
    Write-Log "$_"
}