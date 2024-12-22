# Check for administrative privileges
If (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Restart script with elevated privileges
    Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File', "`"$PSCommandPath`"" -Verb RunAs
    Exit
}

# HTML Header
$htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>System Information Report</title>
    <style>
        body { font-family: Arial, sans-serif; }
        h1, h2 { color: #2E6DA4; }
        table { width: 100%; border-collapse: collapse; }
        table, th, td { border: 1px solid black; }
        th, td { padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .wrap { white-space: pre-wrap; }
    </style>
</head>
<body>
    <h1>System Information Report</h1>
"@

# General info
$htmlContent += "<h2>General Info</h2><table>"

$htmlContent += "<tr><th>Username</th><td>$env:USERNAME</td></tr>"
$htmlContent += "<tr><th>Profile location</th><td>$env:USERPROFILE</td></tr>"
$htmlContent += "<tr><th>Computer name</th><td>$env:COMPUTERNAME</td></tr>"
$htmlContent += "<tr><th>Operating System</th><td>$((Get-CimInstance -ClassName Win32_OperatingSystem).Caption)</td></tr>"

# Check if the machine is joined to Azure AD
$EIDStatus = dsregcmd /status
$tenantName = $EIDStatus | Select-String -Pattern "TenantName\s*:\s*(.*)" | ForEach-Object {
    $_.Matches.Groups[1].Value.Trim()
}
if ($EIDStatus -match "AzureAdJoined\s*:\s*YES") {
    $htmlContent += "<tr><th>Entra ID membership tenant</th><td>$tenantName</td></tr>"
} else {
    # Check if the machine is joined to a local domain or workgroup
    $DomainRole = (Get-WmiObject Win32_ComputerSystem).DomainRole
    $DomainName = (Get-WmiObject Win32_ComputerSystem).Domain

    if ($DomainRole -eq 0 -or $DomainRole -eq 1) {
        $htmlContent += "<tr><th>Workgroup membership name</th><td>$DomainName</td></tr>"
    } else {
        $htmlContent += "<tr><th>Active Directory domain</th><td>$DomainName</td></tr>"
    }
}
$htmlContent += "<tr><th>Boot Mode</th><td>$((Get-CimInstance -ClassName Win32_ComputerSystem).BootupState)</td></tr>"

# Get the last boot time using Get-WmiObject
$os = Get-WmiObject -Class Win32_OperatingSystem
$lastBootUpTime = $os.ConvertToDateTime($os.LastBootUpTime)

# Calculate the uptime
$uptime = (Get-Date) - $lastBootUpTime

# Display the results
$htmlContent += "<tr><th>Boot Time</th><td>$lastBootUpTime</td></tr>"
$htmlContent += "<tr><th>Uptime</th><td>$($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes</td></tr>"
$htmlContent += "</table>"

# Bitlocker info
$bitlockerStatus = manage-bde -status | Out-String
$htmlContent += "<h2>Bitlocker Info</h2><table><tr><td class='wrap'>$bitlockerStatus</td></tr></table>"

# Antivirus info
$htmlContent += "<h2>Antivirus Info</h2><table><tr><th>AV Name</th><th>Product State</th></tr>"
$antivirusProducts = Get-CimInstance -Namespace "root/SecurityCenter2" -ClassName "AntiVirusProduct"
$antivirusProducts | ForEach-Object {
    $htmlContent += "<tr><td>$($_.displayName)</td><td>$($_.productState)</td></tr>"
}
$htmlContent += "</table>"

# CPU information
$htmlContent += "<h2>CPU Information</h2><table>"
$cpuInfo = Get-CimInstance -ClassName Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed
$cpuInfo | ForEach-Object {
    $htmlContent += "<tr><th>Name</th><td>$($_.Name)</td></tr>"
    $htmlContent += "<tr><th>Number of Cores</th><td>$($_.NumberOfCores)</td></tr>"
    $htmlContent += "<tr><th>Number of Logical Processors</th><td>$($_.NumberOfLogicalProcessors)</td></tr>"
    $htmlContent += "<tr><th>Max Clock Speed (MHz)</th><td>$($_.MaxClockSpeed)</td></tr>"
}
$htmlContent += "</table>"

# RAM information
$htmlContent += "<h2>RAM Information</h2><table><tr><th>Manufacturer</th><th>Capacity (GB)</th><th>Speed (MHz)</th><th>Part Number</th></tr>"
$ramInfo = Get-CimInstance -ClassName Win32_PhysicalMemory | Select-Object Manufacturer, Capacity, Speed, PartNumber
$ramInfo | ForEach-Object {
    $_.Capacity = [math]::Round($_.Capacity / 1GB, 2) # Convert Capacity from bytes to gigabytes
    $htmlContent += "<tr><td>$($_.Manufacturer)</td><td>$($_.Capacity)</td><td>$($_.Speed)</td><td>$($_.PartNumber)</td></tr>"
}
$htmlContent += "</table>"

# Physical disks information
$htmlContent += "<h2>Physical Disks Information (in GB)</h2><table><tr><th>Device ID</th><th>Media Type</th><th>Operational Status</th><th>Size (GB)</th><th>Friendly Name</th></tr>"
$physicalDisks = Get-PhysicalDisk | Select-Object DeviceID, MediaType, OperationalStatus, Size, FriendlyName
$physicalDisks | ForEach-Object {
    $_.Size = [math]::Round($_.Size / 1GB, 2) # Convert Size to gigabytes and round to 2 decimal places
    $htmlContent += "<tr><td>$($_.DeviceID)</td><td>$($_.MediaType)</td><td>$($_.OperationalStatus)</td><td>$($_.Size)</td><td>$($_.FriendlyName)</td></tr>"
}
$htmlContent += "</table>"

# HTML Footer
$formattedDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$htmlContent += @"
    <p>Executed on: $formattedDateTime</p>
</body>
</html>
"@

# Get the Downloads folder path
$downloadsPath = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path

# Get the current date and time formatted as yyyy-MM-dd-HH-mm-ss
$timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"

# Create the file name with the timestamp
$fileName = "ComputerInfo-$timestamp.html"

# Construct the full file path
$htmlFilePath = Join-Path -Path $downloadsPath -ChildPath $fileName

# Output the HTML content to a file
$htmlContent | Out-File -FilePath $htmlFilePath -Encoding UTF8

# Open the HTML file in the default browser
Start-Process $htmlFilePath
