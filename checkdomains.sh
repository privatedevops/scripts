#! /bin/bash

do_query () # name
{
    dig "$1" +noquestion +nostat +noanswer +noauthority 2> /dev/null
}

get_answers_number () # name
{
    local res=$(do_query "$1")
    res=${res##*ANSWER: }
    echo "${res%%,*}"
}

# Unregistered domains saved in file
file="unregistered.txt"
echo "Results will be saved in $file"

#for adr in {a..z}{a..z}{a..z} {a..z}{a..z}{a..z}{a..z}
for adr in $(cat ./list)
do
    name="$adr.com"
    printf "Checking %s ...\r" "$name"
    r=$(get_answers_number "$name")
    if ((r==0)); then
	./cdom.sh $adr.com | grep AVAILABLE >> ./unregistered.txt
	sleep 2s;
    fi

done 3>| "$file"
