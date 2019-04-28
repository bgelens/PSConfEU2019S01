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
        ServerURL = 'http://wspull:8080/PSDSCPullServer.svc'
        RegistrationKey = 'cb30127b-4b66-4f83-b207-c4801fb05087'
        AllowUnsecureConnection = $true
    }

    ReportServerWeb PullWeb {
        ServerURL = 'http://wspull:8080/PSDSCPullServer.svc'
        RegistrationKey = 'cb30127b-4b66-4f83-b207-c4801fb05087'
        AllowUnsecureConnection = $true
    }
}
lcm
Set-DscLocalConfigurationManager .\lcm -Verbose

Exit-PSSession

# query rest api
$uri = 'http://localhost:8080/PSDSCPullServer.svc'

$irmArgs = @{
    Headers = @{
        Accept = 'application/json'
        ProtocolVersion = '2.0'
    }
    UseBasicParsing = $true
}
# available routes
(Invoke-RestMethod @irmArgs -Uri $uri).value

# Get node object, you need the agentid for this, no get all, list, wildcard
Invoke-Command -Session $lcmSession -ScriptBlock {(Get-DscLocalConfigurationManager).AgentId} | Tee-Object -Variable agentId

$uri = "http://localhost:8080/PSDSCPullServer.svc/Nodes(AgentId = '$agentId')" 
Invoke-RestMethod @irmArgs -Uri $uri

# Get node reports
$uri = "http://localhost:8080/PSDSCPullServer.svc/Nodes(AgentId = '$agentId')/Reports"
$reports = (Invoke-RestMethod @irmArgs -Uri $uri).value
$reports[0]
$reports[0].StatusData | ConvertFrom-Json

# inflexible, not admin friendly. Requires some sort of shadow administration
