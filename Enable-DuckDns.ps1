<#
.SYNOPSIS
    Updates the IP address of your DuckDNS domain(s) on
    a schedule you decide (in minutes).
.DESCRIPTION
    This script registers two schedulded tasks automatically, one
    which runs at system start, which will set up the other task
    again in the event your system reboots, so you don't have to 
    remember to re-run this script. The second schedulded task runs
    however often you set it to, and does the actual work of updating
    your DuckDNS domains.
.PARAMETER Domains
    A comma-separated list of your Duck DNS domains to update.
.PARAMETER Token
    Your Duck DNS token.
.PARAMETER IP
    The IP address to use. Usuallu DuckDNS automatically detects this
    for you, so you should leave it blank unless you know what you're
    doing.
.INPUTS
    None. 
.OUTPUTS
    The script writes to the event log if it encounters problems with
    writing to the DuckDNS web service.
.EXAMPLE
    .\Enable-DuckDNS.ps1 -MyDomains "wibble,pibble" -Token YourDuckDNSToken -Interval 5
.LINK
    
#>

Param (
    [Alias("Domain","Domains","MyDomains")]
    [Parameter(
        Mandatory=$True,
        HelpMessage="Comma separate the domains if you want to update more than one."
    )]
    [String]$MyDomain,

    [Alias("Token")]
    [Parameter(Mandatory=$True)]
    [String]$MyToken,

    [Alias("Interval")]
    [Parameter(Mandatory=$False)]
    [int]$MyUpdateInterval = 5,

    [Parameter(Mandatory=$False)]
    [String]$IP = ""
)

# This scriptblock is the code which does the actual update call to the
# DuckDNS web service.
[scriptblock]$UpdateDuckDns = {
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [string]$strUrl
    )
    $Encoding = [System.Text.Encoding]::UTF8;

    # Run the call to DuckDNS's website
    $HTTP_Response = Invoke-WebRequest -Uri $strUrl;

    # Turn the response into english ;)
    $Text_Response = $Encoding.GetString($HTTP_Response.Content);

    # If the response is anything other than 'OK' then log an error in the windows event log
    if($Text_Response -ne "OK"){
        Write-EventLog -LogName Application -Source "DuckDNS Updater" -EntryType Information -EventID 1 -Message "DuckDNS Update failed for some reason. Check your Domain or Token.";
    }
}

# This scriptblock is the code which gets run when the system starts up each time,
# and is responsible for setting up the job which will repeat every five minutes
# to update your IP address with DuckDNS
[scriptblock]$SetupRepeatingJob = {
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [string]$strDomain,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$strToken,
        [Parameter(Mandatory=$true,Position=2)]
        [int]$iUpdateInterval,
        [Parameter(Mandatory=$false,Position=3)]
        [string]$strIP=""
    )
    # Build DuckDNS update URL using supplied domain, token and optional IP parameters
    $duckdns_url = "https://www.duckdns.org/update?domains=" + $strDomain + "&token=" + $strToken + "&ip=" + $strIP;

    # Set how often we want the job to repeat based on the interval set at the start of the script
    $RepeatTimeSpan = New-TimeSpan -Minutes $iUpdateInterval;

    # Set the time to start running this job (it will be $iUpdateInterval minutes from now)
    $At = $(Get-Date) + $RepeatTimeSpan;

    # Create the trigger to start this job
    $UpdateTrigger = New-JobTrigger -Once -At $At -RepetitionInterval $RepeatTimeSpan -RepeatIndefinitely;

    # Register the job with Windows Task scheduling system
    Register-ScheduledJob -Name "RunDuckDnsUpdate" -ScriptBlock $UpdateDuckDns -Trigger $UpdateTrigger -ArgumentList @($duckdns_url);
}

$AdministratorCheck = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
$VersionCheck = ($PSVersionTable.PSVersion.Major -ge 4)
$Break = $False

# Check to see if the script is being run under adminstrator credentials, and stop if it's not.
if(!($AdministratorCheck)){
    Write-Warning "You need to run this from an Administrator PowerShell prompt"
    $Break = $True
}
# Check on the version of Powershell
If(!($VersionCheck)){
    Write-Warning "You need to be running PowerShell version 4.0 or better"
    $Break = $True
}
# Check to see if we need to exit  
If($Break){
    Break
}

# Check to see if the "DuckDNS Updater" event log source already exists,
# and if it doesn't then create it
if (!([System.Diagnostics.EventLog]::SourceExists("DuckDNS Updater"))){
    New-EventLog  -LogName "Application" -Source "DuckDNS Updater"
}

# Set the trigger for the bootup task
$StartTrigger = New-JobTrigger -AtStartup

# Check to see if the user is super advanced and supplied their own IP address or not
if($MyIP.Length -ne 0){
    # Register the job that will run when windows first starts with the Windows Task Scheduler service
    Register-ScheduledJob -Name "StartDuckDnsJob" -ScriptBlock $SetupRepeatingJob -Trigger $StartTrigger -ArgumentList @($MyDomain,$MyToken,$MyUpdateInterval,$MyIP)
    # Run the actual update job
    & $SetupRepeatingJob $MyDomain $MyToken $MyUpdateInterval $MyIP
} else {
    # Register the job that will run when windows first starts with the Windows Task Scheduler service
    Register-ScheduledJob -Name "StartDuckDnsJob" -ScriptBlock $SetupRepeatingJob -Trigger $StartTrigger -ArgumentList @($MyDomain,$MyToken,$MyUpdateInterval)
    # Run the actual update job
    & $SetupRepeatingJob $MyDomain $MyToken $MyUpdateInterval
}

Write-Host "All done - your DuckDNS will now update automatically, and will continue to do so across system restarts."
Write-Host "Have a nice day!"