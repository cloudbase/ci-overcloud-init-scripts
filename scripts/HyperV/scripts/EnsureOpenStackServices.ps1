Param(
    [Parameter(Mandatory=$True)]
    [string]$serviceUsername,
    [Parameter(Mandatory=$True)]
    [string]$servicePassword
)

$openstackDir = "C:\OpenStack"
$virtualenv = "$openstackDir\virtualenv"
$configDir = "$openstackDir\etc"
$downloadLocation = "http://dl.openstack.tld/"

$novaServiceName = "nova-compute"
$novaServiceDescription = "OpenStack nova Compute Service"
$novaServiceExecutable = "$virtualenv\Scripts\nova-compute.exe"
$novaServiceParameters = "--config-file $configDir\nova.conf"

$neutronServiceName = "neutron-hyperv-agent"
$neutronServiceDescription = "OpenStack Neutron Hyper-V Agent Service"
$neutronServiceExecutable = "$virtualenv\Scripts\neutron-hyperv-agent.exe"
$neutronServiceParameters = "--config-file $configDir\neutron_hyperv_agent.conf"


Function Set-ServiceAcctCreds
{
    Param(
        [string]$serviceName
    )

    $filter = 'Name=' + "'" + $serviceName + "'" + ''
    $service = Get-WMIObject -namespace "root\cimv2" -class Win32_Service -Filter $filter
    $service.StopService()
    while ($service.Started)
    {
        sleep 2
        $service = Get-WMIObject -namespace "root\cimv2" -class Win32_Service -Filter $filter
    }

    if ((Get-WMIObject -namespace "root\cimv2" -class Win32_ComputerSystem).partofdomain -eq $true) 
    {
        $hostname = (Get-WmiObject Win32_ComputerSystem).Domain
    } else {
        $hostname = hostname
    }

    $service.Change($null,$null,$null,$null,$null,$null,"$hostname\$serviceUsername",$servicePassword)
}

Function Check-Service
{
    Param(
        [string]$serviceName,
        [string]$serviceDescription,
        [string]$serviceExecutable,
        [string]$serviceParameters
    )

    $serviceFileLocation = "$openstackDir\service"
    $serviceFileName = "OpenStackService.exe"
    $serviceStartMode = "Manual"
    $filter='Name=' + "'" + $serviceName + "'"

    #Temporary hack
    $service=Get-WmiObject -namespace "root\cimv2" -Class Win32_Service -Filter $filter
    if($service)
    {
        $service.delete()
    }

    $hasServiceFileFolder = Test-Path $serviceFileLocation
    $hasServiceFile = Test-Path "$serviceFileLocation\$serviceFileName"
    $hasService = Get-Service $serviceName -ErrorAction SilentlyContinue
    $hasCorrectUser = (Get-WmiObject -namespace "root\cimv2" -class Win32_Service -Filter $filter).StartName -like "*$serviceUsername*"

    if(!$hasServiceFileFolder)
    {
        New-Item -Path $serviceFileLocation -ItemType directory
    }

    if(!$hasServiceFile)
    {
        Invoke-WebRequest -Uri "$downloadLocation/$serviceFileName" -OutFile "$serviceFileLocation\$serviceFileName"
    }

    if(!$hasService)
    {
        New-Service -name "$serviceName" -binaryPathName "`"$serviceFileLocation\$serviceFileName`" $serviceName `"$serviceExecutable`" `"$serviceParameters`"" -displayName "$serviceName" -description "$serviceDescription" -startupType $serviceStartMode
    }

    if((Get-Service -Name $serviceName).Status -eq "Running")
    {
        Stop-Service $serviceName
    }

    if(!$hasCorrectUser)
    {
        Set-ServiceAcctCreds $serviceName
    }
}

Check-Service $novaServiceName $novaServiceDescription $novaServiceExecutable $novaServiceParameters

Check-Service $neutronServiceName $neutronServiceDescription $neutronServiceExecutable $neutronServiceParameters
