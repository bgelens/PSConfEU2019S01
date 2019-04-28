param (
    [switch] $CopyDemoOnly,

    [string] $UserName,

    [string] $UserPassword
)

# disable servermanager
$null = Get-ScheduledTask -TaskName servermanager | Disable-ScheduledTask

# download demo files
Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/bgelens/PSConfEU2019S01/archive/master.zip' -OutFile $env:TEMP\master.zip
Expand-Archive -Path $env:TEMP\master.zip -DestinationPath c:\Users\Public\Desktop -Force

# disable firewall
Get-NetFirewallProfile | Set-NetFirewallProfile -Enabled False

if ($CopyDemoOnly) {
    return
}

$cred = [pscredential]::new($UserName, (ConvertTo-SecureString -AsPlainText -Force -String $UserPassword))

$ProgressPreference = 'SilentlyContinue'

# bootstrap powershellget
Install-PackageProvider -Name powershellget -Force -ForceBootstrap

# install dscpullserveradmin
Install-Module -Name DSCPullServerAdmin -Scope AllUsers -Force

# install xPSDSC
Install-Module -Name xPSDesiredStateConfiguration -Scope AllUsers -Force

# download sql 2017 express setup file
$sqlExpressUri = 'https://download.microsoft.com/download/5/E/9/5E9B18CC-8FD5-467E-B5BF-BADE39C51F73/SQLServer2017-SSEI-Expr.exe'
Invoke-WebRequest -Uri $sqlExpressUri -UseBasicParsing -OutFile "$env:TEMP\SQLServer2017-SSEI-Expr.exe"

# write configuration ini
@'
[OPTIONS]
ROLE="AllFeatures_WithDefaults"
ENU="True"
FEATURES=SQLENGINE
INSTANCENAME="MSSQLSERVER"
INSTANCEID="MSSQLSERVER"
SECURITYMODE="SQL"
ADDCURRENTUSERASSQLADMIN="True"
TCPENABLED="1"
SAPWD="Welkom01"
'@ | Out-File -FilePath c:\Configuration.ini -Force

# download setupfiles
Start-Process -FilePath "$env:TEMP\SQLServer2017-SSEI-Expr.exe" -ArgumentList @(
    '/Action=Download',
    '/Quiet',
    '/MEDIAPATH=c:\Windows\TEMP'
) -Wait

# extract setupfiles
Start-Process -FilePath "C:\Windows\Temp\sqlexpr_x64_enu.exe" -ArgumentList @(
    '/x:c:\setup /q'
) -Wait
 
# install sql 2017 (this will take some time!)
Start-Process -FilePath "c:\setup\setup.exe" -ArgumentList @(
    '/ACTION="Install"'
    '/ConfigurationFile=C:\Configuration.ini',
    '/IAcceptSqlServerLicenseTerms',
    '/QUIET'
) -Wait

# create PullServer directory
New-Item -Path c:\pullserver -ItemType Directory -Force

# create registrationkey file
New-Item -Path C:\pullserver -Name 'RegistrationKeys.txt' -Value 'cb30127b-4b66-4f83-b207-c4801fb05087' -ItemType File

Import-Module WebAdministration

# remove default website
Get-Website -Name 'Default Web Site' | Remove-Website

# install EDB Pull Server
Invoke-DscResource -ModuleName xPSDesiredStateConfiguration -Name xDscWebService -Method Set -Property @{
    Ensure                       = 'Present'
    EndpointName                 = 'EDBPullServer'
    Port                         = 8080
    PhysicalPath                 = "$env:SystemDrive\inetpub\EDBPullServer"
    CertificateThumbPrint        = 'AllowUnencryptedTraffic'
    ModulePath                   = "c:\pullserver\Modules"
    ConfigurationPath            = "c:\pullserver\Configuration"
    DatabasePath                 = "c:\pullserver" 
    State                        = 'Started'
    RegistrationKeyPath          = "c:\pullserver"
    UseSecurityBestPractices     = $false
}

$edbAP = New-Item -Path IIS:\AppPools\EDB
$edbAP.processModel.identityType = 'LocalSystem'
$edbAP | Set-Item
$null = Set-ItemProperty "IIS:\Sites\EDBPullServer" -Name ApplicationPool -Value EDB
Remove-Item IIS:\AppPools\PSWS -Force -Recurse

# create edb
$uri = 'http://localhost:8080/PSDSCPullServer.svc'
$irmArgs = @{
    Headers = @{
        Accept = 'application/json'
        ProtocolVersion = '2.0'
    }
    UseBasicParsing = $true
}
Invoke-RestMethod @irmArgs -Uri $uri

# stop website
Get-Website -Name "EDBPullServer" | Stop-Website -ErrorAction SilentlyContinue

