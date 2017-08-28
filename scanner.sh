#!/bin/bash

# Note: input files (asset_file, exclude_macs_file) may be sensitive to non-Unix style line breaks. 
# Use the dos2unix program to correct Windows-style linebreaks (\r\n) to Unix-style (\n) on these files before use.

# Description of options
#
# -a <asset_file>
# A file in which to look for MAC addresses. It could simply be a dump of just MAC addresses, or it could be
# a large CSV export from an inventory tool, where one field happens to be a MAC. All this tool looks for is 
# the presence or absense of a MAC address in the file. "Present" implies you know about the machine and 
# expect it to show up on your network. "Absent" implies someone may have bought a new machine, started using it,
# and the user / purchasing officer / etc. never told you about it.
#
# -o <oui_file>
# Specify a file conforming to the format of 'nmap-mac-prefixes' to look up vendors based on the MAC address OUI.
# If this switch is ommitted, no vendor lookup will be performed. 
#
# -r <ip_range>
# A range of IP addresses to scan, in the form of a shell brace expansion. <ip_range> MUST BE IN QUOTES!
# example 1: -r '192.168.0.{1..20}'
# example 2: -r '{192.168.{0..255}.{1..254},10.0.{1,2}.{1..254}}'
#
# -s
# Print a hardware vendor summary based on MAC address OUIs. Will be printed last on the console, but listed
# first in the written file specified by -w.
#
# -v
# Verbose output. With this switch output will print devices excluded by OUI with -x or by MAC with -X. 
# Non-verbose output does not print these devices. Using verbose output is recommended. 
#
# -w <write_file>
# The file to write the output to. If not given, output to stdout only.
#
# -x <exclude_oui>
# A list of OUIs to mark as excluded, separated by commas. Not case sensitive. Example: "-x '00:00:5e,5c:5e:ab'". 
# A potential use is to exlude all VoIP phones, which probably all share the same OUI.
#
# -X <exclude_macs_file>
# A file containing a list of MAC addresses, one per line, to mark as excluded in the output. You might use this
# if you share a subnet with another department, and their equipment is not in your inventory. They can provide
# you a list of their equipment's MAC addresses, so you can differentiate between a machine you might need to care
# about and one somebody else handles.

# Common OUIs to exclude:
# 00:00:5e - VRRP OUI. You'll find these on the subnet gateway IP, eg x.x.x.254
# 5c:5e:ab - Juniper Routers. You'll find these on IPs x.x.x.253/252 acting as the redundant pair for VRRP. 
# 00:04:F2 - Polycom VoIP phones
# 00:0C:29 - VMware virtual machines, although you probably still want to know about those. 

summary='n'
verbose='n'
write_file='/dev/null'

# TODO: add some error checking (eg, if -o specified exit 1 if file doesn't exist or not specified)

while getopts ":a:o:r:svw:x:X:" opt; do
	case $opt in
		a)	asset_file="$OPTARG" ;;
		o)	oui_file="$OPTARG" ;;
		r)	ip_range="$OPTARG" ;;
		s)	summary='y' ;;
		v)	verbose='y' ;;
		w)	write_file="$OPTARG" ;;
		x)	exclude_oui="$(tr -d : <<< $OPTARG)" ;;
		X)	exclude_macs_file="$OPTARG" ;;
	esac
done

[[ -z "$asset_file" ]]						&& { >&2 echo Must specify '-a <asset_file>'.	; exit 1 ; }
[[ -f "$asset_file" ]]						|| { >&2 echo '<asset_file> does not exist.'	; exit 1 ; }
[[ -z "$ip_range" ]]						&& { >&2 echo Must specify '-r <ip_range>'.		; exit 1 ; }

tmpfile=$(mktemp /tmp/scanner.XXXXXXXXXX) || { >&2 echo "Could not create temporary file" ; exit 1 ; }

while read ip ; do
	if output=$(arping -f -w 2 $ip) ; then
		mac=$(sed -n 's:.*\[\(.*\)].*:\1:p' <<< $output)
		oui=$(tr -d : <<< $mac | cut -c 1-6)
		hostname="$(dig +short -x $ip | sed 's/.$/,/' | tr -d '\n' | sed 's/,$//' )"
		[[ -z "$hostname" ]] && hostname="No_Hostname"
		grep -qi $oui <<< "$exclude_oui" && oui_excluded="y" || oui_excluded="n"
		if  [[ ! -z "$exclude_macs_file" ]] && grep -qi $mac "$exclude_macs_file" ; then
			mac_excluded="y"
		else
			mac_excluded="n"
		fi
		[[ -f "$oui_file" ]] && vendor=$(grep $oui "$oui_file" | cut -c 8-100 | tr -s ' ' | tr ' ' '_') || vendor=''
		[[ -z "${vendor// }" ]] && vendor='Unknown_Vendor'
		grep -qi $mac "$asset_file" && presence="Present" || presence="Absent"

		if [[ "$verbose" = 'y' ]] ; then
			printf "%s\t%s\t%s\t%s\tOUI_Excluded:%s\tMAC_Excluded:%s\t(%s)\t%s\n" $ip $mac $(date -Is) $presence $oui_excluded $mac_excluded "$vendor" "$hostname" | tee -a "$tmpfile"
		else
			if [[ "$mac_excluded" = "n" && "$oui_excluded" = "n" ]] ; then
				printf "%s\t%s\t%s\t%s\t(%s)\t%s\n" $ip $mac $(date -Is) $presence "$vendor" "$hostname" | tee -a "$tmpfile"
			fi
		fi
	fi	
done <<< "$(tr ' ' '\n' <<< $(eval echo $ip_range))"

if [[ "$summary" == 'y' ]] ; then
	printf "===== Begin Hardware Vendor Summary =====\n" | tee -a "$write_file"
	awk '{print $(NF-1)}' "$tmpfile" | sort | uniq -c | tee -a "$write_file"
	printf "===== End Hardware Vendor Summary =====\n" | tee -a "$write_file"
fi

sort -Vo "$tmpfile" "$tmpfile"
/usr/bin/cp "$tmpfile" "$write_file"

rm "$tmpfile"
