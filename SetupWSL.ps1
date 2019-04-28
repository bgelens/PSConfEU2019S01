& c:\ubuntu\ubuntu.exe install --root
& c:\ubuntu\ubuntu.exe run wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb
& c:\ubuntu\ubuntu.exe run dpkg -i packages-microsoft-prod.deb
& c:\ubuntu\ubuntu.exe run apt-get update
& c:\ubuntu\ubuntu.exe run add-apt-repository universe
& c:\ubuntu\ubuntu.exe run apt-get install -y powershell
& c:\ubuntu\ubuntu.exe run pwsh -NoProfile -Command Install-Module DSCPullServerAdmin -Force