# install SQL Pull Server
Invoke-DscResource -ModuleName xPSDesiredStateConfiguration -Name xDscWebService -Method Set -Property @{
    Ensure                       = 'Present'
    EndpointName                 = 'SQLPullServer'
    Port                         = 8081
    PhysicalPath                 = "$env:SystemDrive\inetpub\SQLPullServer"
    CertificateThumbPrint        = 'AllowUnencryptedTraffic'
    ModulePath                   = "c:\pullserver\Modules"
    ConfigurationPath            = "c:\pullserver\Configuration"
    DatabasePath                 = "c:\pullserver" 
    State                        = 'Started'
    RegistrationKeyPath          = "c:\pullserver"
    UseSecurityBestPractices     = $false
    SqlProvider                  = $true
    SqlConnectionString          = 'Provider=SQLOLEDB.1;Server=localhost;User ID=sa;Password=Welkom01;Initial Catalog=master;'
}

$sqlAP = New-Item -Path IIS:\AppPools\SQL
$sqlAP.processModel.identityType = 'LocalSystem'
$sqlAP | Set-Item
$null = Set-ItemProperty "IIS:\Sites\SQLPullServer" -Name ApplicationPool -Value SQL
Remove-Item IIS:\AppPools\PSWS -Force -Recurse

# set binding to 8080
Set-WebBinding -Name SQLPullServer -BindingInformation "*:8081:" -PropertyName Port -Value 8080

# create db
$uri = 'http://localhost:8080/PSDSCPullServer.svc'
$irmArgs = @{
    Headers = @{
        Accept = 'application/json'
        ProtocolVersion = '2.0'
    }
    UseBasicParsing = $true
}
Invoke-RestMethod @irmArgs -Uri $uri

# stop all websites
Get-Website | Stop-Website -ErrorAction SilentlyContinue

# install ubuntu
Invoke-WebRequest -Uri https://aka.ms/wsl-ubuntu-1804 -OutFile Ubuntu.zip -UseBasicParsing
Expand-Archive ./Ubuntu.zip C:/Ubuntu
$machineenv = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
[System.Environment]::SetEnvironmentVariable("PATH", $machineenv + ";C:\Ubuntu", "Machine")
New-Item -Path C:\Ubuntu -Name ubuntu.exe -ItemType SymbolicLink -Value C:\Ubuntu\ubuntu1804.exe

# wsl needs to have been installed and system has to be rebooted for this to work
Invoke-Command -Credential $cred -ComputerName . -ScriptBlock {
    & c:\ubuntu\ubuntu.exe install --root
    & c:\ubuntu\ubuntu.exe run wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb
    & c:\ubuntu\ubuntu.exe run dpkg -i packages-microsoft-prod.deb
    & c:\ubuntu\ubuntu.exe run apt-get update
    & c:\ubuntu\ubuntu.exe run add-apt-repository universe
    & c:\ubuntu\ubuntu.exe run apt-get install -y powershell

    & c:\ubuntu\ubuntu.exe run pwsh -NoProfile -Command Install-Module DSCPullServerAdmin -Force
}

# install pwsh on windows using msi install
Invoke-WebRequest -UseBasicParsing -Uri https://github.com/PowerShell/PowerShell/releases/download/v6.2.0/PowerShell-6.2.0-win-x64.msi -OutFile $env:TEMP\PowerShell-6.2.0-win-x64.msi
Start-Process -Wait -ArgumentList "/package $env:TEMP\PowerShell-6.2.0-win-x64.msi /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1" -FilePath msiexec.exe

# install dscpullserveradmin on pwsh
& 'C:\Program Files\PowerShell\6\pwsh.exe' -NoProfile -Command Install-module DSCPullServerAdmin -Scope AllUsers -Force

# install vs code
Invoke-WebRequest -UseBasicParsing -Uri https://go.microsoft.com/fwlink/?Linkid=852157 -OutFile $env:TEMP\vscodesetup.exe
Start-Process -Wait -ArgumentList '/VERYSILENT /MERGETASKS=!runcode' -FilePath $env:TEMP\vscodesetup.exe


# add appcmd to path
$machineenv = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
[System.Environment]::SetEnvironmentVariable("PATH", $machineenv + ";c:\Windows\System32\inetsrv", "Machine")

# add shortcuts to desktop
New-Item -Path c:\Users\Public\Desktop -Name pwsh.lnk -ItemType SymbolicLink -Value 'C:\Program Files\PowerShell\6\pwsh.exe'
New-Item -Path c:\Users\Public\Desktop -Name vscode.lnk -ItemType SymbolicLink -Value 'C:\Program Files\Microsoft VS Code\Code.exe'
New-Item -Path c:\Users\Public\Desktop -Name ubuntu.lnk -ItemType SymbolicLink -Value 'C:\Ubuntu\ubuntu.exe'

# restart
shutdown /r /t 30
