#!/bin/bash

# Note: input files (asset_file, exclude_macs_file) may be sensitive to non-Unix style line breaks. 
# Use the dos2unix program to correct Windows-style linebreaks (\r\n) to Unix-style (\n) on these files before use.

ARPING=/sbin/arping
SED=/bin/sed
TR=/bin/tr
CUT=/bin/cut
DIG=/bin/dig
GREP=/bin/grep
DATE=/bin/date

while getopts ":a:i:o:r:sx:X:" opt; do
	case $opt in
		a)	asset_file="$OPTARG" ;;
		i)	ip="$OPTARG" ;;
		o)	oui_file="$OPTARG" ;;
		r)	ip_range="$OPTARG" ;;
		s)	scan='y' ;;
		x)	exclude_oui="$(tr -d : <<< $OPTARG)" ;;
		X)	exclude_macs_file="$OPTARG" ;;
	esac
done

if [[ "$scan" != 'y' ]] ; then
	[[ -z "$asset_file" ]]						&& { >&2 echo Must specify '-a <asset_file>'.	; exit 1 ; }
	[[ -f "$asset_file" ]]						|| { >&2 echo "<asset_file> $asset_file does not exist."	; exit 1 ; }
	[[ -z "$ip_range" ]]						&& { >&2 echo Must specify '-r <ip_range>'.		; exit 1 ; }
	[[ -f "$oui_file" ]]						|| { >&2 echo '<oui_file> does not exist.'		; exit 1 ; }
fi

scan() {
	if output=$($ARPING -f -w 2 $ip) ; then
		mac=$($SED -n 's:.*\[\(.*\)].*:\1:p' <<< $output)
		oui=$($TR -d : <<< $mac | $CUT -c 1-6)
		hostname="$($DIG +short -x $ip | $SED 's/.$/,/' | $TR -d '\n' | $SED 's/,$//' )"
		[[ -z "$hostname" ]] && hostname="No_Hostname"
		$GREP -qi $oui <<< "$exclude_oui" && oui_excluded="y" || oui_excluded="n"
		if  [[ ! -z "$exclude_macs_file" ]] && $GREP -qi $mac "$exclude_macs_file" ; then
			mac_excluded="y"
		else
			mac_excluded="n"
		fi
		[[ -f "$oui_file" ]] && vendor=$($GREP $oui "$oui_file" | $CUT -c 8-100 | $TR -s ' ' | $TR ' ' '_') || vendor=''
		[[ -z "${vendor// }" ]] && vendor='Unknown_Vendor'
		$GREP -qi $mac "$asset_file" && presence="Present" || presence="Absent"
		printf "%s\t%s\t%s\t%s\tOUI_Excluded:%s\tMAC_Excluded:%s\t(%s)\t%s\n" \
			$ip $mac $($DATE -Is) $presence $oui_excluded $mac_excluded "$vendor" "$hostname"
	fi	
}

[[ "$scan" == 'y' ]] && { scan "$ip" ; exit $? ; }

export asset_file
export ip_range
export oui_file
export exclude_oui
export exclude_macs_file

echo "$(eval echo $ip_range)" | tr ' ' '\n' | xargs -n 1 -P 50 /bin/bash "$0" -s -i
