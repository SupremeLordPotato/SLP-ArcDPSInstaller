# SLP-ArcDPSInstaller
A script to install ArcDPS and automatically update it at logon.
## Using the script
1. First, extract the files
2. In the folder with the extracted files, right click on ArcDPSInstaller.ps1
3. In the context menu, click on run with powershell.
4. follow the instructions on screen
## What it does
This script has 2 parts, 1 is the installation of ArcDPS and 2 is the installation of the update mechanism.##
### 1. Installing ArcDPS
1. Firstly, the script will check for the GW2 install location, if it cannot find the folder please provide the folder name containing the bin64 folder
2. Next, it will check if the files are already installed.
3. If the files are not already installed, the script will download the files and put them in the bin64 folder.
### 2. Installing the update mechanism
1. After installing ArcDPS, the script will install the update mechanism.
2. The script will create a new folder in the GW2 installation location, aptly named SLPScript.
3. In there it will put the ArcDPSUpdater.ps1 script, this script is what will handle the updateing of ArcDPS.
4. The installer script will create a new scheduled task with the ArcDPSUpdater.ps1 script as the executing script.
#### Task properties
- Scheduled Task name : SLP - ArcDPS Update
- Trigger             : At log on of any user
- Action              : start a program; powershell.exe -ExecutionPolicy Bypass -command "& '$GW2InstallationPath\SLPScript\ArcDPSUpdater.ps1' -GW2InstallPath '$GW2InstallationPath'"
