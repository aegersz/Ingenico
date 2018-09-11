#! /bin/bash

#
# to make our lives a little easier !
#
# view ALL exclusive locks (by DB) on most chains
#
# view the information about the top blocker pid only
#
# pg_terminate all exclusive locks after a specified blocker duration time
#

if [[ "$1" == "--help" ]] ; then
	echo 
        echo "--help    show options"
        echo "--bypass  removes lock time restrictions and increases the amounts of locks displayed"
	exit
fi

h=$(hostname -s)

#
# be aware that this list changes
#
case $h in
	"srv0081")
                d="everest"
                ;;
	"srv0113")
                d="oneyearfr45"
                ;;
	"srv0004")
                d="eportal"
                ;;
	"srv0080")
                d="axfrak4"
                ;;
	"srv0102")
                d="axisfr2"
                ;;
	"srv0104")
		d="axisuk5"
#              	d="axisuk7"
		;;
        "srv0058")
                d="axisfr12"
                ;;
        "srv0068")
		echo ""
		echo "Multi Instance DB: which instance do you want ? (enter a number between 20-59)"
		read i
		if [[ "$i" =~ ^[0-9]+$ ]] && [ "$i" -ge 20 ] && [ "$i" -le 59 ]; then :
		else
		    	echo "invalid instance number !"
        		exit 1
		fi
                d="axisfr"$i
                ;;
        "srv0095")
                d="axisuk13"
                ;;
	"srv0056")
                d="axisww01"
		;;
	*)
		echo ""
		echo "host" $h "is unrecognised !"	
		exit 1
		;;
esac

#echo ""
#echo "Do you want to view ALL locks on" $d "? (LIMIT 50)"
#read y
y="yes"

if [[ "$1" == "--bypass" ]] ; then
        lim="1000"
else lim="50"
fi

if [ "$y" == "yes" ] || [ "$y" == "y" ]; then
	echo ""
        psql -d $d -c "select database, waiting_pid, waiting_duration, blocker_duration, blocker_locktype, blocker_table, blocker_pid from meteo.check_locks() where lower( blocker_mode ) ~ 'excl' order by blocker_duration DESC LIMIT ' $lim' ;"
fi

echo ""
echo "do you want to view the oldest blocker pid information ?"
read y

if [ "$y" == "yes" ] || [ "$y" == "y" ]; then
       	echo ""
        p=$(psql -d $d -A -t -F " " -c "select blocker_pid from meteo.check_locks() where lower( blocker_mode ) ~ 'excl' order by blocker_duration DESC LIMIT 1;")
	if [[ -n "$p" ]]; then
		psql $d <<EOF
		\x
        	select * from meteo.pg_stat_activity() where pid=$p;
EOF
	fi
fi

if [[ "$1" == "--bypass" ]] ; then
	min=0
else min="5"
fi

echo ""
echo "terminate all postgres locks on" $d "older than or equal to HOW MANY minutes ? ( the minimum is" $min ")"
read t

if [[ "$t" =~ ^[0-9]+$ ]] && [ "$t" -ge $min ]; then :
else 
	echo ""
	echo "time must be numeric and greater than or equal to" $min
	exit 1
fi

t="$t min"

echo ""
echo "do you REALLY want to PGTERM all locks on" $d "that have been held for" $t "minutes or longer ?"
read x
echo ""

if [ "$x" == "yes" ] || [ "$x" == "y" ]; then
	psql -d $d -c "select distinct(blocker_pid), database, waiting_duration, blocker_duration from meteo.check_locks() where lower( blocker_mode ) ~ 'excl' and blocker_duration > '$t'::interval order by blocker_duration DESC;"
	echo "continue ?"
	read y
	if [ "$y" == "yes" ] || [ "$y" == "y" ]; then
		psql -d $d -A -t -F " " -c "select distinct(blocker_pid), blocker_duration from meteo.check_locks() where lower( blocker_mode ) ~ 'excl' and blocker_duration > '$t'::interval order by blocker_duration DESC;" | cut -d' ' -f1 > ~/pgtermlocks
		echo ""
		echo "number of locks to terminate is:" 
		wc -l ~/pgtermlocks
		echo ""
		while read -r a
		do
	      		echo psql postgres -c 'select meteo.pg_terminate_backend( '$a' )'
	      		psql postgres -c 'select meteo.pg_terminate_backend( '$a' )'
	      		sleep 1
	   	done < ~/pgtermlocks
		echo "Check for any new locks ..."
		echo ""
		psql -d $d -c "select database, waiting_duration, blocker_duration from meteo.check_locks() where lower( blocker_mode ) ~ 'excl' order by blocker_duration DESC;"
	fi

else 
	echo ""
	echo "goodbye then"
	exit 1
fi
