#!/bin/bash
export JENKINS_URL=$(kubectl describe svc jenkins -n cicd | grep "LoadBalancer Ingress:" | sed 's~LoadBalancer Ingress:[ \t]*~~')
while :
do
curl -s http://$JENKINS_URL:24711/job/sockshop/job/carts/job/master/lastBuild/api/json\?pretty > cartsStatus.json
curl -s http://$JENKINS_URL:24711/job/sockshop/job/carts.performance/job/master/lastBuild/api/json\?pretty > cartsPerfStatus.json
	declare cartsStatus=$(cat cartsStatus.json | jq -r '.result')
	declare cartsBuilding=$(cat cartsStatus.json | jq -r '.building')
	declare cartsPerfStatus=$(cat cartsPerfStatus.json | jq -r '.result')
	declare cartsPerfBuilding=$(cat cartsPerfStatus.json | jq -r '.building')
	declare ufoIP=192.168.220.198

	echo "stauts = " $cartsStatus
	echo "building = " $cartsBuilding
	echo "perf stauts = " $cartsPerfStatus
	echo "perf building = " $cartsPerfBuilding


		if [ "$cartsBuilding" = "true" ] && [ "$cartsStatus" = "null" ]
		then
				curl "http://$ufoIP/api?top_init=1&top=0|15|1496ff&top_bg=000000&top_morph=300|15"
		fi
		if [ "$cartsBuilding" = "false" ] && [ "$cartsStatus" = "SUCCESS" ]
		then
				curl "http://$ufoIP/api?top_init=1&top=0|15|00ff00"
		fi
		if [ "$cartsBuilding" = "false" ] && [ "$cartsStatus" = "FAILURE" ]
		then
			curl "http://$ufoIP/api?top_init=1&top=0|15|ff0000&top_bg=000000&top_morph=300|15"
		fi
#test perf pipeline
if [ "$cartsPerfBuilding" = "true" ] && [ "$cartsPerfStatus" = "null" ]
then
		curl "http://$ufoIP/api?bottom_init=1&bottom=0|15|1496ff&bottom_bg=000000&bottom_morph=300|15"
fi
if [ "$cartsPerfBuilding" = "false" ] && [ "$cartsPerfStatus" = "SUCCESS" ]
then
		curl "http://$ufoIP/api?bottom_init=1&bottom=0|15|00ff00"
fi
if [ "$cartsPerfBuilding" = "false" ] && [ "$cartsPerfStatus" = "UNSTABLE" ]
then
	curl "http://$ufoIP/api?bottom_init=1&bottom=0|10|ffff00&bottom_whirl=480"
fi
if [ "$cartsPerfBuilding" = "false" ] && [ "$cartsPerfStatus" = "FAILURE" ]
then
	curl "http://$ufoIP/api?bottom_init=1&bottom=0|10|ff0000&bottom_whirl=480"
fi

		sleep 1
	done
