#!/bin/bash

# Azure Verified Modules (AVM) Bicep Fork Setup Script
# This script creates and sets up everything a contributor to the AVM Bicep project should need to get started

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

This script creates and sets up everything a contributor to the AVM Bicep project should need to get started with their contribution to a AVM Bicep Module.

Required Parameters:
  --repo-path <path>              Path to clone the forked repository (directory will be created if it doesn't exist)
  --subscription-id <id>          Azure subscription ID for test deployments
  --tenant-id <id>                Azure tenant ID
  --token-nameprefix <prefix>     Short (3-5 character) unique string for resource naming

Optional Parameters:
  --mgmt-group-id <id>           Management group ID for management group scoped deployments
  --spn-name <name>              Service Principal name (for non-OIDC, deprecated)
  --uami-name <name>             User Assigned Managed Identity name
  --uami-rsg-name <name>         Resource Group name for UAMI (default: rsg-avm-bicep-brm-fork-ci-oidc)
  --uami-location <location>     Location for UAMI and Resource Group
  --use-oidc <true|false>        Use OIDC authentication (default: true)
  --help                         Show this help message

Examples:
  # OIDC with subscription and management group scoped deployments
  $0 --repo-path "/home/user/repos" --mgmt-group-id "alz" --subscription-id "1b60f82b-d28e-4640-8cfa-e02d2ddb421a" --tenant-id "c3df6353-a410-40a1-b962-e91e45e14e4b" --token-nameprefix "ex123" --uami-location "uksouth"

  # OIDC with custom UAMI names
  $0 --repo-path "/home/user/repos" --subscription-id "1b60f82b-d28e-4640-8cfa-e02d2ddb421a" --tenant-id "c3df6353-a410-40a1-b962-e91e45e14e4b" --token-nameprefix "ex123" --uami-location "uksouth" --uami-name "my-uami-name" --uami-rsg-name "my-uami-rsg-name"

  # Non-OIDC (deprecated)
  $0 --repo-path "/home/user/repos" --subscription-id "1b60f82b-d28e-4640-8cfa-e02d2ddb421a" --tenant-id "c3df6353-a410-40a1-b962-e91e45e14e4b" --token-nameprefix "ex123" --use-oidc false

EOF
}

# Initialize variables
REPO_PATH=""
MGMT_GROUP_ID=""
SUBSCRIPTION_ID=""
TENANT_ID=""
TOKEN_NAMEPREFIX=""
SPN_NAME=""
UAMI_NAME=""
UAMI_RSG_NAME="rsg-avm-bicep-brm-fork-ci-oidc"
UAMI_LOCATION=""
USE_OIDC=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo-path)
            REPO_PATH="$2"
            shift 2
            ;;
        --mgmt-group-id)
            MGMT_GROUP_ID="$2"
            shift 2
            ;;
        --subscription-id)
            SUBSCRIPTION_ID="$2"
            shift 2
            ;;
        --tenant-id)
            TENANT_ID="$2"
            shift 2
            ;;
        --token-nameprefix)
            TOKEN_NAMEPREFIX="$2"
            shift 2
            ;;
        --spn-name)
            SPN_NAME="$2"
            shift 2
            ;;
        --uami-name)
            UAMI_NAME="$2"
            shift 2
            ;;
        --uami-rsg-name)
            UAMI_RSG_NAME="$2"
            shift 2
            ;;
        --uami-location)
            UAMI_LOCATION="$2"
            shift 2
            ;;
        --use-oidc)
            if [[ "$2" == "false" || "$2" == "False" || "$2" == "FALSE" ]]; then
                USE_OIDC=false
            else
                USE_OIDC=true
            fi
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown parameter: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$REPO_PATH" || -z "$SUBSCRIPTION_ID" || -z "$TENANT_ID" || -z "$TOKEN_NAMEPREFIX" ]]; then
    print_color $RED "Error: Missing required parameters"
    show_usage
    exit 1
fi

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    print_color $RED "The GitHub CLI is not installed. Please install the GitHub CLI and try again."
    print_color $RED "Install link for GitHub CLI: https://github.com/cli/cli#installation"
    exit 1
fi
print_color $GREEN "The GitHub CLI is installed..."

# Check if GitHub CLI is authenticated
if ! gh auth status &> /dev/null; then
    print_color $RED "Not authenticated to GitHub. Please authenticate to GitHub using the GitHub CLI command 'gh auth login', and try again."
    exit 1
fi

