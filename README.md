# Gemini Enterprise Custom IAM Role (No AGY / No Code Assist)

## Purpose

The predefined **Gemini Enterprise User** (`roles/discoveryengine.agentspaceUser`) role grants end-user access to Gemini Enterprise (chat, search, agents, sessions, memories, connectors), **plus** permissions for AI developer coding tools:

- **Antigravity (AGY):** `businessaicode.*` (5 permissions, including `businessaicode.locations.selfAssignLicense`)
- **Cloud AI Companion / Gemini Code Assist:** `cloudaicompanion.*` (13 permissions, including `cloudaicompanion.licenses.selfAssign`)

Meanwhile, **Gemini Enterprise Viewer** (`roles/discoveryengine.agentspaceViewer`) omits `businessaicode.*` and `cloudaicompanion.*`, but is read-only and too restrictive for regular Gemini Enterprise end users.

This repository provides a reproducible workflow and permission set ([final_perms.txt](./permissions_list/final_perms.txt)) to create a **project-level custom IAM role** that gives users full **Gemini Enterprise User** functionality while withholding **Antigravity (AGY)** and **Cloud AI Companion (Gemini Code Assist)** permissions.

## Official Documentation Reference

- **Predefined Roles & Permissions:** [Gemini Enterprise Access Control — Predefined Roles (`roles/discoveryengine.agentspaceUser`)](https://docs.cloud.google.com/gemini/enterprise/docs/access-control#discoveryengine.agentspaceUser)

---

## Permission Breakdown (`final_perms.txt` vs Predefined Role)

| Source / File | Permission Count | Delta vs Previous |
|---|---|---|
| **Docs page** (`roles/discoveryengine.agentspaceUser`) | **105** | Baseline from official documentation |
| [agentspaceUser_all.txt](./permissions_list/agentspaceUser_all.txt) (Live `gcloud iam roles describe`) | **112** | **+7** undocumented `discoveryengine.immersiveArtifacts.*` permissions |
| [custom_role_perms.txt](./permissions_list/custom_role_perms.txt) (`grep -v '^businessaicode\.'`) | **107** | **−5** `businessaicode.*` permissions (Antigravity / AGY) |
| [final_perms.txt](./permissions_list/final_perms.txt) (Project custom role permissions) | **93** | **−13** `cloudaicompanion.*` permissions (Cloud AI Companion / Code Assist)<br>**−1** `resourcemanager.projects.list` |

### Why These Exact Differences Exist

1. **Removed `businessaicode.*` (`−5` permissions):** Strips Antigravity (AGY) access and self-service license assignment (`businessaicode.locations.selfAssignLicense`).
2. **Removed `cloudaicompanion.*` (`−13` permissions):** Strips Cloud AI Companion / Gemini Code Assist chat, code completion, and license self-assignment (`cloudaicompanion.licenses.selfAssign`).
3. **Dropped `resourcemanager.projects.list` (`−1` permission):** GCP IAM does not allow `resourcemanager.projects.list` inside a **project-level** custom role (only valid in organization/folder custom roles).
4. **Included `discoveryengine.immersiveArtifacts.*` (`+7` permissions vs. docs):** Present in the live `roles/discoveryengine.agentspaceUser` role returned by `gcloud iam roles describe`, though not yet listed on the documentation page.

---

## Quick Start

### 1. Configure Environment Variables

Copy `.env.example` to `.env` and set your target Google Cloud project ID:

```bash
cp .env.example .env
```

Edit `.env`:

```ini
PROJECT_ID=your-gcp-project-id
CUSTOM_ROLE_ID=geminiEnterpriseUserNoCodeTools
CUSTOM_ROLE_TITLE="Gemini Enterprise User (No AGY / Code Assist)"
CUSTOM_ROLE_STAGE=GA
```

### 2. (Optional) Refresh Permissions from Live IAM

To re-extract the latest `roles/discoveryengine.agentspaceUser` permissions and recalculate `permissions_list/final_perms.txt` against your project's testable permissions:

```bash
./recon.sh
```

### 3. Create or Update the Custom IAM Role

Create (or update) the custom role in your GCP project using [final_perms.txt](./permissions_list/final_perms.txt):

```bash
./create_role.sh
```

---

## Caveats & Alternative Approach

- **Predefined Role Drift (Maintenance):** Custom IAM roles do not automatically inherit updates when Google adds new permissions to the built-in `roles/discoveryengine.agentspaceUser` role. Periodically re-run `./recon.sh` and `./create_role.sh` to keep the custom role synchronized with newly released Gemini Enterprise features.
- **Alternative — IAM Deny Policies:** Instead of maintaining a custom allow role, you can grant the standard built-in `roles/discoveryengine.agentspaceUser` role and attach an [IAM Deny Policy](https://cloud.google.com/iam/docs/deny-overview) (at the project, folder, or organization level) that explicitly denies `businessaicode.*` and `cloudaicompanion.*` permissions.

