#!/bin/bash

# domainavailable
# whois check domain availab.

trap 'exit 1' INT TERM EXIT

for d in $@;
do
	if host $d | grep "NXDOMAIN" >&/dev/null; then
		if whois $d | grep -E "(No match for|NOT FOUND)" >&/dev/null; then
			echo "$d AVAILABLE";
		else
			echo "$d taken";
		fi
	else
		echo "$d taken";
	fi
	sleep 0.1;
done