print_color $CYAN "Authenticated to GitHub with following details..."
echo ""
gh auth status
echo ""

# Ask the user to confirm if it's the correct GitHub account
while true; do
    print_color $YELLOW "Is the above GitHub account correct to continue with the fork setup of the 'Azure/bicep-registry-modules' repository? Please enter 'y' or 'n'."
    read -r user_input
    user_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')

    case $user_input in
        y)
            echo ""
            print_color $GREEN "User Confirmed. Proceeding with the GitHub account listed above..."
            echo ""
            break
            ;;
        n)
            echo ""
            print_color $RED "User stated incorrect GitHub account. Please switch to the correct GitHub account. You can do this in the GitHub CLI (gh) by logging out by running 'gh auth logout' and then logging back in with 'gh auth login'"
            exit 1
            ;;
        *)
            echo ""
            print_color $RED "Invalid input. Please enter 'y' or 'n'."
            echo ""
            ;;
    esac
done

# Fork and clone repository locally
print_color $MAGENTA "Changing to directory $REPO_PATH ..."

if [[ ! -d "$REPO_PATH" ]]; then
    print_color $YELLOW "Directory does not exist. Creating directory $REPO_PATH ..."
    mkdir -p "$REPO_PATH"
    echo ""
fi

cd "$REPO_PATH"
CREATED_DIRECTORY_LOCATION=$(pwd)
print_color $MAGENTA "Forking and cloning 'Azure/bicep-registry-modules' repository..."

if ! gh repo fork 'Azure/bicep-registry-modules' --default-branch-only --clone=true; then
    print_color $RED "Failed to fork and clone the 'Azure/bicep-registry-modules' repository. Please check the error message above, resolve any issues, and try again."
    exit 1
fi

CLONED_REPO_DIRECTORY_LOCATION="$CREATED_DIRECTORY_LOCATION/bicep-registry-modules"
echo ""
print_color $GREEN "Fork of 'Azure/bicep-registry-modules' created successfully in directory $CREATED_DIRECTORY_LOCATION ..."
echo ""
print_color $MAGENTA "Changing into cloned repository directory $CLONED_REPO_DIRECTORY_LOCATION ..."
cd "$CLONED_REPO_DIRECTORY_LOCATION"

# Check if user is logged in to Azure
if ! az account show &> /dev/null; then
    print_color $RED "You are not logged into Azure. Please log into Azure using the Azure CLI command 'az login' to the correct tenant and try again."
    exit 1
fi

USER_ACCOUNT=$(az account show --query "user.name" -o tsv)
print_color $GREEN "You are logged into Azure as '$USER_ACCOUNT' ..."

# Check user has access to desired subscription
if ! az account show --subscription "$SUBSCRIPTION_ID" &> /dev/null; then
    print_color $RED "You do not have access to the subscription with the ID of '$SUBSCRIPTION_ID'. Please ensure you have access to the subscription and try again."
    exit 1
fi
print_color $GREEN "You have access to the subscription with the ID of '$SUBSCRIPTION_ID' ..."
echo ""

# Get GitHub Login/Org Name
GITHUB_USER_RAW=$(gh api user)
GITHUB_ORG_NAME=$(echo "$GITHUB_USER_RAW" | jq -r '.login')
GITHUB_ORG_AND_REPO_NAME_COMBINED="$GITHUB_ORG_NAME/bicep-registry-modules"

