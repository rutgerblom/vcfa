# VMware Cloud Foundation Automation (VCFA) provider variables

variable "vcfa_url" {
  type        = string
  description = "The base URL for the VCFA API (e.g. https://.lab.local)"
}

variable "vcfa_organization" {
  type        = string
  description = "VCFA Provider Organization"
}

variable "vcfa_allow_unverified_ssl" {
  type        = bool
  description = "Whether to allow unverified SSL certificates (true for lab environments)"
  default     = true
}

# --- Org generation (prefix + count) ---
variable "org_groups" {
  description = "List of org groups to create; each with a prefix and a count"
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
  description = "Description template; $${name} is replaced with org name"
  type        = string
  default     = "Created by Terraform $${name}"
}

variable "org_enabled" {
  description = "Whether newly created orgs are enabled"
  type        = bool
  default     = true
}

# --- Org admin user config ---
variable "org_admin_role_name" {
  description = "Role name to assign to the org admin user"
  type        = string
  default     = "Organization Administrator"
}

variable "admin_user_replace_from" {
  description = "Substring in org name to replace when building admin username"
  type        = string
  default     = "org_"
}

variable "admin_user_replace_to" {
  description = "Replacement substring for admin username"
  type        = string
  default     = "admin_"
}

variable "org_admin_password" {
  description = "Password for org admin users (set via env TF_VAR_org_admin_password)"
  type        = string
  sensitive   = true
}

# --- Infra lookups ---
variable "vcfa_vcenter_name" {
  type        = string
  description = "Display name of the vCenter hosting the Supervisor"
}

variable "vcfa_supervisor_name" {
  type        = string
  description = "Supervisor name in the region"
  default     = "supervisor"
}

variable "vcfa_region_name" {
  type        = string
  description = "Region name (e.g., eu-north-1)"
}

variable "vcfa_region_zone_name" {
  type        = string
  description = "Region zone name (e.g., domain-c10)"
}

variable "vcfa_region_storage_policy_name" {
  type        = string
  description = "Region storage policy display name"
}

variable "vcfa_vm_class_names" {
  type        = list(string)
  description = "Allowed VM class names to include in the quota"
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

# --- Quota limits ---
variable "vcfa_quota_cpu_limit_mhz" {
  type        = number
  description = "CPU limit for the org quota (MHz)"
  default     = 100000
}

variable "vcfa_quota_cpu_reservation_mhz" {
  type        = number
  description = "CPU reservation for the org quota (MHz)"
  default     = 0
}

variable "vcfa_quota_memory_limit_mib" {
  type        = number
  description = "Memory limit for the org quota (MiB)"
  default     = 100000
}

variable "vcfa_quota_memory_reservation_mib" {
  type        = number
  description = "Memory reservation for the org quota (MiB)"
  default     = 0
}

variable "vcfa_quota_storage_limit_mib" {
  type        = number
  description = "Per-org storage cap for the region storage policy (MiB)"
  default     = 1048576 # 1 TiB
}
