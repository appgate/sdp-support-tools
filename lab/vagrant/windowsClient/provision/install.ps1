$num = $args[0]
Switch ($num)
{
    5.0 {
      $base = "5.0"
      $release = "5.0.3"
    }
    5.1 {
      $base = "5.1"
      $release = "5.1.2"
    }
    5.2 {
      $base = "5.2"
      $release = "5.2.2"
    }
    5.3 {
      $base = "5.3"
      $release = "5.3.3"
    }
    default { 
      $base = "5.3"
      $release = "5.3.3"
    }
}

mkdir C:\temp
$wc = New-Object net.webclient
$wc.Downloadfile("https://bin.appgate-sdp.com/$base/client/AppGate-SDP-$release-Installer.exe", "C:\temp\AppGate-SDP-$release-Installer.exe")
#Invoke-WebRequest "https://bin.appgate-sdp.com/$base/client/AppGate-SDP-$release-Installer.exe" -OutFile "C:\temp\AppGate-SDP-$release-Installer.exe" -UseBasicParsing

$profileFile = "C:\vagrant\provision\profile.txt"
if (Test-Path $profileFile -PathType leaf) 
{
  $scriptPath = "C:\temp\AppGate-SDP-$release-Installer.exe"
  $params = '/S /A /P=''"' + (Get-Content -Path $profileFile) + '"'''
  Invoke-Expression "$scriptPath $params"
  Write-Host "Appgate Client version $base ($release) is now installing in the background.  A Profile file was found and attempting to preload it.."
  Remove-Item -Path $profileFile -Force
}
else
{
  Invoke-Expression "C:\temp\AppGate-SDP-$release-Installer.exe /S /A"

  Write-Host "Appgate Client version $base ($release) is now installing in the background.  You will be prompted to add profile once you login."
}