# Create SPN if not using OIDC
if [[ "$USE_OIDC" == false ]]; then
    if [[ -z "$SPN_NAME" ]]; then
        print_color $YELLOW "No value provided for the SPN Name. Defaulting to 'spn-avm-bicep-brm-fork-ci-<GitHub Organization>' ..."
        SPN_NAME="spn-avm-bicep-brm-fork-ci-$GITHUB_ORG_NAME"
    fi

    print_color $MAGENTA "Creating Service Principal with name '$SPN_NAME'..."
    SPN_RESULT=$(az ad sp create-for-rbac --name "$SPN_NAME" --role Owner --scopes "/subscriptions/$SUBSCRIPTION_ID" --json-auth)
    SPN_APP_ID=$(echo "$SPN_RESULT" | jq -r '.clientId')
    SPN_CLIENT_SECRET=$(echo "$SPN_RESULT" | jq -r '.clientSecret')
    SPN_OBJECT_ID=$(az ad sp show --id "$SPN_APP_ID" --query "id" -o tsv)

    print_color $GREEN "New SPN created with a Display Name of '$SPN_NAME' and an Object ID of '$SPN_OBJECT_ID'."
    echo ""

    # Create RBAC Role Assignments for SPN on Management Group if provided
    if [[ -n "$MGMT_GROUP_ID" ]]; then
        print_color $MAGENTA "Creating RBAC Role Assignments of 'Owner' for the Service Principal Name (SPN) '$SPN_NAME' on the Management Group with the ID of '$MGMT_GROUP_ID' ..."
        sleep 60  # Wait for SPN to be available
        az role assignment create --assignee "$SPN_APP_ID" --role "Owner" --scope "/providers/Microsoft.Management/managementGroups/$MGMT_GROUP_ID"
        print_color $GREEN "RBAC Role Assignments of 'Owner' for the Service Principal Name (SPN) '$SPN_NAME' created successfully on the Management Group with the ID of '$MGMT_GROUP_ID'."
        echo ""
    else
        print_color $YELLOW "No Management Group ID provided, skipping RBAC Role Assignments upon Management Groups"
        echo ""
    fi
fi

# Create UAMI if using OIDC
if [[ "$USE_OIDC" == true ]]; then
    if [[ -z "$UAMI_NAME" ]]; then
        print_color $YELLOW "No value provided for the UAMI Name. Defaulting to 'id-avm-bicep-brm-fork-ci-<GitHub Organization>' ..."
        UAMI_NAME="id-avm-bicep-brm-fork-ci-$GITHUB_ORG_NAME"
    fi

    if [[ -z "$UAMI_RSG_NAME" ]]; then
        print_color $YELLOW "No value provided for the UAMI Resource Group Name. Defaulting to 'rsg-avm-bicep-brm-fork-ci-<GitHub Organization>-oidc' ..."
        UAMI_RSG_NAME="rsg-avm-bicep-brm-fork-ci-$GITHUB_ORG_NAME-oidc"
    fi

    print_color $MAGENTA "Selecting the subscription with the ID of '$SUBSCRIPTION_ID' to create Resource Group & UAMI in for OIDC ..."
    az account set --subscription "$SUBSCRIPTION_ID"
    echo ""

    if [[ -z "$UAMI_LOCATION" ]]; then
        print_color $YELLOW "No value provided for the UAMI Location ..."
        echo "Available locations:"
        az account list-locations --query "[?metadata.regionType=='Physical'].name" -o tsv | sort
        echo ""
        while true; do
            read -p "Please enter the location for the UAMI and the Resource Group to be created in for OIDC deployments (e.g. 'uksouth' or 'eastus'): " UAMI_LOCATION
            UAMI_LOCATION=$(echo "$UAMI_LOCATION" | tr '[:upper:]' '[:lower:]')

            # Validate location
            if az account list-locations --query "[?name=='$UAMI_LOCATION']" -o tsv | grep -q "$UAMI_LOCATION"; then
                break
            else
                print_color $YELLOW "Invalid location provided. Please provide a valid location from the list above."
            fi
        done
    fi

    print_color $MAGENTA "Creating Resource Group for UAMI with the name of '$UAMI_RSG_NAME' and location of '$UAMI_LOCATION'..."
    az group create --name "$UAMI_RSG_NAME" --location "$UAMI_LOCATION"
    print_color $GREEN "New Resource Group created with a Name of '$UAMI_RSG_NAME' and a Location of '$UAMI_LOCATION'."
    echo ""

    print_color $MAGENTA "Creating UAMI with the name of '$UAMI_NAME' and location of '$UAMI_LOCATION' in the Resource Group with the name of '$UAMI_RSG_NAME'..."
    UAMI_RESULT=$(az identity create --resource-group "$UAMI_RSG_NAME" --name "$UAMI_NAME" --location "$UAMI_LOCATION")
    UAMI_CLIENT_ID=$(echo "$UAMI_RESULT" | jq -r '.clientId')
    UAMI_PRINCIPAL_ID=$(echo "$UAMI_RESULT" | jq -r '.principalId')
    print_color $GREEN "New UAMI created with a Name of '$UAMI_NAME' and an Object ID of '$UAMI_PRINCIPAL_ID'."
    echo ""

    # Create Federated Credentials for UAMI for OIDC
    print_color $MAGENTA "Creating Federated Credentials for the User-Assigned Managed Identity Name (UAMI) for OIDC ... '$UAMI_NAME' for OIDC ..."
    az identity federated-credential create \
        --name "avm-gh-env-validation" \
        --identity-name "$UAMI_NAME" \
        --resource-group "$UAMI_RSG_NAME" \
        --issuer "https://token.actions.githubusercontent.com" \
        --subject "repo:$GITHUB_ORG_AND_REPO_NAME_COMBINED:environment:avm-validation" \
        --audiences "api://AzureADTokenExchange"
    echo ""

    # Create RBAC Role Assignments for UAMI
    print_color $YELLOW "Starting 120 second sleep to allow the UAMI to be created and available for RBAC Role Assignments (eventual consistency) ..."
    sleep 120

    print_color $MAGENTA "Creating RBAC Role Assignments of 'Owner' for the User-Assigned Managed Identity Name (UAMI) '$UAMI_NAME' on the Subscription with the ID of '$SUBSCRIPTION_ID' ..."
    az role assignment create --assignee "$UAMI_PRINCIPAL_ID" --role "Owner" --scope "/subscriptions/$SUBSCRIPTION_ID"
    print_color $GREEN "RBAC Role Assignments of 'Owner' for the User-Assigned Managed Identity Name (UAMI) '$UAMI_NAME' created successfully on the Subscription with the ID of '$SUBSCRIPTION_ID'."
    echo ""

    if [[ -z "$MGMT_GROUP_ID" ]]; then
        print_color $YELLOW "No Management Group ID provided as input parameter, skipping RBAC Role Assignments upon Management Groups"
        echo ""
    else
        print_color $MAGENTA "Creating RBAC Role Assignments of 'Owner' for the User-Assigned Managed Identity Name (UAMI) '$UAMI_NAME' on the Management Group with the ID of '$MGMT_GROUP_ID' ..."
        az role assignment create --assignee "$UAMI_PRINCIPAL_ID" --role "Owner" --scope "/providers/Microsoft.Management/managementGroups/$MGMT_GROUP_ID"
        print_color $GREEN "RBAC Role Assignments of 'Owner' for the User-Assigned Managed Identity Name (UAMI) '$UAMI_NAME' created successfully on the Management Group with the ID of '$MGMT_GROUP_ID'."
        echo ""
    fi
