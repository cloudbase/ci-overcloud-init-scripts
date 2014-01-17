
$openstackDir = "C:\OpenStack"
$baseDir = "$openstackDir\devstack"
$scriptdir = "$baseDir\scripts"
$binDir = "C:\OpenStack\bin"

$mngmtIPOctet = (Get-NetIPAddress -AddressFamily IPv4| where {$_.IPAddress -match "10.21.7.*"}).IPAddress.split('.')[-1]
$dataIP = "10.0.2.$mngmtIPOctet"
$curDataIP = (Get-NetIPAddress | where {$_.InterfaceAlias -match "br100" -and $_.AddressFamily -eq "IPv4"})

$hasScripts = Test-Path $scriptdir
$hasBinDir = Test-Path $binDir
$hasMkisoFs = Test-Path $binDir\mkisofs.exe
$hasQemuImg = Test-Path $binDir\qemu-img.exe


function GetDir {
   $Invocation = (Get-Variable MyInvocation -Scope 1).Value
   Split-Path $Invocation.InvocationName
}

$MyDir = GetDir

$pyPkgs = Get-Content "$MyDir\python_packages.txt"
$pipFreeze = (pip freeze | sort)

if ($pyPkgs.ToString() -ne $pipFreeze.ToString()){
	echo "Python packages do not match. Required packages are: $pyPkgs"
}

if (($hasScripts -eq $false) -or ($hasBinDir -eq $false) -or ($hasMkisoFs -eq $false) -or ($hasQemuImg -eq $false)){
    echo "ERROR: The following paths must exist: $scriptdir, $binDir, $binDir\mkisofs.exe, $binDir\qemu-img.exe"
}

if ($mngmtIPOctet -and ($curDataIP.IPAddress.ToString() -ne $curDataIP.ToString())){
	echo "FAILED: Datalink IP is not correct. Should be $curDataIP --> $dataIP"
}

if ($curDataIP.PrefixLength.ToString() -ne '23' ){
    echo "ERROR: Invalid netmask on br100. Should be /23"
}

$pipVersion = pip --version | awk '{print $2}'

if ( $pipVersion -ne '1.4.1'){
	echo "ERROR: incorrect pip version ($pipVersion). Needs 1.4.1"
}

