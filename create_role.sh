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
ROLE_ID="${CUSTOM_ROLE_ID:-geminiEnterpriseUserNoCodeTools}"
ROLE_TITLE="${CUSTOM_ROLE_TITLE:-Gemini Enterprise User (No AGY / Code Assist)}"
ROLE_STAGE="${CUSTOM_ROLE_STAGE:-GA}"
PERMS_FILE="${PERMS_FILE:-permissions_list/final_perms.txt}"

if [ -z "$PROJ" ] || [ "$PROJ" = "your-gcp-project-id" ]; then
  echo "Error: Set PROJECT_ID in .env or pass it as the first argument: ./create_role.sh <PROJECT_ID>" >&2
  exit 1
fi

if [ ! -s "$PERMS_FILE" ]; then
  echo "Error: Permissions file '$PERMS_FILE' not found or empty. Run ./recon.sh first if you want to refresh it from live IAM." >&2
  exit 1
fi

export CLOUDSDK_METRICS_ENVIRONMENT="datacloud.antigravity"

PERMISSIONS_CSV="$(paste -sd, "$PERMS_FILE")"
ROLE_DESCRIPTION="Gemini Enterprise User (roles/discoveryengine.agentspaceUser) minus Antigravity (businessaicode.*) and Cloud AI Companion / Code Assist (cloudaicompanion.*)."

if gcloud iam roles describe "$ROLE_ID" --project="$PROJ" >/dev/null 2>&1; then
  echo "Updating existing custom role '$ROLE_ID' in project '$PROJ'..."
  gcloud iam roles update "$ROLE_ID" \
    --project="$PROJ" \
    --title="$ROLE_TITLE" \
    --description="$ROLE_DESCRIPTION" \
    --permissions="$PERMISSIONS_CSV" \
    --stage="$ROLE_STAGE"
else
  echo "Creating custom role '$ROLE_ID' in project '$PROJ'..."
  gcloud iam roles create "$ROLE_ID" \
    --project="$PROJ" \
    --title="$ROLE_TITLE" \
    --description="$ROLE_DESCRIPTION" \
    --permissions="$PERMISSIONS_CSV" \
    --stage="$ROLE_STAGE"
fi

echo "Successfully configured custom role: projects/$PROJ/roles/$ROLE_ID"
