---
applyTo: "**/*.tf,**/*.tfvars,**/*.tftpl,**/*.yaml,**/*.yml"
---

# AWS Engineering Standards and Conventions

## 1. General AWS Principles

- Follow AWS Well-Architected Framework principles.
- Apply the principle of least privilege to all AWS resources and IAM permissions.
- Prefer managed AWS services over self-managed infrastructure when appropriate.
- Use Infrastructure as Code for all AWS infrastructure.
- Prefer native AWS integrations over custom implementations.
- Design infrastructure to be secure, scalable, observable and maintainable.
- Avoid unnecessary infrastructure complexity and operational overhead.
- Use explicit configuration instead of relying on undocumented defaults.
- Consider resource dependencies, lifecycle and failure scenarios before implementing changes.
- Do not introduce additional AWS services without explaining their operational and financial impact.

## 2. AWS Resource Naming Conventions

Use the following general naming pattern for AWS resources:

`<project>-<environment>-<component>-<resource>`

Examples:

- `miracle6-prod-eks`
- `miracle6-stg-vpc`
- `miracle6-prod-ebs-kms`
- `miracle6-prod-vault-kms`
- `miracle6-prod-karpenter-node`
- `miracle6-prod-eks-cluster`

### Naming Rules

- Use lowercase letters.
- Use hyphens as word separators where the AWS service permits them.
- Avoid spaces and special characters.
- Use descriptive names instead of generic names.
- Include the project identifier when applicable.
- Include the environment identifier for environment-specific resources.
- Include the component or service name.
- Use consistent abbreviations across the repository.
- Avoid unnecessary duplication of resource type information.
- Follow AWS-specific naming restrictions for each service.
- Do not assume all AWS services support the same naming format or length.

### Standard Identifiers

Use these standard identifiers:

| Identifier | Meaning |
|---|---|
| `dev` | Development |
| `stg` | Staging |
| `preprod` | Pre-production |
| `prod` | Production |
| `eks` | Elastic Kubernetes Service |
| `vpc` | Virtual Private Cloud |
| `kms` | Key Management Service |
| `iam` | Identity and Access Management |
| `alb` | Application Load Balancer |
| `ebs` | Elastic Block Store |
| `s3` | Simple Storage Service |

Do not introduce alternative abbreviations for existing components.

### Terraform Naming vs AWS Resource Naming

Keep Terraform identifiers and AWS resource names separate.

Terraform identifiers must use snake_case:

- `aws_eks_cluster.main`
- `aws_kms_key.ebs`
- `aws_iam_role.karpenter_controller`

AWS resource names should follow the naming convention defined above.

Example:

```hcl
resource "aws_kms_key" "ebs" {
  description             = "KMS key for EBS encryption"
  deletion_window_in_days = 10

  tags = {
    Name = "${var.project_name}-${var.environment}-ebs-kms"
  }
}
```

## 3. Mandatory Resource Tagging

Use consistent tags for supported AWS resources.

Standard tags:

| Tag | Description |
|---|---|
| `Name` | Human-readable resource name |
| `Project` | Project identifier |
| `Environment` | Deployment environment |
| `ManagedBy` | Infrastructure management tool |
| `CreatedBy` | Resource creator |

Example:

```hcl
tags = {
  Name        = "${var.project_name}-${var.environment}-eks"
  Project     = var.project_name
  Environment = var.environment
  ManagedBy   = "terraform"
  CreatedBy   = "terraform"
}
```

### Tagging Rules

- Apply tags consistently to all supported AWS resources.
- Prefer provider-level default tags where appropriate.
- Allow resource-specific tags to extend common tags.
- Do not overwrite mandatory tags with conflicting resource-level values.
- Use consistent capitalization for tag keys.
- Do not include credentials, secrets or sensitive information in tags.

## 4. AWS Regions and Accounts

