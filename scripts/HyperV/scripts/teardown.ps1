$baseDir = "c:\OpenStack"
$virtualenv = "$baseDir\virtualenv"
$buildDir = "$baseDir\build"

$ErrorActionPreference = "SilentlyContinue"

Stop-Service -Name nova-compute -Force -ErrorAction $ErrorActionPreference
Stop-Service -Name neutron-hyperv-agent -Force -ErrorAction $ErrorActionPreference

Stop-Process -Name python -Force -ErrorAction $ErrorActionPreference
Stop-Process -Name nova-compute -Force -ErrorAction $ErrorActionPreference
Stop-Process -Name neutron-hyperv-agent -Force -ErrorAction $ErrorActionPreference

Get-VM | where {$_.State -eq 'Running' -or $_.State -eq 'Paused'} | Stop-Vm -Force
Remove-VM * -Force

Remove-Item -Recurse -Force $buildDir\openstack\* -ErrorAction Continue
Remove-Item -Recurse -Force $virtualenv -ErrorAction Continue
Remove-Item -Force $baseDir\Log\* -ErrorAction Continue
Remove-Item -Force $baseDir\etc\* -ErrorAction Continue
Remove-Item -Recurse -Force $baseDir\Instances\* -ErrorAction Continue
