#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

parent=""
submissionName=""
remotePrefix="NS"
includeRemotes=""


while getopts p:s:r:i: flag
do
case "${flag}" in
	p) parent="${OPTARG}";;
	s) submissionName="${OPTARG}";;
	r) remotePrefix="${OPTARG}";;
	i) includeRemotes="${OPTARG}";;
esac
done

if [ -z "$parent" ]; then
	echo "-p flag requred" 1>&2
	exit 2
fi

if [ -z "$submissionName" ]; then
	submissionName="submission-$parent"
fi


ns=()
ip4=()
ip6=()

NSs="$(dig +short $parent NS | sed 's/\.$//')"


while read line; do
	if [ -z "$line" ]; then
		continue
	fi
	v4="$(dig +short $line A)"
	v6="$(dig +short $line AAAA)"

	if [[ -z "$v4" && -z "$v6 " ]]; then
		echo "query for $line did not return any A/AAAA records" 1>&2
		exit 2
	fi

	lv4=""
	lv6=""
	while read l; do
		if [ -z "$lv4" ]; then
			lv4="$l"
		else
			lv4="$lv4, $l"
		fi
	done <<< $(echo "$v4")
	while read l; do
		if [ -z "$lv6" ]; then
			lv6="$l"
		else
			lv6="$lv6, $l"
		fi
	done <<< $(echo "$v6")

	v4="$lv4"
	v6="$lv6"

	ns[${#ns[*]}]="$remotePrefix-$line"
	ip4[${#ip4[*]}]="$v4"
	ip6[${#ip6[*]}]="$v6"
done <<< $(echo "$NSs")

if [ ${#ns[*]} -eq 0 ]; then
	echo "query for $parent NS returned 0 records" 1>&2
	exit 2
fi

parent=""
r=0
for i in ${!ip4[*]}; do
	v4="${ip4[$i]}"
	v6="${ip6[$i]}"
	n="${ns[$i]}"


	if [ -z "$parent" ]; then
		parent="$n"
	else
		parent="$parent, $n"
	fi

	if [ $r -eq 0 ]; then
		echo "remote:"
		r=1
	fi

	if [[ ! -z "$v4" && ! -z "$v6"  ]]; then
		echo "  - id: $n"
		echo "    address: [$v4, $v6]"
		continue
	fi

	if [ ! -z "$v6" ]; then
		v4="$v6"
	fi
	
	if [ ! -z "$v4" ]; then
		echo "  - id: $n"
		echo "    address: $v4"
		continue
	fi
done

for i in $(echo "$includeRemotes" | sed "s/,/ /g"); do
	if [ -z "$parent" ]; then
		parent="$i"
	else
		parent="$parent, $i"
	fi
done


echo "submission:"
echo "  - id: $submissionName"
echo "    parent: [$parent]"
