$baseDir = "c:\OpenStack"
$virtualenv = "$baseDir\virtualenv"
$buildDir = "$baseDir\build"

$ErrorActionPreference = "SilentlyContinue"

Stop-Service -Name nova-compute -Force
Stop-Service -Name neutron-hyperv-agent -Force

Stop-Process -Name python -Force
Stop-Process -Name nova-compute -Force
Stop-Process -Name neutron-hyperv-agent -Force

if (Get-Process -Name nova-compute){
    Throw "Nova is still running on this host"
}

if (Get-Process -Name neutron-hyperv-agent){
    Throw "Neutron is still running on this host"
}

if (Get-Process -Name python){
    Throw "Python processes still running on this host"
}

if ($(Get-Service nova-compute).Status -ne "Stopped"){
    Throw "Nova service is still running"
}

if ($(Get-Service neutron-hyperv-agent).Status -ne "Stopped"){
    Throw "Neutron service is still running"
}

Get-VM | where {$_.State -eq 'Running' -or $_.State -eq 'Paused'} | Stop-Vm -Force
Remove-VM * -Force

Remove-Item -Recurse -Force $buildDir\openstack\*
Remove-Item -Recurse -Force $virtualenv
Remove-Item -Force $baseDir\Log\*
Remove-Item -Force $baseDir\etc\*
Remove-Item -Recurse -Force $baseDir\Instances\*
