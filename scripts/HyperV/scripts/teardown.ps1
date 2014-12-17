$baseDir = "c:\OpenStack"
$virtualenv = "$baseDir\virtualenv"
$buildDir = "$baseDir\build"

$log = "C:\Users\Administrator\cleanup.log"

$ErrorActionPreference = "SilentlyContinue"

Add-Content $log "Stopping Nova and Neutron services"
Stop-Service -Name nova-compute -Force
Stop-Service -Name neutron-hyperv-agent -Force

Add-Content $log "Stopping any python processes that might have been left running"
Stop-Process -Name python -Force
Stop-Process -Name nova-compute -Force
Stop-Process -Name neutron-hyperv-agent -Force

Add-Content $log "Checking that services and processes have been succesfully stopped"
if (Get-Process -Name nova-compute){
    Throw "Nova is still running on this host"
}else {
    Add-Content $log "No nova process running."
}

if (Get-Process -Name neutron-hyperv-agent){
    Throw "Neutron is still running on this host"
}else {
    Add-Content $log "No neutron process running"
}

if (Get-Process -Name python){
    Throw "Python processes still running on this host"
}else {
    Add-Content $log "No python processes left running"
}

if ($(Get-Service nova-compute).Status -ne "Stopped"){
    Throw "Nova service is still running"
}else {
    Add-Content $log "Nova service is in Stopped state."
}

if ($(Get-Service neutron-hyperv-agent).Status -ne "Stopped"){
    Throw "Neutron service is still running"
}else {
    Add-Content $log "Neutron service is in Stopped state"
}

Add-Content $log "Clearing any VMs that might have been left."
Get-VM | where {$_.State -eq 'Running' -or $_.State -eq 'Paused'} | Stop-Vm -Force
Remove-VM * -Force

Add-Content $log "Cleaning the build folder."
Remove-Item -Recurse -Force $buildDir\openstack\*
Add-Content $log "Cleaning the virtualenv folder."
Remove-Item -Recurse -Force $virtualenv
Add-Content $log "Cleaning the logs folder."
Remove-Item -Force $baseDir\Log\*
Add-Content $log "Cleaning the config folder."
Remove-Item -Force $baseDir\etc\*
Add-Content $log "Cleaning the Instances folder."
Remove-Item -Recurse -Force $baseDir\Instances\*
Add-Content $log "Cleaning up process finished."