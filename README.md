# Enable-DuckDns.ps1

Updates the IP address of your DuckDNS domain(s) on a schedule you decide (in minutes).

## Description

This script registers two schedulded tasks automatically, one
which runs at system start, which will set up the other task
again in the event your system reboots, so you don't have to 
remember to re-run this script. The second schedulded task runs
however often you set it to, and does the actual work of updating
your DuckDNS domains.

## Dependencies

PowerShell Version 4.0

## Sample Usage
`.\Enable-DuckDNS.ps1 -MyDomains "wibble,pibble" -Token YourDuckDNSToken -Interval 5`