fi

# Set GitHub Repo Secrets (non-OIDC)
if [[ "$USE_OIDC" == false ]]; then
    print_color $MAGENTA "Setting GitHub Secrets on forked repository (non-OIDC) '$GITHUB_ORG_AND_REPO_NAME_COMBINED' ..."
    print_color $CYAN "Creating and formatting secret 'AZURE_CREDENTIALS' with details from SPN creation process (non-OIDC) and other parameter inputs ..."

    FORMATTED_AZURE_CREDENTIALS_SECRET=$(jq -n \
        --arg clientId "$SPN_APP_ID" \
        --arg clientSecret "$SPN_CLIENT_SECRET" \
        --arg subscriptionId "$SUBSCRIPTION_ID" \
        --arg tenantId "$TENANT_ID" \
        '{clientId: $clientId, clientSecret: $clientSecret, subscriptionId: $subscriptionId, tenantId: $tenantId}')

    if [[ -n "$MGMT_GROUP_ID" ]]; then
        echo "$MGMT_GROUP_ID" | gh secret set ARM_MGMTGROUP_ID -R "$GITHUB_ORG_AND_REPO_NAME_COMBINED"
    fi
    echo "$SUBSCRIPTION_ID" | gh secret set ARM_SUBSCRIPTION_ID -R "$GITHUB_ORG_AND_REPO_NAME_COMBINED"
    echo "$TENANT_ID" | gh secret set ARM_TENANT_ID -R "$GITHUB_ORG_AND_REPO_NAME_COMBINED"
    echo "$FORMATTED_AZURE_CREDENTIALS_SECRET" | gh secret set AZURE_CREDENTIALS -R "$GITHUB_ORG_AND_REPO_NAME_COMBINED"
    echo "$TOKEN_NAMEPREFIX" | gh secret set TOKEN_NAMEPREFIX -R "$GITHUB_ORG_AND_REPO_NAME_COMBINED"

    echo ""
    print_color $GREEN "Successfully created and set GitHub Secrets (non-OIDC) on forked repository '$GITHUB_ORG_AND_REPO_NAME_COMBINED' ..."
    echo ""
fi

