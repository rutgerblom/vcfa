###############################################################################
# VMware Cloud Foundation Automation (VCFA) – Variables
# ---------------------------------------------------------------------------
# This file defines all configurable inputs for the Terraform configuration.
# Each variable includes a short explanation and example usage.
###############################################################################

# =============================================================================
# 🔐 Provider connection
# =============================================================================

variable "vcfa_url" {
  type        = string
  description = "Base URL for the VCFA API (e.g. https://pod-240-vcf-automation.sddc.lab)"
}

variable "vcfa_organization" {
  type        = string
  description = "Provider organization name (typically 'System')"
}

variable "vcfa_allow_unverified_ssl" {
  type        = bool
  description = "Allow unverified SSL certificates (set to true for lab/test environments)"
  default     = true
}

# =============================================================================
# 🏗️ Organization generation
# =============================================================================
# The orgs are created automatically in numbered sequences (prefix + count).
# Example: [{ prefix = \"org_it\", count = 35 }, { prefix = \"org_ot\", count = 35 }]
# will create org_it_001–035 and org_ot_001–035.

variable "org_groups" {
  description = "List of org groups to create; each group defines a prefix and how many to create"
  type = list(object({
    prefix = string
    count  = number
  }))
  default = [
    { prefix = "org_it", count = 35 },
    { prefix = "org_ot", count = 35 },
  ]
}

variable "org_description_template" {
  description = "Description for each org; use $${name} as placeholder for the org name"
  type        = string
  default     = "Created by Terraform $${name}"
}

variable "org_enabled" {
  description = "Whether new orgs are enabled immediately after creation"
  type        = bool
  default     = true
}

# =============================================================================
# 👤 Organization administrator account
# =============================================================================
# Each org gets one local administrator user. The username is built by replacing
# 'org_' with 'admin_' (configurable below).

variable "org_admin_role_name" {
  description = "Role name to assign to the organization administrator"
  type        = string
  default     = "Organization Administrator"
}

variable "admin_user_replace_from" {
  description = "Substring in the org name to replace when building the admin username"
  type        = string
  default     = "org_"
}

variable "admin_user_replace_to" {
  description = "Replacement substring for the admin username (e.g., org_it_001 → admin_it_001)"
  type        = string
  default     = "admin_"
}

variable "org_admin_password" {
  description = "Password for all organization admin users (set via environment variable TF_VAR_org_admin_password)"
  type        = string
  sensitive   = true
}

# =============================================================================
# 🌐 Infrastructure lookups (static environment info)
# =============================================================================
# These point Terraform at your existing VCF infrastructure components.

variable "vcfa_vcenter_name" {
  type        = string
  description = "Name of the vCenter that hosts the Supervisor"
}

variable "vcfa_supervisor_name" {
  type        = string
  description = "Name of the Supervisor cluster used by all orgs"
  default     = "supervisor"
}

variable "vcfa_region_name" {
  type        = string
  description = "Region name (e.g., eu-north-1)"
}

variable "vcfa_region_zone_name" {
  type        = string
  description = "Zone name within the region (e.g., domain-c10)"
}

variable "vcfa_region_storage_policy_name" {
  type        = string
  description = "Display name of the storage policy used in this region"
}

# =============================================================================
# 🧮 Quota configuration (compute + storage limits)
# =============================================================================
# Controls the resource limits each organization can consume.

variable "vcfa_vm_class_names" {
  type        = list(string)
  description = "VM class names to include in the quota (must exist in the region)"
  default = [
    "best-effort-xsmall",
    "best-effort-small",
    "best-effort-medium",
    "best-effort-large",
    "best-effort-xlarge",
    "best-effort-2xlarge",
    "best-effort-4xlarge",
    "best-effort-8xlarge",
  ]
}

variable "vcfa_quota_cpu_limit_mhz" {
  type        = number
  description = "Maximum CPU allocation per org (in MHz)"
  default     = 100000
}

variable "vcfa_quota_cpu_reservation_mhz" {
  type        = number
  description = "Reserved CPU allocation per org (in MHz)"
  default     = 0
}

variable "vcfa_quota_memory_limit_mib" {
  type        = number
  description = "Maximum memory allocation per org (in MiB)"
  default     = 100000
}

variable "vcfa_quota_memory_reservation_mib" {
  type        = number
  description = "Reserved memory allocation per org (in MiB)"
  default     = 0
}

variable "vcfa_quota_storage_limit_mib" {
  type        = number
  description = "Maximum storage per org for the selected policy (in MiB)"
  default     = 1048576 # 1 TiB
}

# =============================================================================
# 🧩 Networking (Org + Regional)
# =============================================================================
# Configure creation of organization networking and regional connectivity.

variable "enable_org_networking" {
  type        = bool
  description = "Whether to create vcfa_org_networking resources for each org"
  default     = true
}

variable "networking_target_org_names" {
  type        = list(string)
  description = "Exact org names to attach networking to; empty list means 'all orgs'"
  default     = []
}

variable "network_log_name_prefix" {
  type        = string
  description = "Optional short prefix for org networking log_name (≤8 chars total)"
  default     = ""
}

variable "network_log_name_suffix" {
  type        = string
  description = "Optional short suffix for org networking log_name (≤8 chars total)"
  default     = ""
}

# ---- Region / Edge / Provider Gateways ----
variable "vcfa_edge_cluster_name" {
  type        = string
  description = "Edge cluster name in the region (e.g., edge-cluster)"
}

variable "vcfa_provider_gateway_name_it" {
  type        = string
  description = "Provider gateway used by IT orgs (prefix org_it_)"
}

variable "vcfa_provider_gateway_name_ot" {
  type        = string
  description = "Provider gateway used by OT orgs (prefix org_ot_)"
}

# ---- Regional Networking naming ----
variable "org_regional_networking_name_template" {
  type        = string
  description = "Template for regional networking name; use $${name} to insert the org name"
  default     = "$${name}-regional"
}
