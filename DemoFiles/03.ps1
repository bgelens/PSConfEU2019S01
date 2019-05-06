<#
    EDB interaction

    now that we have seen the how the module works with MDB, we move to EDB.
    the DB type does not impact the module user ux besides specifying MDB/ESE FilePath or SQLServer

    this all works on Windows PowerShell but we switch to PSV6
#>

# psversion
$PSVersionTable

# little follow up that MDB is not accessible from PSv6
New-DSCPullServerAdminConnection -MDBFilePath .\DemoFiles\Devices.mdb

# where is the edb located? (pretent you didn't see it before :))
([xml](Get-Content -Path C:\inetpub\EDBPullServer\web.config)).configuration.appsettings.GetEnumerator()

# use DSCPullServerAdmin to work with edb
New-DSCPullServerAdminConnection -ESEFilePath C:\pullserver\Devices.edb -Verbose

# unlock the file... this is the number one reason to move to SQL (besides that SQL brings scalability and high availability of course :))
appcmd stop site /site.name:EDBPullServer
appcmd stop apppool /apppool.name:EDB

# try again (note the verbose output, EDB is checked for correct tables)
New-DSCPullServerAdminConnection -ESEFilePath C:\pullserver\Devices.edb -Verbose

# we can get the node that was registered in first demo and the one that was copied in using the mdb demo
Get-DSCPullServerAdminRegistration

# let's adjust wslcm configuration name and have the node converge
configuration PSCONFEU {
    Node JustAConfig {
        File just_a_file {
            Ensure          = 'Present'
            Type            = 'File'
            DestinationPath = 'c:\just_a_file.txt'
            Contents        = 'PSCONFEU is AWESOME!'
        }
    }
}

PSCONFEU -OutputPath C:\pullserver\Configuration
New-DscChecksum -Path C:\pullserver\Configuration\JustAConfig.mof -Force

# now update the config assigned
Get-DSCPullServerAdminRegistration -NodeName wslcm | Set-DSCPullServerAdminRegistration -ConfigurationNames 'JustAConfig'
Get-DSCPullServerAdminRegistration -NodeName wslcm

# start the pull server
appcmd start apppool /apppool.name:EDB
appcmd start site /site.name:EDBPullServer

# move to node
$lcmSession | Enter-PSSession

# check local config (see no config name)
Get-DscLocalConfigurationManager | Select-Object -ExpandProperty ConfigurationDownloadManagers

# update (picks up server side config)
Update-DscConfiguration -Wait -Verbose

# check the file
Get-Content -Path C:\just_a_file.txt

Exit-PSSession

# stop the pull server so we can access the status reports
appcmd stop site /site.name:EDBPullServer
appcmd stop apppool /apppool.name:EDB

Get-DSCPullServerAdminStatusReport -OperationType Consistency -NodeName wslcm

<# see edb is not accessible from linux (F8 doesn't work)
    ubuntu.exe
    pwsh
    $PSVersionTable
    New-DSCPullServerAdminConnection -ESEFilePath /mnt/c/pullserver/Devices.edb
    exit
    exit
#>
