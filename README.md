# Summary

This simple scanner uses ARP (via arping) to discover devices on a network. It should be able to discover devices even with the most restrictive firewall rules, as if the host doesn't reply to ARP requests, it effectively cannot use the network at all.

This script should work on RHEL / CentOS 7. Modifications are necessary for other distributions.

Make sure you have the few prerequisite packages installed:

`yum install bind-utils iputils git -y`

# Example

A very simple example:

`git clone https://github.com/scranfor/scanner.git`

`cd scanner`

`wget https://svn.nmap.org/nmap/nmap-mac-prefixes -O nmap-mac-prefixes`

`touch empty-file`

` ./scanner.sh -a empty-file -w empty-file -e fake@email.tld -o nmap-mac-prefixes -X empty-file -r '192.168.{0..255}.{0..255}' | tee scan-output.txt`

This will scan the 65k IP addresses of 192.168.0.0/16. It will take roughly 22 minutes, and will generate roughly 11MB of network traffic. Discovered devices will be printed to the screen and logged in scan-output.txt. Because on most networks 192.168.0.0/16 will be mostly vacant, expect very long stretches of time where nothing is being printed.

# Description of options

## -a <asset_file>
A file in which to look for MAC addresses. It could simply be a dump of just MAC addresses, or it could be
a large CSV export from an inventory tool, where one field happens to be a MAC. All this tool looks for is 
the presence or absense of a MAC address in the file. "Present" implies you know about the machine and 
expect it to show up on your network. "Absent" implies someone may have bought a new machine, started using it,
and the user / purchasing officer / etc. never told you about it.

## -e <email_address>
The email address to send to when a MAC you want to watch for is found active. Does nothing if -w is not specified.

## -o <oui_file>
Specify a file conforming to the format of 'nmap-mac-prefixes' to look up vendors based on the MAC address OUI.
If this switch is ommitted, no vendor lookup will be performed. 

## -r <ip_range>
A range of IP addresses to scan, in the form of a shell brace expansion. <ip_range> MUST BE IN SINGLE QUOTES!
example 1: -r '192.168.0.{1..20}'
example 2: -r '{192.168.{0..255}.{0..255},10.0.{1,2}.{1..254}}'

## -w <watchfor_file>
A file containing a list of MAC addresses to watch out for. If the scanner finds an active MAC that is in
that file, it will send an email to the address specified by -e. 

## -x <exclude_oui>
A list of OUIs to mark as excluded, separated by commas. Not case sensitive. Example: "-x '00:00:5e,5c:5e:ab'". 
A potential use is to exlude all VoIP phones, which probably all share the same OUI.

## -X <exclude_macs_file>
A file containing a list of MAC addresses, one per line, to mark as excluded in the output. You might use this
if you share a subnet with another department, and their equipment is not in your inventory. They can provide
you a list of their equipment's MAC addresses, so you can differentiate between a machine you might need to care
about and one somebody else handles.

# Common OUIs to exclude:
* 00:00:5e - VRRP OUI. You'll find these on the subnet gateway IP, eg x.x.x.254
* 5c:5e:ab - Juniper Routers. You'll find these on IPs x.x.x.253/252 acting as the redundant pair for VRRP. 
* 00:04:F2 - Polycom VoIP phones
* 00:0C:29 - VMware virtual machines, although you probably still want to know about those. 
