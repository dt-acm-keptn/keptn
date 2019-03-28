#!/bin/bash

declare -a repositories=("carts" "catalogue" "front-end" "orders" "payment" "queue-master" "shipping" "user")

while [ true ]
do

	declare numRed=0
	declare numGreen=0

	for repo in "${repositories[@]}"
	do
		res=$(curl -s http://35.232.218.69:24711/job/sockshop/job/$repo/job/master/lastBuild/api/json\?pretty\=true | jq -r '.result')

		if [ "$res" = "SUCCESS" ]
		then
			numGreen=$((numGreen+1))
		fi

		if [ "$res" = "FAILURE" ]
		then
			numRed=$((numRed+1))
		fi
	done
	curl "http://192.168.205.45/api?top_init=1&top=0|$numRed|FF0000&top_bg=00FF00&top_whirl=500"

	sleep 60

done
