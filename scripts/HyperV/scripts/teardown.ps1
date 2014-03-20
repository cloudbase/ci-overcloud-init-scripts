$baseDir = "c:\OpenStack"
$virtualenv = "$baseDir\virtualenv"
$buildDir = "$baseDir\build"

#Stop-Job -Name nova -erroraction 'silentlycontinue'
#Stop-Job -Name neutron -erroraction 'silentlycontinue'

#Remove-Job -Name nova
#Remove-Job -Name neutron

Stop-Process -Name nova-compute -Force -ErrorAction Continue
Stop-Process -Name neutron-hyperv-agent -Force -ErrorAction Continue
Stop-Process -Name python -Force -ErrorAction Continue

Get-VM | where {$_.State -eq 'Running' -or $_.State -eq 'Paused'} | Stop-Vm -Force
Remove-VM * -Force

Remove-Item -Recurse -Force $buildDir\openstack\* -ErrorAction Continue
Remove-Item -Recurse -Force $virtualenv -ErrorAction Continue
Remove-Item -Force $baseDir\Log\* -ErrorAction Continue
Remove-Item -Force $baseDir\etc\* -ErrorAction Continue
Remove-Item -Recurse -Force $baseDir\Instances\* -ErrorAction Continue
net use u: /delete
