#!/bin/bash
# Atualiza preDeployCommand em 4 service instances (web+worker x prod+dev)
# pra escrever CAPTAIN_OPEN_AI_API_KEY na InstallationConfig.
set -e

TOKEN="0d392ab4-0de0-4a4a-a73b-4bb03fc5c8bb"
ENDPOINT="https://backboard.railway.app/graphql/v2"

# Build the new command as a JSON-safe string using jq
NEW_CMD='bundle exec rake db:migrate && bundle exec rails runner '\''InstallationConfig.find_or_initialize_by(name: "DEPLOYMENT_ENV").tap{|c| c.value="self-hosted"; c.save!}; InstallationConfig.find_or_initialize_by(name: "INSTALLATION_PRICING_PLAN").tap{|c| c.value="enterprise"; c.save!}; InstallationConfig.find_or_initialize_by(name: "INSTALLATION_PRICING_PLAN_QUANTITY").tap{|c| c.value=10000; c.save!}; ENV["CAPTAIN_OPEN_AI_API_KEY"].to_s.empty? || InstallationConfig.find_or_initialize_by(name: "CAPTAIN_OPEN_AI_API_KEY").tap{|c| c.value=ENV["CAPTAIN_OPEN_AI_API_KEY"]; c.save!}; GlobalConfig.clear_cache'\'''

update_predeploy() {
  local SERVICE_ID="$1"
  local ENV_ID="$2"
  local LABEL="$3"

  # JSON-escape the command and build the mutation payload via jq
  PAYLOAD=$(jq -nc \
    --arg sid "$SERVICE_ID" \
    --arg eid "$ENV_ID" \
    --arg cmd "$NEW_CMD" \
    '{query: "mutation($input:ServiceInstanceUpdateInput!,$sid:String!,$eid:String){serviceInstanceUpdate(serviceId:$sid,environmentId:$eid,input:$input)}", variables: {sid:$sid, eid:$eid, input:{preDeployCommand:[$cmd]}}}')

  echo "[$LABEL] Updating preDeployCommand..."
  RESP=$(curl -sS -X POST "$ENDPOINT" \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d "$PAYLOAD")
  echo "[$LABEL] $RESP"
}

# Prod
update_predeploy "3ec17e8b-9929-4f9e-b508-eae79534d655" "4071f2be-9abe-4b7e-a20d-f9783725b993" "prod-web"
update_predeploy "2e37d1f6-84e9-4f93-9880-bb61f23c8c85" "4071f2be-9abe-4b7e-a20d-f9783725b993" "prod-worker"

# Dev
update_predeploy "3ec17e8b-9929-4f9e-b508-eae79534d655" "4e1ebd91-4da8-4382-9a3a-5ef67daae4c7" "dev-web"
update_predeploy "2e37d1f6-84e9-4f93-9880-bb61f23c8c85" "4e1ebd91-4da8-4382-9a3a-5ef67daae4c7" "dev-worker"
