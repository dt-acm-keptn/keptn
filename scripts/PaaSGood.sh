#!/bin/bash
export JENKINS_URL=$(kubectl describe svc jenkins -n cicd | grep "LoadBalancer Ingress:" | sed 's~LoadBalancer Ingress:[ \t]*~~')
export JENKINS_USER=$(cat creds.json | jq -r '.jenkinsUser')
export JENKINS_TOKEN=$(cat creds.json | jq -r '.jenkinsToken')

sed -i '.original' -e  's/delayInMillis=.*/delayInMillis=0/g' ../repositories/carts/src/main/resources/application.properties
git add .
git commit -m "Set delay to 0"
git push
sleep 10
curl -X POST http://$JENKINS_URL:24711/job/sockshop/job/carts/job/master/build --user "admin:$JENKINS_TOKEN"
echo "--------------------------"
echo "Carts build started"
echo "--------------------------"
echo
sleep 15
declare cartsBuilding=$(curl -s http://$JENKINS_URL:24711/job/sockshop/job/carts/job/master/lastBuild/api/json\?pretty | jq -r '.building')
sleep 180
while [ "$cartsBuilding" = "true" ]
	do
		cartsBuilding=$(curl -s http://$JENKINS_URL:24711/job/sockshop/job/carts/job/master/lastBuild/api/json\?pretty | jq -r '.building')
		sleep 10
done
sleep 10
declare cartsStatus=$(curl -s http://$JENKINS_URL:24711/job/sockshop/job/carts/job/master/lastBuild/api/json\?pretty | jq -r '.result')
echo "--------------------------"
echo "Carts build finished"
echo "The build was marked as " $cartsStatus
echo "--------------------------"
echo

if [ "$cartsStatus" != "SUCCESS" ]
then
	exit
fi
echo "Do you wish to trigger carts.performance?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) curl -X POST http://$JENKINS_URL:24711/job/sockshop/job/carts.performance/job/master/build --user "admin:$JENKINS_TOKEN"; break;;
        No ) exit;;
    esac
done

echo "--------------------------"
echo "Carts performance started"
echo "--------------------------"
echo
sleep 15
declare cartsPerfBuilding=$(curl -s http://$JENKINS_URL:24711/job/sockshop/job/carts.performance/job/master/lastBuild/api/json\?pretty | jq -r '.building')
sleep 60
while [ "$cartsPerfBuilding" = "true" ]
	do
		cartsPerfBuilding=$(curl -s http://$JENKINS_URL:24711/job/sockshop/job/carts.performance/job/master/lastBuild/api/json\?pretty | jq -r '.building')
		sleep 10
done
declare cartsPerfStatus=$(curl -s http://$JENKINS_URL:24711/job/sockshop/job/carts.performance/job/master/lastBuild/api/json\?pretty | jq -r '.result')
echo "--------------------------"
echo "Carts performance finished"
echo "The performance of carts was marked as " $cartsPerfStatus
echo "--------------------------"
echo
