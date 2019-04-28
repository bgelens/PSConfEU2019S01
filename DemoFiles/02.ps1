# MDB interaction
# this demo only runs on PSv5.1

# Module is already installed
Get-Module -ListAvailable -Name DSCPullServerAdmin

# explore commands
Get-Command -Module DSCPullServerAdmin

# create a connection with mdb
# show the same does not work on psv6
New-DSCPullServerAdminConnection -MDBFilePath .\DemoFiles\Devices.mdb -Verbose

# we are now able to get data out of the mdb
Get-DSCPullServerAdminRegistration
Get-DSCPullServerAdminRegistration -NodeName VM02 -Verbose

Get-DSCPullServerAdminStatusReport | Select-Object -First 1

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
Copy-DSCPullServerAdminData -Connection1 $mdbConnection -Connection2 $sqlConnection -ObjectsToMigrate RegistrationData, StatusReports
