# Check for administrative privileges
If (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Restart script with elevated privileges
    Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File', "`"$PSCommandPath`"" -Verb RunAs
    Exit
}

# General info
Write-Host ""

Write-Host "***************************** General info *****************************"

Write-Host ""
Write-Host "Username: $env:USERNAME"
Write-Host "Profile location: $env:USERPROFILE"
Write-Host "Computer name: $env:COMPUTERNAME"
Write-Host "Operating System: "(Get-CimInstance -ClassName Win32_OperatingSystem).Caption
# Check if the machine is joined to Azure AD
$EIDStatus = dsregcmd /status
$tenantName = $EIDStatus | Select-String -Pattern "TenantName" | ForEach-Object {
    ($_ -split ":\s*")[1].Trim()
}
if ($EIDStatus -match "AzureAdJoined\s*:\s*YES") {
    Write-Host "Entra ID membership tenant: $tenantName"
} else {
    # Check if the machine is joined to a local domain or workgroup
    $DomainRole = (Get-WmiObject Win32_ComputerSystem).DomainRole
    $DomainName = (Get-WmiObject Win32_ComputerSystem).Domain

    if ($DomainRole -eq 0 -or $DomainRole -eq 1) {
        Write-Host "Workgroup membership name: $DomainName"
    } else {
        Write-Host "Active Directory domain: $DomainName"
    }
}
Write-Host "Boot Mode: "(Get-CimInstance -ClassName Win32_ComputerSystem).BootupState

# Get the last boot time using Get-WmiObject
$os = Get-WmiObject -Class Win32_OperatingSystem
$lastBootUpTime = $os.ConvertToDateTime($os.LastBootUpTime)

# Calculate the uptime
$uptime = (Get-Date) - $lastBootUpTime

# Display the results
Write-Host "Boot Time: $lastBootUpTime"
Write-Host "Uptime: $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes"

Write-Host ""

Write-Host "**************************** Bitlocker info ****************************"

Write-Host ""
& manage-bde -status
Write-Host ""

Write-Host "**************************** Antivirus info ****************************"

Write-Host ""
# Get installed antivirus products
$antivirusProducts = Get-CimInstance -Namespace "root/SecurityCenter2" -ClassName "AntiVirusProduct"

# Display antivirus information
$antivirusProducts | ForEach-Object {
    Write-Host "AV Name: $($_.displayName)"
    Write-Host "Product State: $($_.productState)"
    Write-Host ""
}

Write-Host ""

Write-Host "**************************** CPU information ***************************"

# Get CPU information
$cpuInfo = Get-CimInstance -ClassName Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed
$cpuInfo | Format-Table -AutoSize

Write-Host "**************************** RAM information ***************************"

# Get RAM information
$ramInfo = Get-CimInstance -ClassName Win32_PhysicalMemory | Select-Object Manufacturer, Capacity, Speed, PartNumber
$ramInfo | ForEach-Object {
    $_.Capacity = [math]::Round($_.Capacity / 1GB, 2) # Convert Capacity from bytes to gigabytes
}
$ramInfo | Format-Table -AutoSize

Write-Host "****************** Physical disks information (in GB) ******************"

Write-Host ""
# Get physical disk information
$physicalDisks = Get-PhysicalDisk | Select-Object DeviceID, MediaType, OperationalStatus, Size, FriendlyName

# Convert Size from bytes to gigabytes
$physicalDisks | ForEach-Object {
    $_.Size = [math]::Round($_.Size / 1GB, 2) # Convert Size to gigabytes and round to 2 decimal places
}

# Display the converted information
Write-Host "Physical Disks Information (in GB):"
$physicalDisks | Format-Table -AutoSize

Write-Host "************************************************************************"

Write-Host ""
$formattedDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "Executed on: $formattedDateTime"

# Pause the script
Write-Host "Press enter to close window"
Read-Host
