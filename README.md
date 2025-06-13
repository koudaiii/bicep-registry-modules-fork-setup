# Bicep Registry Modules Fork Setup

[日本語](./README_ja.md)

A script that automates all the necessary setup to start contributing to the Azure Verified Modules (AVM) Bicep project.

## Overview

This script automates the following processes:

- Fork creation of the Azure/bicep-registry-modules repository
- Local cloning
- Creation of Azure Service Principal (SPN) or User Assigned Managed Identity (UAMI)
- Authentication setup for GitHub Actions (OIDC or legacy authentication)
- GitHub repository secrets configuration
- Workflow enablement and configuration

## Prerequisites

The following tools must be installed and properly configured:

- [GitHub CLI (gh)](https://github.com/cli/cli#installation)
- [Azure CLI (az)](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [jq](https://stedolan.github.io/jq/download/)

The following authentication must also be completed:

- GitHub CLI: `gh auth login`
- Azure CLI: `az login`

## Usage

Run the following command from the repository root directory:

```bash
./script/fork-setup.sh [OPTIONS]
```

### Required Parameters

- `--repo-path <path>`: Path to clone the forked repository (directory will be created if it doesn't exist)
- `--subscription-id <id>`: Azure subscription ID for test deployments
- `--tenant-id <id>`: Azure tenant ID
- `--token-nameprefix <prefix>`: Short (3-5 character) unique string for resource naming

### Optional Parameters

- `--mgmt-group-id <id>`: Management group ID for management group scoped deployments
- `--spn-name <name>`: Service Principal name (for non-OIDC, deprecated)
- `--uami-name <name>`: User Assigned Managed Identity name
- `--uami-rsg-name <name>`: Resource Group name for UAMI (default: rsg-avm-bicep-brm-fork-ci-oidc)
- `--uami-location <location>`: Location for UAMI and Resource Group
- `--use-oidc <true|false>`: Use OIDC authentication (default: true)
- `--help`: Show help message

## Examples

### OIDC authentication with subscription and management group scoped deployments

```bash
./script/fork-setup.sh \
  --repo-path "/home/user/repos" \
  --mgmt-group-id "alz" \
  --subscription-id "1b60f82b-d28e-4640-8cfa-e02d2ddb421a" \
  --tenant-id "c3df6353-a410-40a1-b962-e91e45e14e4b" \
  --token-nameprefix "ex123" \
  --uami-location "uksouth"
```

### OIDC authentication with custom UAMI name

```bash
./script/fork-setup.sh \
  --repo-path "/home/user/repos" \
  --subscription-id "1b60f82b-d28e-4640-8cfa-e02d2ddb421a" \
  --tenant-id "c3df6353-a410-40a1-b962-e91e45e14e4b" \
  --token-nameprefix "ex123" \
  --uami-location "uksouth" \
  --uami-name "my-uami-name" \
  --uami-rsg-name "my-uami-rsg-name"
```

### Non-OIDC authentication (deprecated)

```bash
./script/fork-setup.sh \
  --repo-path "/home/user/repos" \
  --subscription-id "1b60f82b-d28e-4640-8cfa-e02d2ddb421a" \
  --tenant-id "c3df6353-a410-40a1-b962-e91e45e14e4b" \
  --token-nameprefix "ex123" \
  --use-oidc false
```

## Script Operation

1. **Prerequisites Check**: Verify GitHub CLI and Azure CLI authentication status
2. **Repository Fork**: Fork Azure/bicep-registry-modules and clone locally
3. **Azure Authentication Setup**:
   - When using OIDC: Create User Assigned Managed Identity and federated credentials
   - When not using OIDC: Create Service Principal
4. **RBAC Configuration**: Assign Owner role to required scopes (subscription, management group)
5. **GitHub Configuration**:
   - Configure repository secrets
   - Create environment (avm-validation)
   - Enable workflows
6. **Workflow Configuration**: Disable all workflows (following contribution guidelines)

## Important Notes

- The script can be run from any location, but running from this repository root is recommended
- Using OIDC authentication is strongly recommended (for security reasons)
- If no management group ID is provided, management group scope permissions will not be configured
- After script execution, GitHub Actions must be manually enabled
- All workflows will be disabled after setup (following contribution guidelines)

## Troubleshooting

### Common Issues

1. **GitHub CLI authentication error**: Re-authenticate with `gh auth login`
2. **Azure CLI authentication error**: Log in to the appropriate tenant with `az login`
3. **Permission error**: Ensure you have Owner permissions on the specified subscription
4. **Resource name conflict**: Use a unique value for `--token-nameprefix`

### Log Review

The script outputs detailed logs during execution. If errors occur, check the error messages and take appropriate action.

## Reference Links

- [Azure Verified Modules - Bicep Contribution Flow](https://azure.github.io/Azure-Verified-Modules/contributing/bicep/bicep-contribution-flow/)
- [GitHub CLI Documentation](https://cli.github.com/manual/)
- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)

## License

This script is provided under the same license as the original Azure/bicep-registry-modules repository.
