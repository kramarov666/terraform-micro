# Repository Instructions for GitHub Copilot

## Project Context

This repository manages AWS infrastructure and Kubernetes workloads using Terraform, Amazon EKS, Argo CD and Helm.

The infrastructure follows an Infrastructure as Code approach. All infrastructure and Kubernetes configuration must be version-controlled.

## General Rules

- Follow the existing repository architecture and coding patterns.
- Prefer simple, maintainable and reusable solutions.
- Do not introduce unnecessary Terraform modules, abstractions or dependencies.
- Do not duplicate existing resources or configuration.
- Do not introduce new technologies without explaining why they are needed.
- Preserve existing resource names unless a rename is explicitly requested.
- Never silently remove existing functionality.
- Do not make assumptions about AWS resources, IAM permissions or Kubernetes dependencies.
- Before modifying existing infrastructure, understand its dependencies and lifecycle.
- Explain potentially breaking changes before implementing them.

## Infrastructure Architecture

- Terraform is responsible for AWS infrastructure provisioning.
- Argo CD is responsible for Kubernetes application deployment and reconciliation.
- Helm is the preferred deployment mechanism for third-party Kubernetes applications when an official Helm chart exists.
- Kubernetes manifests should be stored in the dedicated Git repository - "git@github.com:kramarov666/miracle6-k8s.git"
- Terraform-generated values must be used only when configuration depends on dynamically provisioned infrastructure resources.
- Avoid duplicating infrastructure configuration between Terraform and Kubernetes repositories.

## Security

- Follow the principle of least privilege.
- Never hardcode AWS credentials, access keys, passwords, tokens or private keys.
- Prefer IAM Roles for Service Accounts (IRSA) or EKS Pod Identity where appropriate.
- Use AWS KMS for encryption of supported infrastructure resources.
- Do not expose sensitive information in Terraform outputs or application manifests.
- Do not disable TLS verification or security controls to resolve deployment problems without explicit justification.

## Change Management

Before implementing changes:

1. Inspect the existing implementation.
2. Identify dependencies and potential side effects.
3. Explain the proposed changes.
4. Preserve existing behavior unless explicitly requested otherwise.

After implementing changes:

1. Validate syntax and configuration.
2. Identify required Terraform or Kubernetes validation commands.
3. Explain any manual deployment or migration steps.
4. Highlight potential destructive changes.
5. Never run "terraform" or "kubectl" commands without confirmation.

## Documentation

- Use clear and descriptive resource names.
- Document non-obvious architectural decisions.
- Keep documentation synchronized with configuration changes.
- Prefer explicit configuration over implicit behavior.