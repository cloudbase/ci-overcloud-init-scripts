$UpdateSession = New-Object -Com Microsoft.Update.Session
$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()

$SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Software'")

$UpdatesToDownload = New-Object -Com Microsoft.Update.UpdateColl

For ($X = 0; $X -lt $SearchResult.Updates.Count; $X++){
    $Update = $SearchResult.Updates.Item($X)
    #Write-Host( ($X + 1).ToString() + "&gt; Adding: " + $Update.Title)
    $Null = $UpdatesToDownload.Add($Update)
}

$Downloader = $UpdateSession.CreateUpdateDownloader()
$Downloader.Updates = $UpdatesToDownload
$Null = $Downloader.Download()

$UpdatesToInstall = New-Object -Com Microsoft.Update.UpdateColl

For ($X = 0; $X -lt $SearchResult.Updates.Count; $X++){
    $Update = $SearchResult.Updates.Item($X)
    If ($Update.IsDownloaded) {
        $Null = $UpdatesToInstall.Add($Update)        
    }
}

$Installer = $UpdateSession.CreateUpdateInstaller()
$Installer.Updates = $UpdatesToInstall

$InstallationResult = $Installer.Install()

For ($X = 0; $X -lt $UpdatesToInstall.Count; $X++){
    Write-Host($UpdatesToInstall.Item($X).Title + ": " + $InstallationResult.GetUpdateResult($X).ResultCode)
}

If ($InstallationResult.RebootRequire -eq $True){
    (Get-WMIObject -Class Win32_OperatingSystem).Reboot()
}
