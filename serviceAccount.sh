#!/bin/bash

# Script to create a Kubernetes Service Account, Role, RoleBinding, and get a token for GitHub Actions
# in a given namespace on a k3s cluster.
# Handles the case where k3s doesn't auto-create service account tokens.

set -euo pipefail  # Exit on error, unset variable, or broken pipe.

# --- Configuration ---
NAMESPACE=${1:-"default"} # Default to 'default' namespace if none provided
SERVICE_ACCOUNT_NAME="github-actions-sa"
ROLE_NAME="github-actions-role"
SECRET_NAME="${SERVICE_ACCOUNT_NAME}-token"  # Explicit secret name

# --- Helper Functions ---

create_namespace() {
  if ! kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
    echo "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
  else
    echo "Namespace '$NAMESPACE' already exists."
    return  # Exit the function, don't try to create it again
  fi

  # Error checking after creation
  if [[ $? -ne 0 ]]; then
    echo "ERROR: Failed to create namespace '$NAMESPACE'."
    exit 1
  fi
}

create_service_account() {
  if ! kubectl get serviceaccount "$SERVICE_ACCOUNT_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
    echo "Creating Service Account: $SERVICE_ACCOUNT_NAME in namespace: $NAMESPACE"
    kubectl create serviceaccount "$SERVICE_ACCOUNT_NAME" -n "$NAMESPACE"
  else
    echo "Service Account '$SERVICE_ACCOUNT_NAME' already exists in namespace '$NAMESPACE'."
    return  # Exit the function
  fi

  # Error checking after creation
  if [[ $? -ne 0 ]]; then
    echo "ERROR: Failed to create Service Account '$SERVICE_ACCOUNT_NAME' in namespace '$NAMESPACE'."
    exit 1
  fi
}

create_token_secret() {
  # Create the secret manually
  if ! kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
    echo "Creating token secret: $SECRET_NAME in namespace: $NAMESPACE"

    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: ${SERVICE_ACCOUNT_NAME}
type: kubernetes.io/service-account-token
EOF

  else
    echo "Token secret '$SECRET_NAME' already exists in namespace '$NAMESPACE'."
    return  # Exit the function
  fi

  # Error checking after creation
  if [[ $? -ne 0 ]]; then
    echo "ERROR: Failed to create token secret '$SECRET_NAME' in namespace '$NAMESPACE'."
    exit 1
  fi
}

create_role() {
  if ! kubectl get role "$ROLE_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
    echo "Creating Role: $ROLE_NAME in namespace: $NAMESPACE"
    kubectl create role "$ROLE_NAME" -n "$NAMESPACE" \
      --verb=get,list,watch,create,update,patch,delete \
      --resource=pods,deployments,services,configmaps,secrets,ingresses,persistentvolumeclaims,persistentvolumes
      # You can add more resources and verbs as needed for your GitHub Actions workflows.
  else
    echo "Role '$ROLE_NAME' already exists in namespace '$NAMESPACE'."
    return # Exit the function, don't try to create it again
  fi

  # Error checking after creation
  if [[ $? -ne 0 ]]; then
    echo "ERROR: Failed to create Role '$ROLE_NAME' in namespace '$NAMESPACE'."
    exit 1
  fi
}

create_role_binding() {
  if ! kubectl get rolebinding "$ROLE_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
    echo "Creating Role Binding: $ROLE_NAME in namespace: $NAMESPACE"
    kubectl create rolebinding "$ROLE_NAME" -n "$NAMESPACE" \
      --role="$ROLE_NAME" \
      --serviceaccount="$NAMESPACE":"$SERVICE_ACCOUNT_NAME"
  else
    echo "Role Binding '$ROLE_NAME' already exists in namespace '$NAMESPACE'."
    return # Exit the function, don't try to create it again
  fi

  # Error checking after creation
  if [[ $? -ne 0 ]]; then
    echo "ERROR: Failed to create Role Binding '$ROLE_NAME' in namespace '$NAMESPACE'."
    exit 1
  fi
}

get_token() {
  # Get the token from the Secret

  if ! kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
    echo "ERROR:  Token secret '$SECRET_NAME' does not exist."
    exit 1
  fi

  TOKEN=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.token}' | base64 --decode)

  if [ -z "$TOKEN" ]; then
    echo "ERROR:  Failed to retrieve token from secret '$SECRET_NAME'."
    exit 1
  fi

  echo "Successfully retrieved token."
  echo "TOKEN: $TOKEN"
  echo "Copy and store this token securely. It will be used in your GitHub Actions workflow."
}

# --- Main Script ---

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
  echo "ERROR: kubectl is not installed. Please install it before running this script."
  exit 1
fi

# Create the namespace if it doesn't exist
create_namespace

# Create the Service Account
create_service_account

# Create the token secret
create_token_secret

# Create the Role
create_role

# Create the Role Binding
create_role_binding

# Get the token
get_token

echo "Service account, role, role binding, and token secret created successfully in namespace '$NAMESPACE'."
echo "Remember to configure your GitHub Actions workflow with the retrieved token and Kubernetes cluster details."

exit 0
