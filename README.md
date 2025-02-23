# Kubernetes Service Account & Token Automation Script

This Bash script simplifies the process of creating a Kubernetes Service Account, Role, and RoleBinding, and retrieving a token for use in environments like GitHub Actions. It is designed to work with k3s clusters but should be adaptable to other Kubernetes distributions. The script ensures secure access to your Kubernetes cluster from external services by granting the Service Account minimal required permissions using RBAC.

## Features

*   **Namespace Configuration:** Allows you to specify the namespace to create resources in, defaulting to `default` if none is provided.
*   **Idempotent Creation:** Checks if the namespace, Service Account, Role, and RoleBinding already exist before attempting to create them, making the script safe to run multiple times.
*   **Automatic Token Retrieval:** Retrieves the generated Service Account token for use in your CI/CD pipelines or other automation tools.
*   **Explicit Secret Creation:** Handles cases where the service account token isn't automatically created in recent versions of k3s by explicitly creating a secret.
*   **RBAC Configuration:** Creates a Role with common permissions (get, list, watch, create, update, patch, delete) for common resources (pods, deployments, services, configmaps, secrets, ingresses, persistentvolumeclaims, persistentvolumes), which can be customized to fit your specific needs.
*   **Error Handling:** Includes robust error handling to exit gracefully if something goes wrong, such as missing `kubectl` or failed resource creation.
*   **Clear Instructions:** Provides clear instructions and reminders on how to securely store and use the generated token.

## Prerequisites

*   **kubectl:**  kubectl must be installed and configured to connect to your Kubernetes cluster.
*   **k3s (or other Kubernetes distribution):** The script is designed to create resources in a Kubernetes cluster.
*   **Sufficient Permissions:** You must have sufficient permissions in your Kubernetes cluster to create namespaces, service accounts, roles, and rolebindings.

## Usage

1.  **Download the Script:**  Download the `serviceAccount.sh` script to your local machine.

2.  **Make Executable:**  Make the script executable using the following command:

    ```bash
    chmod +x serviceAccount.sh
    ```

3.  **Run the Script:**

    *   **Default Namespace:** To run the script in the default namespace, execute:

        ```bash
        ./serviceAccount.sh
        ```

    *   **Specific Namespace:** To specify a namespace (e.g., `my-app`), execute:

        ```bash
        ./serviceAccount.sh my-app
        ```

4.  **Securely Store the Token:**  The script will output the generated token. **Immediately copy this token and store it securely.** The recommended way to use this token is by adding it as a *secret* to your GitHub repository (Settings -> Secrets -> Actions). Give it a descriptive name like `K8S_TOKEN`.

## Configuration

The following variables can be configured at the top of the script:

*   `NAMESPACE`:  The Kubernetes namespace to create the resources in (defaults to `default`).  Passed as the first argument to the script.
*   `SERVICE_ACCOUNT_NAME`:  The name of the Service Account to create (defaults to `github-actions-sa`).
*   `ROLE_NAME`:  The name of the Role to create (defaults to `github-actions-role`).
*   `SECRET_NAME`: The name of the kubernetes secret ( defaults to`${SERVICE_ACCOUNT_NAME}-token`)

**Important:**  Customize the `--resource` list in the `create_role` function to grant the *minimum* necessary permissions for your specific GitHub Actions workflows.  Granting excessive permissions can compromise the security of your cluster.

## GitHub Actions Workflow Example

Here's an example of how to use the generated token in a GitHub Actions workflow:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Deploy to Kubernetes
        run: |
          kubectl config set-cluster k3s --server="${{ secrets.K8S_API_SERVER }}" --insecure-skip-tls-verify=true # Or use --certificate-authority if you have a valid cert
          kubectl config set-credentials github-actions --token="${{ secrets.K8S_TOKEN }}"
          kubectl config set-context default --cluster=k3s --user=github-actions --namespace=my-app # Replace 'my-app' with your namespace
          kubectl config use-context default

          # Now you can run kubectl commands, e.g.,
          kubectl apply -f deployment.yaml
        env:
          K8S_API_SERVER: "https://<your_k3s_server_ip>:6443"  # Replace with your k3s API server address
