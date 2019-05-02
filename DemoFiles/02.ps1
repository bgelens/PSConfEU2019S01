# MDB interaction
# this demo only runs on PSv5.1

$psv5 = New-PSSession -ComputerName localhost
Invoke-Command -Session $psv5 -ScriptBlock { Set-Location -Path $using:pwd}
$psv5 | Enter-PSSession

# psversion
$PSVersionTable

# Module is already installed
Get-Module -ListAvailable -Name DSCPullServerAdmin

# explore commands
Get-Command -Module DSCPullServerAdmin

# create a connection with mdb
New-DSCPullServerAdminConnection -MDBFilePath .\DemoFiles\Devices.mdb -Verbose

# we are now able to get data out of the mdb
Get-DSCPullServerAdminRegistration
Get-DSCPullServerAdminRegistration -NodeName VM02 -Verbose

Get-DSCPullServerAdminStatusReport | Select-Object -First 1

<# more options:
    Get LCM reports from 2 hours ago until now
    Get-DSCPullServerAdminStatusReport -OperationType LocalConfigurationManager -FromStartTime ([datetime]::Now.AddHours(-2))

    remove everything that is older than 7 days
    Get-DSCPullServerAdminStatusReport -OperationType All -ToStartTime ([datetime]::Now.AddDays(-7)) |
        Remove-DSCPullServerAdminStatusReport -Confirm:$false

    try to do this using the pull server rest api ;)
#>

# we can set data
Get-DSCPullServerAdminRegistration -NodeName VM02 | Set-DSCPullServerAdminRegistration -ConfigurationNames PSConfEU -WhatIf
Get-DSCPullServerAdminRegistration -NodeName VM02 | Set-DSCPullServerAdminRegistration -ConfigurationNames PSConfEU

Get-DSCPullServerAdminRegistration -NodeName VM02

# we can create new data which is great to pre-register nodes (they don't need registration key if they are already known)
New-DSCPullServerAdminRegistration -AgentId ([guid]::NewGuid()) -LCMVersion 2.0 -NodeName PSCONFEU01 -IPAddress 192.168.0.1 -ConfigurationNames PSCONFEU
Get-DSCPullServerAdminRegistration -NodeName PSCONFEU01

# we can remove data
Get-DSCPullServerAdminRegistration -NodeName PSCONFEU01 | Remove-DSCPullServerAdminRegistration -WhatIf
Get-DSCPullServerAdminRegistration -NodeName PSCONFEU01 | Remove-DSCPullServerAdminRegistration

Get-DSCPullServerAdminRegistration

# we can copy data out of (or in to) mdb to edb / sql (migrate to other DB type)
Get-DSCPullServerAdminConnection
$mdbConnection = Get-DSCPullServerAdminConnection -OnlyShowActive
$edbConnection = New-DSCPullServerAdminConnection -ESEFilePath C:\pullserver\Devices.edb

Copy-DSCPullServerAdminData -Connection1 $mdbConnection -Connection2 $edbConnection -ObjectsToMigrate RegistrationData -WhatIf
Copy-DSCPullServerAdminData -Connection1 $mdbConnection -Connection2 $edbConnection -ObjectsToMigrate RegistrationData

# this also works the other way around
Copy-DSCPullServerAdminData -Connection1 $edbConnection -Connection2 $mdbConnection -ObjectsToMigrate RegistrationData -Verbose
Get-DSCPullServerAdminRegistration -Connection $mdbConnection
Get-DSCPullServerAdminRegistration -Connection $edbConnection

# start the pull server and see that VM02 is available
appcmd start apppool /apppool.name:EDB
appcmd start site /site.name:EDBPullServer

$irmArgs = @{
    Headers         = @{
        Accept          = 'application/json'
        ProtocolVersion = '2.0'
    }
    UseBasicParsing = $true
}
$uri = "http://localhost:8080/PSDSCPullServer.svc/Nodes(AgentId = 'da773f3c-6600-11e9-a3df-00155d006e03')" 
Invoke-RestMethod @irmArgs -Uri $uri

# just migrated from mdb to edb! We can also move status reports if desired but registration is the key for migrating nodes to another pull server

Exit-PSSession