- Use explicitly configured AWS regions.
- Do not hardcode AWS regions in resource definitions.
- Use Terraform variables or provider configuration for region selection.
- Keep AWS account IDs configurable when cross-account deployments are required.
- Do not hardcode AWS account IDs in reusable modules.
- Prefer AWS data sources and provider information for account-specific references.
- Use explicit provider aliases for multi-account or multi-region deployments.
- Avoid creating resources in unexpected regions.

Example:

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      CreatedBy   = "terraform-bootstrap"
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = var.project_name
    }
  }
}
```

## 5. IAM and Access Management

- Follow least-privilege access principles.
- Avoid wildcard permissions in IAM policies unless technically necessary and justified.
- Separate IAM roles by workload and responsibility.
- Prefer IAM roles over IAM users for workloads and automation.
- Never store AWS access keys in Terraform code, Kubernetes manifests or GitHub repositories.
- Use GitHub Actions OIDC for CI/CD authentication.
- Prefer EKS Pod Identity or IRSA for Kubernetes workload authentication.
- Separate controller IAM roles from worker node IAM roles.
- Use dedicated IAM policies for individual workloads where practical.
- Restrict trust policies to explicitly authorized principals.
- Avoid using the AWS account root principal for application workloads.
- Document permissions that require broader access than normally expected.

### IAM Naming

Use descriptive role and policy names:

- `miracle6-prod-karpenter-controller`
- `miracle6-prod-karpenter-node`
- `miracle6-prod-vault-unseal`
- `miracle6-prod-ebs-csi`
- `miracle6-prod-alb-controller`

Separate controller and node roles. Never reuse a node role as a controller role.

## 6. Encryption and AWS KMS

- Enable encryption at rest for supported AWS services.
- Prefer customer-managed KMS keys when custom key policies, rotation or separation of duties are required.
- Use separate KMS keys for logically different security boundaries.
- Enable automatic key rotation where supported and appropriate.
- Configure key deletion windows explicitly.
- Avoid accidental KMS key deletion.
- Use descriptive KMS aliases.
- Configure key policies with explicit principals and required permissions.
- Consider service grants and AWS service integration requirements.
- Do not assume that IAM permissions alone are sufficient for KMS access.
- Avoid unrestricted KMS key policies.
- Never expose sensitive encryption material.

### KMS Naming

Key aliases must follow:

`alias/<project>-<environment>-<purpose>`

Examples:

- `alias/miracle6-prod-ebs`
- `alias/miracle6-prod-vault`
- `alias/miracle6-prod-s3`

## 7. Networking and VPC

- Use private subnets for internal workloads and EKS worker nodes where appropriate.
- Use public subnets only for resources requiring public network access.
- Avoid assigning public IP addresses to internal workloads.
- Use explicit CIDR allocation strategies.
- Prevent subnet CIDR overlaps.
- Design subnet allocation to allow future expansion.
- Use dedicated route tables where network isolation requires them.
- Apply restrictive security group rules.
- Avoid unrestricted ingress and egress rules.
- Prefer security group references over hardcoded CIDRs when appropriate.
- Use VPC endpoints for private access to supported AWS services where beneficial.
- Consider NAT Gateway costs and availability requirements.
- Enable VPC Flow Logs where required for network visibility and auditing.

### Networking Naming

Examples:

- `miracle6-prod-vpc`
- `miracle6-prod-public-subnet-1`
- `miracle6-prod-private-subnet-1`
- `miracle6-prod-eks-security-group`
- `miracle6-prod-private-route-table`

## 8. Amazon EKS

- Use managed EKS control planes.
- Keep Kubernetes versions explicitly configured.
- Prefer managed EKS add-ons when appropriate.
- Pin add-on versions where version control is required.
- Separate system workloads from application workloads.
- Maintain dedicated system node groups for critical infrastructure controllers.
- Use Karpenter for dynamic workload provisioning where appropriate.
- Avoid scheduling critical infrastructure controllers exclusively on Karpenter-managed nodes.
- Apply appropriate node selectors, tolerations and affinity rules.
- Use dedicated IAM roles for Kubernetes controllers.
- Enable encryption for persistent storage.
- Prefer the AWS EBS CSI Driver over deprecated in-tree storage integrations.
- Use Pod Identity or IRSA for AWS access from Kubernetes workloads.
- Avoid granting unnecessary permissions to worker node roles.
- Consider cluster upgrades and add-on compatibility before changing Kubernetes versions.

### EKS Naming

Examples:

- `miracle6-prod-eks`
- `miracle6-prod-system-nodes`
- `miracle6-prod-karpenter-nodes`
- `miracle6-prod-eks-cluster-role`
- `miracle6-prod-eks-node-role`

## 9. Storage and Backup

- Enable encryption for supported storage resources.
- Use customer-managed KMS keys when required by the security architecture.
- Define retention and backup policies explicitly.
- Consider recovery requirements before configuring deletion protection.
- Avoid storing persistent application data on ephemeral compute resources.
- Prefer lifecycle policies for S3 objects where appropriate.
- Consider versioning for important S3 buckets.
- Enable S3 public access blocking unless public access is explicitly required.
- Use appropriate EBS volume types based on workload requirements.
- Do not delete persistent storage resources without evaluating data loss implications.

## 10. Monitoring, Logging and Auditing

- Enable CloudTrail for AWS API auditing.
- Use CloudWatch for AWS service metrics and logs where appropriate.
- Enable relevant EKS control plane logging.
- Use VPC Flow Logs for network auditing where required.
- Configure monitoring for critical infrastructure components.
- Avoid logging credentials, tokens and sensitive information.
- Consider log retention and storage costs.
- Prefer centralized logging for multi-environment deployments.

## 11. High Availability and Disaster Recovery

- Design production infrastructure according to defined availability requirements.
- Use multiple Availability Zones where supported and appropriate.
- Avoid unnecessary single points of failure.
- Define backup and recovery strategies for stateful services.
- Consider RTO and RPO when designing disaster recovery.
- Validate restoration procedures rather than assuming backups are sufficient.
- Document dependencies between AWS services and Kubernetes workloads.
- Consider regional failure scenarios for critical workloads.

## 12. Cost Optimization

- Prefer right-sized resources.
- Avoid unnecessarily oversized EC2 instances and EBS volumes.
- Consider Savings Plans and Reserved Instances where appropriate.
- Review NAT Gateway, load balancer and data transfer costs.
- Use Karpenter consolidation where suitable.
- Avoid provisioning resources that are not required.
- Consider the cost impact of high-availability configurations.
- Do not sacrifice required security or availability controls solely to reduce cost.

## 13. Terraform and AWS Integration

- Use the official AWS Terraform provider.
- Follow existing provider version constraints.
- Prefer official AWS Terraform resources and data sources.
- Avoid using local-exec or external provisioners for AWS resource management.
- Use Terraform modules for reusable infrastructure components.
- Keep resource dependencies explicit where necessary.
- Avoid unnecessary depends_on declarations when Terraform can infer dependencies.
- Use Terraform outputs to expose required infrastructure identifiers.
- Do not hardcode generated ARNs, IDs or endpoints in dependent resources.
- Keep environment-specific configuration separate from reusable infrastructure modules.
- Use consistent AWS provider aliases when managing multiple accounts or regions.

## 14. Validation and Change Safety

Before considering AWS infrastructure changes complete:

- Run terraform fmt -check.
- Run terraform validate.
- Review Terraform plan.
- Check IAM policies and trust relationships.
- Verify resource naming and mandatory tags.
- Verify encryption configuration.
- Review security group rules.
- Check resource replacement and destruction implications.
- Verify dependencies between AWS resources and Kubernetes workloads.

Never execute terraform apply or terraform destroy without explicit authorization.

Always highlight potentially destructive changes and their impact before implementation.