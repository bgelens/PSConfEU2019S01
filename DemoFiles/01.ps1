# show multiple pull servers are installed
appcmd.exe list site

# start edb pull server
appcmd start apppool /apppool.name:EDB
appcmd start site /site.name:EDBPullServer

# connect with LCM node
$cred = Get-Credential -UserName dscadmin
Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value '*' -Force
$lcmSession = New-PSSession -ComputerName wslcm -Authentication Negotiate -Credential $cred
$lcmSession | Enter-PSSession

# node is currently not onboarded
Get-DscLocalConfigurationManager

# onboard node
[dsclocalconfigurationmanager()]
configuration lcm {
    Settings {
        RefreshMode = 'Pull'
    }

    ConfigurationRepositoryWeb PullWeb {
        ServerURL               = 'http://wspull:8080/PSDSCPullServer.svc'
        RegistrationKey         = 'cb30127b-4b66-4f83-b207-c4801fb05087'
        AllowUnsecureConnection = $true
    }

    ReportServerWeb PullWeb {
        ServerURL               = 'http://wspull:8080/PSDSCPullServer.svc'
        RegistrationKey         = 'cb30127b-4b66-4f83-b207-c4801fb05087'
        AllowUnsecureConnection = $true
    }
}
lcm
Set-DscLocalConfigurationManager .\lcm -Verbose

Exit-PSSession

# query rest api
$uri = 'http://localhost:8080/PSDSCPullServer.svc'

$irmArgs = @{
    Headers         = @{
        Accept          = 'application/json'
        ProtocolVersion = '2.0'
    }
    UseBasicParsing = $true
}
# available routes
(Invoke-RestMethod @irmArgs -Uri $uri).value

# Get node object, you need the agentid for this, no get all, list, wildcard
Invoke-Command -Session $lcmSession -ScriptBlock { (Get-DscLocalConfigurationManager).AgentId } | Tee-Object -Variable agentId

$uri = "http://localhost:8080/PSDSCPullServer.svc/Nodes(AgentId = '$agentId')" 
Invoke-RestMethod @irmArgs -Uri $uri | Tee-Object -Variable node

# Get node reports
$uri = "http://localhost:8080/PSDSCPullServer.svc/Nodes(AgentId = '$agentId')/Reports"
$reports = (Invoke-RestMethod @irmArgs -Uri $uri).value
$reports[0]
$reports[0].StatusData | ConvertFrom-Json

# Update configurationname (basically re-registration)
$registrationKey = Get-Content C:\pullserver\RegistrationKeys.txt

$putArgs = @{
    Headers         = @{
        Accept          = 'application/json'
        ProtocolVersion = '2.0'
        Authorization   = 'Basic {0}' -f [Convert]::ToBase64String(
            [System.Text.Encoding]::Default.GetBytes($registrationKey)
        )
    }
    UseBasicParsing = $true
}
$node.psobject.members.Remove('odata.metadata')
$node.ConfigurationNames = @('PSCONFEU')
$node.RegistrationInformation.RegistrationMessageType = 'ConfigurationRepository'
$node

$uri = "http://localhost:8080/PSDSCPullServer.svc/Nodes(AgentId = '$agentId')" 
Invoke-RestMethod @putArgs -Uri $uri -Method Put -Body ($node | ConvertTo-Json) -ContentType 'application/json'

#check if it's updated
Invoke-RestMethod @irmArgs -Uri $uri

#reset to null
$node.ConfigurationNames = @()
Invoke-RestMethod @putArgs -Uri $uri -Method Put -Body ($node | ConvertTo-Json) -ContentType 'application/json'

# inflexible, not admin friendly. Requires some sort of shadow administration

# stop the pull server for now
appcmd stop site /site.name:EDBPullServer
appcmd stop apppool /apppool.name:EDB