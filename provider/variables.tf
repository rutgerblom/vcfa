###############################################################################
# Variables
###############################################################################

# ---------------------------------------------------------------------------
# Provider & Connection
# ---------------------------------------------------------------------------
variable "vcfa_url" {
  description = "VCF Automation API endpoint (include https://, no trailing slash)."
  type        = string
  validation {
    condition     = can(regex("^https://", var.vcfa_url))
    error_message = "vcfa_url must start with https://"
  }
}

variable "vcfa_allow_unverified_ssl" {
  description = "Allow self-signed or unverified SSL certificates (true for labs)."
  type        = bool
}

variable "vcfa_organization" {
  description = "Provider organization name (often 'System')."
  type        = string
}

# Optional credentials if your provider block uses them; usually set via env:
#   export TF_VAR_vcfa_user="..."
#   export TF_VAR_vcfa_password="..."
variable "vcfa_user" {
  description = "VCFA username (set via environment variable TF_VAR_vcfa_user)."
  type        = string
  default     = null
  nullable    = true
}
variable "vcfa_password" {
  description = "VCFA password (set via environment variable TF_VAR_vcfa_password)."
  type        = string
  sensitive   = true
  default     = null
  nullable    = true
}

# ---------------------------------------------------------------------------
# Organization Families & Settings
# ---------------------------------------------------------------------------
variable "org_families" {
  description = <<-EOT
    Families of organizations to create. Each family defines:
      - name: logical family identifier (e.g., devs, ops)
      - count: number of orgs to create (1..N)
      - provider_gateway_name: name of the provider gateway to use
      - edge_cluster_name:    name of the edge cluster to use
  EOT
  type = list(object({
    name                  = string
    count                 = number
    provider_gateway_name = string
    edge_cluster_name     = string
  }))
  validation {
    condition     = length(var.org_families) > 0
    error_message = "org_families must contain at least one family."
  }
  # Ensure count is an integer >= 0 and family name is safe
  validation {
    condition = alltrue([
      for f in var.org_families :
      (f.count >= 0 && floor(f.count) == f.count) && can(regex("^[a-z0-9_-]+$", f.name))
    ])
    error_message = "Each family must have an integer count >= 0 and a lowercase name matching [a-z0-9_-]."
  }
}

variable "org_description_template" {
  description = "Template for org descriptions. Use $${name} to inject the org name."
  type        = string
}

variable "org_enabled" {
  description = "Whether new orgs should be enabled immediately."
  type        = bool
}

# ---------------------------------------------------------------------------
# Infrastructure References
# ---------------------------------------------------------------------------
variable "vcfa_vcenter_name" {
  description = "The vCenter name as known to VCFA."
  type        = string
}
variable "vcfa_supervisor_name" {
  description = "Supervisor name in the region."
  type        = string
}
variable "vcfa_region_name" {
  description = "VCFA region name."
  type        = string
}
variable "vcfa_region_zone_name" {
  description = "VCFA region zone name."
  type        = string
}

# Region storage policy *name* (string) required during provisioning.
variable "vcfa_region_storage_policy_name" {
  description = "Default storage policy name to use for the region (string name)."
  type        = string
}

# ---------------------------------------------------------------------------
# Quotas & VM Classes (required for provisioning)
# ---------------------------------------------------------------------------
variable "vcfa_vm_class_names" {
  description = "Allowed VM class names per org."
  type        = list(string)
  validation {
    condition     = length(var.vcfa_vm_class_names) > 0
    error_message = "vcfa_vm_class_names must include at least one class."
  }
}

variable "vcfa_quota_cpu_limit_mhz" {
  description = "CPU limit per org (MHz)."
  type        = number
  validation {
    condition     = var.vcfa_quota_cpu_limit_mhz >= 0
    error_message = "vcfa_quota_cpu_limit_mhz must be >= 0."
  }
}

variable "vcfa_quota_cpu_reservation_mhz" {
  description = "CPU reservation per org (MHz)."
  type        = number
  validation {
    condition     = var.vcfa_quota_cpu_reservation_mhz >= 0
    error_message = "vcfa_quota_cpu_reservation_mhz must be >= 0."
  }
}

variable "vcfa_quota_memory_limit_mib" {
  description = "Memory limit per org (MiB)."
  type        = number
  validation {
    condition     = var.vcfa_quota_memory_limit_mib >= 0
    error_message = "vcfa_quota_memory_limit_mib must be >= 0."
  }
}

variable "vcfa_quota_memory_reservation_mib" {
  description = "Memory reservation per org (MiB)."
  type        = number
  validation {
    condition     = var.vcfa_quota_memory_reservation_mib >= 0
    error_message = "vcfa_quota_memory_reservation_mib must be >= 0."
  }
}

variable "vcfa_quota_storage_limit_mib" {
  description = "Storage cap per org (MiB)."
  type        = number
  validation {
    condition     = var.vcfa_quota_storage_limit_mib >= 0
    error_message = "vcfa_quota_storage_limit_mib must be >= 0."
  }
}

# ---------------------------------------------------------------------------
# Organization / Regional Networking
# ---------------------------------------------------------------------------
variable "enable_org_networking" {
  description = "Enable creation of REGIONAL networking per org (org networking is always created)."
  type        = bool
}

variable "networking_target_org_names" {
  description = "Restrict REGIONAL networking to specific org names (empty = all orgs)."
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for n in var.networking_target_org_names :
      can(regex("^org_[a-z0-9_-]+_[0-9]{3}$", n))
    ]) || length(var.networking_target_org_names) == 0
    error_message = "networking_target_org_names entries must look like org_<family>_<NNN> (e.g., org_devs_001)."
  }
}

variable "network_log_name_prefix" {
  description = "Optional short prefix for org networking log_name (≤ 4 chars, lowercase/number/_/-)."
  type        = string
  default     = ""
  validation {
    condition     = length(var.network_log_name_prefix) <= 4 && can(regex("^[a-z0-9_-]*$", var.network_log_name_prefix))
    error_message = "network_log_name_prefix: max 4 chars, allowed [a-z0-9_-]."
  }
}

variable "network_log_name_suffix" {
  description = "Optional short suffix for org networking log_name (≤ 4 chars, lowercase/number/_/-)."
  type        = string
  default     = ""
  validation {
    condition     = length(var.network_log_name_suffix) <= 4 && can(regex("^[a-z0-9_-]*$", var.network_log_name_suffix))
    error_message = "network_log_name_suffix: max 4 chars, allowed [a-z0-9_-]."
  }
}

# ✅ Keep the computed log_name ≤ 8 chars overall:
#    2 (family two letters) + 3 (NNN) + prefix + suffix ≤ 8  => prefix+suffix ≤ 3
validation {
  condition     = length(var.network_log_name_prefix) + length(var.network_log_name_suffix) <= 3
  error_message = "prefix+suffix must be ≤ 3 characters total to keep the final log_name ≤ 8."
}

# ---------------------------------------------------------------------------
# Regional Networking Naming
# ---------------------------------------------------------------------------
variable "org_regional_networking_name_template" {
  description = "Name template for the regional networking object (use $${name} for org name)."
  type        = string
}
