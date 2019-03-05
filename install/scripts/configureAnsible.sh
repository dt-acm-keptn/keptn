#!/bin/bash

export JENKINS_USER=$(cat creds.json | jq -r '.jenkinsUser')
export JENKINS_PASSWORD=$(cat creds.json | jq -r '.jenkinsPassword')
export GITHUB_PERSONAL_ACCESS_TOKEN=$(cat creds.json | jq -r '.githubPersonalAccessToken')
export GITHUB_USER_NAME=$(cat creds.json | jq -r '.githubUserName')
export GITHUB_USER_EMAIL=$(cat creds.json | jq -r '.githubUserEmail')
export DT_TENANT_ID=$(cat creds.json | jq -r '.dynatraceTenant')
export DT_API_TOKEN=$(cat creds.json | jq -r '.dynatraceApiToken')
export DT_PAAS_TOKEN=$(cat creds.json | jq -r '.dynatracePaaSToken')
export GITHUB_ORGANIZATION=$(cat creds.json | jq -r '.githubOrg')
export DT_TENANT_URL="$DT_TENANT_ID.live.dynatrace.com"

export JENKINS_URL=$(kubectl describe svc jenkins -n cicd | grep IP: | sed 's/IP:[ \t]*//')
export CART_URL=$(kubectl describe svc carts -n production | grep "LoadBalancer Ingress:" | sed 's/LoadBalancer Ingress:[ \t]*//')
export TOWER_URL=$(kubectl describe svc ansible-tower -n tower | grep "LoadBalancer Ingress:" | sed 's/LoadBalancer Ingress:[ \t]*//')

#curl -k -X GET https://$TOWER_URL/api/v1/credentials/ --user admin:dynatrace 

export DTAPICREDTYPE=$(curl -k -X POST https://$TOWER_URL/api/v2/credential_types/ --user admin:dynatrace -H "Content-Type: application/json" \
--data '{
  "name": "dt-api",
  "kind": "cloud",
  "description" :"Dynatrace API Authentication Token",
  "inputs": { "fields": [ { "secret": true, "type": "string", "id": "dt_api_token", "label": "Dynatrace API Token" } ], "required": ["dt_api_token"]}, "injectors": { "extra_vars": { "DYNATRACE_API_TOKEN": "{{dt_api_token}}" } }
}' | jq -r '.id')
echo "DTAPICREDTYPE: " $DTAPICREDTYPE

export DTCRED=$(curl -k -X POST https://$TOWER_URL/api/v2/credentials/ --user admin:dynatrace -H "Content-Type: application/json" \
--data '{
  "name": "'$DT_TENANT_ID' API token",
  "credential_type": '$DTAPICREDTYPE',
  "organization": 1,
  "inputs": { "dt_api_token": "'$DT_API_TOKEN'" }
}' | jq -r '.id')
echo "DTCRED: " $DTCRED

export GITCRED=$(curl -k -X POST https://$TOWER_URL/api/v1/credentials/ --user admin:dynatrace -H "Content-Type: application/json" \
--data '{
  "name": "git-token",
  "kind": "scm",
  "user": 1,
  "username": "'$GITHUB_USER_NAME'",
  "password": "'$GITHUB_PERSONAL_ACCESS_TOKEN'"
}' | jq -r '.id')
echo "GITCRED: " $GITCRED

export PROJECT_ID=$(curl -k -X POST https://$TOWER_URL/api/v1/projects/ --user admin:dynatrace -H "Content-Type: application/json" \
--data '{
  "name": "self-healing",
  "scm_type": "git",
  "scm_url": "https://github.com/keptn/keptn",
  "scm_branch": "release-0.1.x",
  "credential": '$GITCRED',
  "scm_clean": "true"
}' | jq -r '.id')
echo "PROJECT_ID: " $PROJECT_ID

echo "wait for project to initialize..."
sleep 60

export INVENTORY_ID=$(curl -k -X POST https://$TOWER_URL/api/v1/inventories/ --user admin:dynatrace -H "Content-Type: application/json" \
--data '{
  "name": "inventory",
  "type": "inventory",
  "organization": 1,
  "variables": "---\ntenantid: \"'$DT_TENANT_ID'\"\ncarts_promotion_url: \"http://'$CART_URL'/carts/1/items/promotion\"\ncommentuser: \"Ansible Playbook\"\ntower_user: \"admin\"\ntower_password: \"dynatrace\"\ndtcommentapiurl: \"https://{{tenantid}}.live.dynatrace.com/api/v1/problem/details/{{pid}}/comments?Api-Token={{DYNATRACE_API_TOKEN}}\"\ndteventapiurl: \"https://{{tenantid}}.live.dynatrace.com/api/v1/events/?Api-Token={{DYNATRACE_API_TOKEN}}\""
}' | jq -r '.id')
echo "INVENTORY_ID: " $INVENTORY_ID

