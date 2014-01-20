$baseDir = "c:\OpenStack"
$virtualenv = "$baseDir\virtualenv"
$buildDir = "$baseDir\build"

#Stop-Job -Name nova -erroraction 'silentlycontinue'
#Stop-Job -Name neutron -erroraction 'silentlycontinue'

#Remove-Job -Name nova
#Remove-Job -Name neutron

Stop-Process -Name nova-compute -Force -ErrorAction SilentlyContinue
Stop-Process -Name neutron-hyperv-agent -Force -ErrorAction SilentlyContinue
Stop-Process -Name python -Force -ErrorAction SilentlyContinue

Get-VM | Stop-VM -Force -Passthru | Remove-VM -Force

Remove-Item -Recurse -Force $buildDir\openstack\* -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $virtualenv -ErrorAction SilentlyContinue
Remove-Item -Force $baseDir\Log\* -ErrorAction SilentlyContinue
Remove-Item -Force $baseDir\etc\* -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $baseDir\Instances\* -ErrorAction SilentlyContinue
net use u: /delete