# Set GitHub Repo Secrets & Environment (OIDC)
if [[ "$USE_OIDC" == true ]]; then
    print_color $MAGENTA "Setting GitHub Environment (avm-validation) and required Secrets on forked repository (OIDC) '$GITHUB_ORG_AND_REPO_NAME_COMBINED' ..."
    print_color $CYAN "Creating 'avm-validation' environment on forked repository ..."

    GITHUB_ENVIRONMENT=$(gh api --method PUT -H "Accept: application/vnd.github+json" "repos/$GITHUB_ORG_AND_REPO_NAME_COMBINED/environments/avm-validation")
    GITHUB_ENVIRONMENT_NAME=$(echo "$GITHUB_ENVIRONMENT" | jq -r '.name')

    if [[ "$GITHUB_ENVIRONMENT_NAME" != "avm-validation" ]]; then
        print_color $RED "Failed to create 'avm-validation' environment on forked repository. Please check the error message above, resolve any issues, and try again."
        exit 1
    fi

    print_color $GREEN "Successfully created 'avm-validation' environment on forked repository ..."
    echo ""

    print_color $CYAN "Creating and formatting secrets for 'avm-validation' environment with details from UAMI creation process (OIDC) and other parameter inputs ..."
    echo "$UAMI_CLIENT_ID" | gh secret set VALIDATE_CLIENT_ID -R "$GITHUB_ORG_AND_REPO_NAME_COMBINED" -e 'avm-validation'
    echo "$SUBSCRIPTION_ID" | gh secret set VALIDATE_SUBSCRIPTION_ID -R "$GITHUB_ORG_AND_REPO_NAME_COMBINED" -e 'avm-validation'
    echo "$TENANT_ID" | gh secret set VALIDATE_TENANT_ID -R "$GITHUB_ORG_AND_REPO_NAME_COMBINED" -e 'avm-validation'

    print_color $CYAN "Creating and formatting secrets for repo with details from UAMI creation process (OIDC) and other parameter inputs ..."
    if [[ -n "$MGMT_GROUP_ID" ]]; then
        echo "$MGMT_GROUP_ID" | gh secret set ARM_MGMTGROUP_ID -R "$GITHUB_ORG_AND_REPO_NAME_COMBINED"
    fi
    echo "$SUBSCRIPTION_ID" | gh secret set ARM_SUBSCRIPTION_ID -R "$GITHUB_ORG_AND_REPO_NAME_COMBINED"
    echo "$TENANT_ID" | gh secret set ARM_TENANT_ID -R "$GITHUB_ORG_AND_REPO_NAME_COMBINED"
    echo "$TOKEN_NAMEPREFIX" | gh secret set TOKEN_NAMEPREFIX -R "$GITHUB_ORG_AND_REPO_NAME_COMBINED"

    echo ""
    print_color $GREEN "Successfully created and set GitHub Secrets in 'avm-validation' environment and repo (OIDC) on forked repository '$GITHUB_ORG_AND_REPO_NAME_COMBINED' ..."
    echo ""
fi

print_color $MAGENTA "Opening browser so you can enable GitHub Actions on newly forked repository '$GITHUB_ORG_AND_REPO_NAME_COMBINED' ..."
print_color $YELLOW "Please click on the green button stating 'I understand my workflows, go ahead and enable them' to enable actions/workflows on your forked repository via the website that has appeared in your browser window and then return to this terminal session to continue ..."

# Try to open browser (works on most systems)
if command -v xdg-open &> /dev/null; then
    xdg-open "https://github.com/$GITHUB_ORG_AND_REPO_NAME_COMBINED/actions" &
elif command -v open &> /dev/null; then
    open "https://github.com/$GITHUB_ORG_AND_REPO_NAME_COMBINED/actions" &
elif command -v start &> /dev/null; then
    start "https://github.com/$GITHUB_ORG_AND_REPO_NAME_COMBINED/actions" &
else
    print_color $YELLOW "Please manually open: https://github.com/$GITHUB_ORG_AND_REPO_NAME_COMBINED/actions"
fi
echo ""

GITHUB_WORKFLOW_PLATFORM_TOGGLE_WORKFLOWS=".Platform - Toggle AVM workflows"
GITHUB_WORKFLOW_PLATFORM_TOGGLE_WORKFLOWS_FILENAME="platform.toggle-avm-workflows.yml"

