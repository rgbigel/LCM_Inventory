# Toggle Windows Search on/off
if ((Get-Service WSearch).Status -eq 'Running') { 
	Stop-Service WSearch;
	Set-Service WSearch -StartupType Disabled; 
	Write-Host "Windows Search disabled." 
} else {
	Set-Service WSearch -StartupType Automatic; 
	Start-Service WSearch; 
	Write-Host "Windows Search enabled." 
}
