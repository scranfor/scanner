#!/bin/bash

# Note: input files (asset_file, exclude_macs_file) may be sensitive to non-Unix style line breaks. 
# Use the dos2unix program to correct Windows-style linebreaks (\r\n) to Unix-style (\n) on these files before use.

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
cat "$tmpfile" >> "$write_file"

rm "$tmpfile"
