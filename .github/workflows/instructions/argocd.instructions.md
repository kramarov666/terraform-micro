---
applyTo: "**/*.yaml,**/*.yml,**/*.yaml.tftpl"
---

# Argo CD Conventions

## Application Management

- Use Argo CD Application resources to manage Kubernetes applications.
- Use ApplicationSet only when application generation or parameterization provides a clear benefit.
- Follow the existing App of Apps architecture.
- Keep each Application responsible for a clearly defined component.
- Use descriptive Application names.
- Keep Helm chart versions explicitly pinned.
- Do not use floating chart versions.

## Terraform Integration

- Terraform provisions AWS infrastructure.
- Terraform may inject dynamically generated AWS values into Argo CD Application manifests.
- Use Terraform templatefile() for dynamic Application manifests.
- Do not hardcode dynamically generated IAM role ARNs, KMS key ARNs, cluster names or endpoints.
- Keep static Helm configuration in the Kubernetes Git repository whenever possible.
- Avoid duplicating Terraform-generated values in multiple locations.

## Synchronization

- Use argocd.argoproj.io/sync-wave to express deployment dependencies.
- Use explicit sync waves for CRDs and their dependent resources.
- Ensure operators are available before deploying their Custom Resources.
- Do not assume sync waves create dependencies between separate Applications automatically.
- Use syncOptions only when their behavior is required.
- Do not enable automated pruning without considering resource deletion risks.

## Helm

- Prefer external values files stored in Git.
- Use multi-source Applications when Helm charts need additional Git-managed values or manifests.
- Keep Helm release names explicit where necessary.
- Do not duplicate values already defined in external values files.
- Keep chart versions pinned.

## Application Lifecycle

- Consider resource ownership before deleting or recreating Applications.
- Avoid unnecessary Application replacement.
- Preserve existing sync policies and ignoreDifferences rules unless explicitly requested.
- Explain potential orphaned resources before changing Application ownership.

## Validation

- Validate YAML syntax.
- Check Application source configuration.
- Check Helm chart and values compatibility.
- Verify repository paths and target revisions.
- Review sync waves and resource dependencies before deployment.

## Naming conventions
Name application files with well-defined application names that indicate their purpose, e.g., `<component>.yaml`