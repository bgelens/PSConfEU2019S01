param (
    [switch] $CopyDemoOnly
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

# bootstrap powershellget
Install-PackageProvider -Name powershellget -Force -ForceBootstrap

# install dscpullserveradmin
Install-Module -Name DSCPullServerAdmin -Scope AllUsers -Force

# install xPSDSC
Install-Module -Name xPSDesiredStateConfiguration -Scope AllUsers -Force

# install dsc-service
Install-WindowsFeature -Name Dsc-Service, Web-Mgmt-Console

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

Get-Item -Path IIS:\AppPools\PSWS | Rename-Item -NewName EDB
$null = Set-ItemProperty "IIS:\Sites\EDBPullServer" -Name ApplicationPool -Value EDB

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

Get-Item -Path IIS:\AppPools\PSWS | Rename-Item -NewName SQL
$null = Set-ItemProperty "IIS:\Sites\SQLPullServer" -Name ApplicationPool -Value SQL

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

# stop website
Get-Website -Name "SQLPullServer" | Stop-Website -ErrorAction SilentlyContinue

# install wsl
Install-WindowsFeature -Name Microsoft-Windows-Subsystem-Linux

Invoke-WebRequest -Uri https://aka.ms/wsl-ubuntu-1804 -OutFile Ubuntu.zip -UseBasicParsing
Expand-Archive ./Ubuntu.zip C:/Ubuntu
$machineenv = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
[System.Environment]::SetEnvironmentVariable("PATH", $machineenv + ";C:\Ubuntu", "Machine")
New-Item -Path C:\Ubuntu -Name ubuntu.exe -ItemType SymbolicLink -Value C:\Ubuntu\ubuntu1804.exe