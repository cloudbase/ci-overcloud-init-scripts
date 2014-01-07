$baseDir = "c:\OpenStack"
$virtualenv = "$baseDir\virtualenv"
$buildDir = "$baseDir\build"

Stop-Job -Name nova -erroraction 'silentlycontinue'
Stop-Job -Name neutron -erroraction 'silentlycontinue'

Remove-Job -Name nova
Remove-Job -Name neutron

rm -Recurse -Force $buildDir\openstack\nova -erroraction 'silentlycontinue'
rm -Recurse -Force $virtualenv -erroraction 'silentlycontinue'
rm -Force $baseDir\Log\* -erroraction 'silentlycontinue'
rm -Force $baseDir\etc\* -erroraction 'silentlycontinue'