export REMEDIATION_TEMPLATE_ID=$(curl -k -X POST https://$TOWER_URL/api/v1/job_templates/ --user admin:dynatrace -H "Content-Type: application/json" \
--data '{
  "name": "remediation",
  "job_type": "run",
  "inventory": '$INVENTORY_ID',
  "project": '$PROJECT_ID',
  "playbook": "scripts/playbooks/remediation.yaml",
  "ask_variables_on_launch": true
}' | jq -r '.id')
echo "REMEDIATION_TEMPLATE_ID: " $REMEDIATION_TEMPLATE_ID

export STOP_CAMPAIGN_ID=$(($REMEDIATION_TEMPLATE_ID + 1))

export STOP_CAMPAIGN_ID=$(curl -k -X POST https://$TOWER_URL/api/v1/job_templates/ --user admin:dynatrace -H "Content-Type: application/json" \
--data '{
  "name": "stop-campaign",
  "job_type": "run",
  "inventory": '$INVENTORY_ID',
  "project": '$PROJECT_ID',
  "playbook": "scripts/playbooks/campaign.yaml",
  "extra_vars": "---\npromotion_rate: \"0\"\nremediation_action: \"https://'$TOWER_URL'/api/v2/job_templates/'$STOP_CAMPAIGN_ID'/launch/\"\ndt_application: \"carts\"\ndt_environment: \"production\""
}' | jq -r '.id')
echo "STOP_CAMPAIGN_ID: " $STOP_CAMPAIGN_ID

export START_CAMPAIGN_ID=$(curl -k -X POST https://$TOWER_URL/api/v1/job_templates/ --user admin:dynatrace -H "Content-Type: application/json" \
--data '{
  "name": "start-campaign",
  "job_type": "run",
  "inventory": '$INVENTORY_ID',
  "project": '$PROJECT_ID',
  "playbook": "scripts/playbooks/campaign.yaml",
  "extra_vars": "---\npromotion_rate: \"0\"\nremediation_action: \"https://'$TOWER_URL'/api/v2/job_templates/'$STOP_CAMPAIGN_ID'/launch/\"\ndt_application: \"carts\"\ndt_environment: \"production\"",
  "ask_variables_on_launch": true
}' | jq -r '.id')
echo "START_CAMPAIGN_ID: " $START_CAMPAIGN_ID

export CANARY_RESET_ID=$(curl -k -X POST https://$TOWER_URL/api/v1/job_templates/ --user admin:dynatrace -H "Content-Type: application/json" \
--data '{
  "name": "canary-reset",
  "job_type": "run",
  "inventory": '$INVENTORY_ID',
  "project": '$PROJECT_ID',
  "playbook": "scripts/playbooks/canary.yaml",
  "extra_vars": "---\ndt_app: \"front-end\"\ndt_env: \"production\"\ndteventapiurl: \"https://{{tenantid}}.live.dynatrace.com/api/v1/events/?Api-Token={{apitoken}}\"\njenkins_user: \"'$JENKINS_USER'\"\njenkins_password: \"'$JENKINS_PASSWORD'\"\njenkins_url: \"http://'$JENKINS_URL':24711/job/k8s-deploy-production-canary/build?delay=0sec\"\nremediation_url: \"\"",
  "ask_variables_on_launch": false,
  "job_tags": "canary_reset"
}' | jq -r '.id')
echo "CANARY_RESET_ID: " $CANARY_RESET_ID

export CANARY_ID=$(curl -k -X POST https://$TOWER_URL/api/v1/job_templates/ --user admin:dynatrace -H "Content-Type: application/json" \
--data '{
  "name": "canary",
  "job_type": "run",
  "inventory": '$INVENTORY_ID',
  "project": '$PROJECT_ID',
  "playbook": "scripts/playbooks/canary.yaml",
  "extra_vars": "---\ndt_app: \"front-end\"\ndt_env: \"production\"\ndteventapiurl: \"https://{{tenantid}}.live.dynatrace.com/api/v1/events/?Api-Token={{apitoken}}\"\njenkins_user: \"'$JENKINS_USER'\"\njenkins_password: \"'$JENKINS_PASSWORD'\"\njenkins_url: \"http://'$JENKINS_URL':24711/job/k8s-deploy-production-canary/build?delay=0sec\"\nremediation_url: \"https://'$TOWER_URL'/api/v2/job_templates/'$CANARY_RESET_ID'/launch/\"",
  "ask_variables_on_launch": true,
  "skip_tags": "canary_reset"
}' | jq -r '.id')
echo "CANARY_ID: " $CANARY_ID

#Assign DT API credential to all jobs
declare -a job_templates=($REMEDIATION_TEMPLATE_ID $STOP_CAMPAIGN_ID $START_CAMPAIGN_ID $CANARY_RESET_ID $CANARY_ID)

for template in "${job_templates[@]}"
do
  curl -k -X POST https://$TOWER_URL/api/v2/job_templates/$template/credentials/ --user admin:dynatrace -H "Content-Type: application/json" \
  --data '{
    "id": '$DTCRED'
  }'
done


echo "Ansible has been configured successfully! Copy the following URL to set it as an Ansible Job URL in the Dynatrace notification settings:"
echo "https://$TOWER_URL/#templates/job_template/$REMEDIATION_TEMPLATE_ID"
