$x = Get-Job -Name nova -erroraction 'silentlycontinue'

if ($x){
	echo 1
}
