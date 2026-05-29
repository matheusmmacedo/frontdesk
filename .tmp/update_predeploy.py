#!/usr/bin/env python3
"""Update preDeployCommand on Frontdesk web+worker in prod and dev."""
import json
import urllib.request
import urllib.error
import sys

TOKEN = "0d392ab4-0de0-4a4a-a73b-4bb03fc5c8bb"
ENDPOINT = "https://backboard.railway.app/graphql/v2"

NEW_CMD = (
    'bundle exec rake db:migrate && bundle exec rails runner \''
    'InstallationConfig.find_or_initialize_by(name: "DEPLOYMENT_ENV").tap{|c| c.value="self-hosted"; c.save!}; '
    'InstallationConfig.find_or_initialize_by(name: "INSTALLATION_PRICING_PLAN").tap{|c| c.value="enterprise"; c.save!}; '
    'InstallationConfig.find_or_initialize_by(name: "INSTALLATION_PRICING_PLAN_QUANTITY").tap{|c| c.value=10000; c.save!}; '
    'ENV["CAPTAIN_OPEN_AI_API_KEY"].to_s.empty? || InstallationConfig.find_or_initialize_by(name: "CAPTAIN_OPEN_AI_API_KEY").tap{|c| c.value=ENV["CAPTAIN_OPEN_AI_API_KEY"]; c.save!}; '
    'GlobalConfig.clear_cache\''
)

MUTATION = "mutation($input:ServiceInstanceUpdateInput!,$sid:String!,$eid:String){serviceInstanceUpdate(serviceId:$sid,environmentId:$eid,input:$input)}"

TARGETS = [
    ("prod-web", "3ec17e8b-9929-4f9e-b508-eae79534d655", "4071f2be-9abe-4b7e-a20d-f9783725b993"),
    ("prod-worker", "2e37d1f6-84e9-4f93-9880-bb61f23c8c85", "4071f2be-9abe-4b7e-a20d-f9783725b993"),
    ("dev-web", "3ec17e8b-9929-4f9e-b508-eae79534d655", "4e1ebd91-4da8-4382-9a3a-5ef67daae4c7"),
    ("dev-worker", "2e37d1f6-84e9-4f93-9880-bb61f23c8c85", "4e1ebd91-4da8-4382-9a3a-5ef67daae4c7"),
]


def update(label, service_id, environment_id):
    payload = {
        "query": MUTATION,
        "variables": {
            "sid": service_id,
            "eid": environment_id,
            "input": {"preDeployCommand": [NEW_CMD]},
        },
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        ENDPOINT,
        data=data,
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            print(f"[{label}] {resp.status} {resp.read().decode()}")
    except urllib.error.HTTPError as e:
        print(f"[{label}] HTTPError {e.code}: {e.read().decode()}")
    except Exception as e:
        print(f"[{label}] Error: {e}")


for label, sid, eid in TARGETS:
    update(label, sid, eid)