while true; do
    print_color $YELLOW "Did you successfully enable the GitHub Actions/Workflows on your forked repository '$GITHUB_ORG_AND_REPO_NAME_COMBINED'? Please enter 'y' or 'n'."
    read -r user_input
    user_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')

    case $user_input in
        y)
            echo ""
            print_color $GREEN "User Confirmed. Proceeding to trigger workflow of '$GITHUB_WORKFLOW_PLATFORM_TOGGLE_WORKFLOWS' to disable all workflows as per: https://azure.github.io/Azure-Verified-Modules/contributing/bicep/bicep-contribution-flow/enable-or-disable-workflows/..."
            echo ""
            break
            ;;
        n)
            echo ""
            print_color $YELLOW "User stated no. Ending script here. Please review and complete any of the steps you have not completed, likely just enabling GitHub Actions/Workflows on your forked repository and then disabling all workflows as per: https://azure.github.io/Azure-Verified-Modules/contributing/bicep/bicep-contribution-flow/enable-or-disable-workflows/"
            exit 0
            ;;
        *)
            echo ""
            print_color $RED "Invalid input. Please enter 'y' or 'n'."
            echo ""
            ;;
    esac
done

print_color $MAGENTA "Setting Read/Write Workflow permissions on forked repository '$GITHUB_ORG_AND_REPO_NAME_COMBINED' ..."
gh api --method PUT -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" "/repos/$GITHUB_ORG_AND_REPO_NAME_COMBINED/actions/permissions/workflow" -f "default_workflow_permissions=write"
echo ""

print_color $MAGENTA "Triggering '$GITHUB_WORKFLOW_PLATFORM_TOGGLE_WORKFLOWS' on '$GITHUB_ORG_AND_REPO_NAME_COMBINED' ..."
echo ""
gh workflow run "$GITHUB_WORKFLOW_PLATFORM_TOGGLE_WORKFLOWS" -R "$GITHUB_ORG_AND_REPO_NAME_COMBINED"
echo ""

print_color $YELLOW "Starting 120 second sleep to allow the workflow run to complete ..."
sleep 120
echo ""

print_color $MAGENTA "Workflow '$GITHUB_WORKFLOW_PLATFORM_TOGGLE_WORKFLOWS' on '$GITHUB_ORG_AND_REPO_NAME_COMBINED' should have now completed, opening workflow in browser so you can check ..."

# Try to open browser for workflow results
if command -v xdg-open &> /dev/null; then
    xdg-open "https://github.com/$GITHUB_ORG_AND_REPO_NAME_COMBINED/actions/workflows/$GITHUB_WORKFLOW_PLATFORM_TOGGLE_WORKFLOWS_FILENAME" &
elif command -v open &> /dev/null; then
    open "https://github.com/$GITHUB_ORG_AND_REPO_NAME_COMBINED/actions/workflows/$GITHUB_WORKFLOW_PLATFORM_TOGGLE_WORKFLOWS_FILENAME" &
elif command -v start &> /dev/null; then
    start "https://github.com/$GITHUB_ORG_AND_REPO_NAME_COMBINED/actions/workflows/$GITHUB_WORKFLOW_PLATFORM_TOGGLE_WORKFLOWS_FILENAME" &
else
    print_color $YELLOW "Please manually open: https://github.com/$GITHUB_ORG_AND_REPO_NAME_COMBINED/actions/workflows/$GITHUB_WORKFLOW_PLATFORM_TOGGLE_WORKFLOWS_FILENAME"
fi
echo ""

print_color $GREEN "Script execution complete. Fork of '$GITHUB_ORG_AND_REPO_NAME_COMBINED' created and configured and cloned to '$CLONED_REPO_DIRECTORY_LOCATION' as per Bicep contribution guide: https://azure.github.io/Azure-Verified-Modules/contributing/bicep/bicep-contribution-flow/ you are now ready to proceed from step 4. Opening the Bicep Contribution Guide for you to review and continue..."

# Try to open browser for contribution guide
if command -v xdg-open &> /dev/null; then
    xdg-open "https://azure.github.io/Azure-Verified-Modules/contributing/bicep/bicep-contribution-flow/" &
elif command -v open &> /dev/null; then
    open "https://azure.github.io/Azure-Verified-Modules/contributing/bicep/bicep-contribution-flow/" &
elif command -v start &> /dev/null; then
    start "https://azure.github.io/Azure-Verified-Modules/contributing/bicep/bicep-contribution-flow/" &
else
    print_color $YELLOW "Please manually open: https://azure.github.io/Azure-Verified-Modules/contributing/bicep/bicep-contribution-flow/"
fi

print_color $GREEN "Setup completed successfully!"
