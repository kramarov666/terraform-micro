---
applyTo: "**/*.tf,**/*.tfvars,**/*.tftpl"
---

# Terraform Conventions

## General

- Use Terraform as the primary IaC tool.
- Follow the existing module structure.
- Use variables for configurable values.
- Use locals for derived values and reusable expressions.
- Avoid hardcoded AWS resource identifiers.
- Prefer data sources when referencing existing AWS resources.
- Keep resource definitions logically grouped.
- Use descriptive resource and variable names.

## Naming

- Use snake_case for Terraform resources, variables, outputs and locals.
- Use descriptive names that indicate the purpose of the resource.
- Follow existing AWS resource naming conventions.
- Use project and environment identifiers in resource names where appropriate.

## Variables and Outputs

- Define variable types explicitly.
- Add descriptions to variables and outputs.
- Define sensible defaults only when appropriate.
- Mark sensitive variables and outputs as sensitive.
- Avoid exposing secrets through outputs.

## Modules

- Keep modules focused on a single responsibility.
- Avoid creating modules for trivial configurations without a clear reuse benefit.
- Use explicit module inputs and outputs.
- Do not introduce unnecessary module dependencies.

## State and Lifecycle

- Do not change Terraform resource addresses without considering state migration.
- Never remove lifecycle protections without justification.
- Consider resource replacement and destruction risks.
- Preserve existing remote state configuration.

## Validation

Before considering Terraform changes complete, check:

- terraform fmt -check
- terraform validate

Never execute terraform apply or terraform destroy without explicit authorization.