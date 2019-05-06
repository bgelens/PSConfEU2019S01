<#
    SQL interaction

    now that we have seen the how the module works with MDB and EDB, we move to SQL.
    the DB type does not impact the module user ux besides specifying MDB/ESE FilePath or SQLServer

    this all works on Windows PowerShell, PowerShell Core on Windows and Linux
#>

# SQL pull server is already installed
appcmd.exe list site

# start SQL pull server
appcmd start apppool /apppool.name:SQL
appcmd start site /site.name:SQLPullServer

# see that we use locally installed SQL Express
([xml](Get-Content -Path C:\inetpub\SQLPullServer\web.config)).configuration.appsettings.GetEnumerator()

# create connection with SQL DB (note that default db name is DSC if not provided in connectionstring)
New-DSCPullServerAdminConnection -SQLServer localhost -Credential sa | Tee-Object -Variable sql

# we have 2 connections, ESE is active meaning all calls will go there unless connection parameter is uses
Get-DSCPullServerAdminConnection

# see that SQL currently doesn't have any nodes
Get-DSCPullServerAdminRegistration -Connection $sql

# see that LCM is unable to get config
$lcmSession | Enter-PSSession
Update-DscConfiguration -Wait -Verbose
Exit-PSSession

# copy data from edb to sql
Copy-DSCPullServerAdminData -Connection1 (Get-DSCPullServerAdminConnection -OnlyShowActive) -Connection2 $sql -ObjectsToMigrate RegistrationData

Get-DSCPullServerAdminRegistration -Connection $sql -Verbose

# see that LCM is able to get config
$lcmSession | Enter-PSSession
Update-DscConfiguration -Wait -Verbose
Exit-PSSession

# see that we can live update the configuration name (no downtime needed!)
configuration PSCONFEU2019 {
    Node JustAnotherConfig {
        File just_a_file {
            Ensure          = 'Present'
            Type            = 'File'
            DestinationPath = 'c:\just_another_file.txt'
            Contents        = 'PSCONFEU is AWESOME!'
        }
    }
}

PSCONFEU2019 -OutputPath C:\pullserver\Configuration
New-DscChecksum -Path C:\pullserver\Configuration\JustAnotherConfig.mof -Force

Get-DSCPullServerAdminRegistration -NodeName wslcm -Connection $sql |
    Set-DSCPullServerAdminRegistration -ConfigurationNames 'JustAnotherConfig' -Verbose

Get-DSCPullServerAdminRegistration -Connection $sql -NodeName wslcm

# see that LCM is able to get the newly assigned config
$lcmSession | Enter-PSSession
Update-DscConfiguration -Wait -Verbose
Get-Content -Path C:\just_another_file.txt
Exit-PSSession

<# sql connections also work on linux (F8 doesn't work)
    ubuntu.exe
    pwsh
    $PSVersionTable
    New-DSCPullServerAdminConnection -SQLServer localhost -Credential sa
    Get-DSCPullServerAdminRegistration
    Get-DSCPullServerAdminStatusReport
    exit
    exit
#>
