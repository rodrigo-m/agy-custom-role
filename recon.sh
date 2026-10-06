#!/usr/bin/env bash
set -euo pipefail

# Load environment variables from .env if present
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

PROJ="${1:-${PROJECT_ID:-}}"
if [ -z "$PROJ" ] || [ "$PROJ" = "your-gcp-project-id" ]; then
  echo "Error: Set PROJECT_ID in .env or pass it as the first argument: ./recon.sh <PROJECT_ID>" >&2
  exit 1
fi

export CLOUDSDK_METRICS_ENVIRONMENT="datacloud.antigravity"
mkdir -p permissions_list

echo "=== 1. Active Account ==="
gcloud auth list --filter=status:ACTIVE --format="value(account)"

echo "=== 2. Project Info ==="
gcloud projects describe "$PROJ" --format="yaml(projectId,projectNumber,parent)"

echo "=== 3. Enabled Relevant Services on $PROJ ==="
gcloud services list --enabled --project="$PROJ" \
  --filter="config.name:(businessaicode.googleapis.com OR discoveryengine.googleapis.com OR cloudaicompanion.googleapis.com)" \
  --format="table(config.name,config.title)"

echo "=== 4. Extracting permissions from roles/discoveryengine.agentspaceUser ==="
gcloud iam roles describe roles/discoveryengine.agentspaceUser \
  --format="value[delimiter=';'](includedPermissions)" \
  | tr ';' '\n' | sed '/^$/d' | sort -u > permissions_list/agentspaceUser_all.txt
echo "Total permissions in predefined role: $(wc -l < permissions_list/agentspaceUser_all.txt | tr -d ' ')"

echo "=== 5. Filtering out AGY (businessaicode.*) and Code Assist (cloudaicompanion.*) ==="
grep -v '^businessaicode\.' permissions_list/agentspaceUser_all.txt > permissions_list/custom_role_perms.txt
grep -Ev '^(businessaicode|cloudaicompanion)\.' permissions_list/agentspaceUser_all.txt > permissions_list/filtered_user_perms.txt
echo "Permissions after removing businessaicode.*: $(wc -l < permissions_list/custom_role_perms.txt | tr -d ' ')"
echo "Permissions after removing businessaicode.* and cloudaicompanion.*: $(wc -l < permissions_list/filtered_user_perms.txt | tr -d ' ')"

echo "=== 6. Filtering to supported project-level custom role permissions ==="
gcloud iam list-testable-permissions "//cloudresourcemanager.googleapis.com/projects/$PROJ" \
  --format="value(name)" | sort -u > permissions_list/all_testable.txt
gcloud iam list-testable-permissions "//cloudresourcemanager.googleapis.com/projects/$PROJ" \
  --filter="customRolesSupportLevel:NOT_SUPPORTED" --format="value(name)" \
  | sort -u > permissions_list/truly_unsupported.txt

comm -23 permissions_list/all_testable.txt permissions_list/truly_unsupported.txt > permissions_list/supported_project_perms.txt
comm -12 permissions_list/filtered_user_perms.txt permissions_list/supported_project_perms.txt > permissions_list/final_perms.txt
rm -f permissions_list/filtered_user_perms.txt permissions_list/supported_project_perms.txt

echo "Final supported project-level custom role permissions: $(wc -l < permissions_list/final_perms.txt | tr -d ' ')"

echo "=== 7. Existing Custom Roles in $PROJ ==="
gcloud iam roles list --project="$PROJ"
