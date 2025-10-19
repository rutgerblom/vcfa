###############################################################################
# MAIN CONFIGURATION
# - Orgs from var.org_families (no hard-coded prefixes)
# - Per-org Region Quota (CPU/Mem per zone, VM classes, storage policy+limit)
# - Org Admin Users (one per org)
# - Org Networking (log_name ≤ 8 chars; cannot be destroyed)
# - Regional Networking (family-bound PGW & Edge)
#
# ✅ Concurrency guidance:
#    Always run Terraform with -parallelism=1 to avoid VCFA BUSY/409 errors:
#      terraform apply   -parallelism=1
#      terraform destroy -parallelism=1
###############################################################################

# -----------------------------------------------------------------------------
# Data sources: region + infra references that must already exist
# -----------------------------------------------------------------------------
data "vcfa_region" "target" {
  name = var.vcfa_region_name
}

data "vcfa_region_zone" "target" {
  name      = var.vcfa_region_zone_name
  region_id = data.vcfa_region.target.id
}

data "vcfa_vcenter" "target" {
  name = var.vcfa_vcenter_name
}

data "vcfa_supervisor" "target" {
  name       = var.vcfa_supervisor_name
  vcenter_id = data.vcfa_vcenter.target.id
}

# Provider Gateways per family (e.g., devs/ops)
data "vcfa_provider_gateway" "by_family" {
  for_each = { for fam in var.org_families : fam.name => fam.provider_gateway_name }
  name      = each.value
  region_id = data.vcfa_region.target.id
}

# Edge Clusters per family (e.g., devs/ops)
data "vcfa_edge_cluster" "by_family" {
  for_each = { for fam in var.org_families : fam.name => fam.edge_cluster_name }
  name      = each.value
  region_id = data.vcfa_region.target.id
}

# Region VM classes (resolve IDs from names in tfvars)
data "vcfa_region_vm_class" "classes" {
  for_each = toset(var.vcfa_vm_class_names)
  name      = each.value
  region_id = data.vcfa_region.target.id
}

# Region storage policy (resolve ID from name in tfvars)
data "vcfa_region_storage_policy" "target" {
  name      = var.vcfa_region_storage_policy_name
  region_id = data.vcfa_region.target.id
}

# -----------------------------------------------------------------------------
# Locals: generated org names and metadata
# -----------------------------------------------------------------------------
locals {
  # org names per family: org_<family>_NNN
  org_names_by_family = {
    for fam in var.org_families :
    fam.name => [for i in range(1, fam.count + 1) : format("org_%s_%03d", fam.name, i)]
  }

  # flat list of all org names
  org_names = flatten(values(local.org_names_by_family))

  # map of org_name => { family, provider_gateway_name, edge_cluster_name }
  org_meta = merge([
    for fam in var.org_families : {
      for i in range(1, fam.count + 1) :
      format("org_%s_%03d", fam.name, i) => {
        family                = fam.name
        provider_gateway_name = fam.provider_gateway_name
        edge_cluster_name     = fam.edge_cluster_name
      }
    }
  ]...)

  # networking targets (empty in tfvars means "all orgs")
  networking_targets = length(var.networking_target_org_names) > 0 ? toset(var.networking_target_org_names) : toset(local.org_names)

  # subset of orgs to apply regional networking to
  orgs_for_networking = {
    for name, meta in local.org_meta : name => meta
    if contains(tolist(local.networking_targets), name)
  }

  # helper to derive admin usernames: org_* -> admin_*
  admin_username = { for name in local.org_names : name => replace(name, "org_", "admin_") }

  # list of region VM class IDs from data sources
  region_vm_class_ids = [for _, v in data.vcfa_region_vm_class.classes : v.id]

  # Short log name (≤8 chars) for org networking: <prefix><family2><NNN><suffix>
  short_log_name_by_org = {
    for name, meta in local.org_meta :
    name => substr(
      "${lower(var.network_log_name_prefix)}${lower(substr(meta.family, 0, 2))}${substr(name, length(name) - 3, 3)}${lower(var.network_log_name_suffix)}",
      0,
      8
    )
  }
}

# -----------------------------------------------------------------------------
# Organizations
# -----------------------------------------------------------------------------
resource "vcfa_org" "this" {
  for_each = local.org_meta

  name         = each.key
  display_name = each.key
  description  = replace(var.org_description_template, "$${name}", each.key)
  is_enabled   = var.org_enabled
}

# -----------------------------------------------------------------------------
# Lookup: "Organization Administrator" role per org
# -----------------------------------------------------------------------------
data "vcfa_role" "org_admin" {
  # one lookup per org we create
  for_each = vcfa_org.this

  org_id = each.value.id
  name   = "Organization Administrator"
}

# -----------------------------------------------------------------------------
# Org Admin Users (one Organization Administrator per org)
# -----------------------------------------------------------------------------
resource "vcfa_org_local_user" "admin" {
  for_each = vcfa_org.this

  org_id   = each.value.id
  username = local.admin_username[each.key]
  password = var.org_admin_password

  # Provider requires role IDs, not names
  role_ids = [data.vcfa_role.org_admin[each.key].id]
}

# -----------------------------------------------------------------------------
# Per-Org Region Quota (CPU/Mem per zone, VM classes, storage policy + storage limit)
# -----------------------------------------------------------------------------
resource "vcfa_org_region_quota" "this" {
  for_each = vcfa_org.this

  org_id    = each.value.id
  region_id = data.vcfa_region.target.id

  supervisor_ids = [data.vcfa_supervisor.target.id]

  zone_resource_allocations {
    region_zone_id         = data.vcfa_region_zone.target.id
    cpu_limit_mhz          = var.vcfa_quota_cpu_limit_mhz
    cpu_reservation_mhz    = var.vcfa_quota_cpu_reservation_mhz
    memory_limit_mib       = var.vcfa_quota_memory_limit_mib
    memory_reservation_mib = var.vcfa_quota_memory_reservation_mib
  }

  region_vm_class_ids = local.region_vm_class_ids

  region_storage_policy {
    region_storage_policy_id = data.vcfa_region_storage_policy.target.id
    storage_limit_mib        = var.vcfa_quota_storage_limit_mib
  }
}

# -----------------------------------------------------------------------------
# Org Networking (log_name ≤ 8 chars)  — CANNOT BE DESTROYED
# -----------------------------------------------------------------------------
resource "vcfa_org_networking" "this" {
  for_each = vcfa_org.this

  org_id   = each.value.id
  log_name = local.short_log_name_by_org[each.key]

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [log_name]
  }
}

# -----------------------------------------------------------------------------
# Regional Networking per Org (optional, filtered)
# -----------------------------------------------------------------------------
resource "vcfa_org_regional_networking" "this" {
  for_each = var.enable_org_networking ? local.orgs_for_networking : {}

  name      = replace(var.org_regional_networking_name_template, "$${name}", each.key)
  org_id    = vcfa_org.this[each.key].id
  region_id = data.vcfa_region.target.id

  provider_gateway_id = data.vcfa_provider_gateway.by_family[each.value.family].id
  edge_cluster_id     = data.vcfa_edge_cluster.by_family[each.value.family].id

  depends_on = [vcfa_org_networking.this]
}

# -----------------------------------------------------------------------------
# Helpful Outputs
# -----------------------------------------------------------------------------
output "org_names" {
  description = "All generated organization names."
  value       = local.org_names
}

output "org_admin_usernames" {
  description = "Derived admin usernames per org."
  value       = local.admin_username
}

output "networking_applied_to" {
  description = "Organizations that received regional networking."
  value       = keys(vcfa_org_regional_networking.this)
}

# -----------------------------------------------------------------------------
# Usage / Guardrail Instructions
# -----------------------------------------------------------------------------
output "usage_instructions" {
  description = "How to run safely with VCFA concurrency limits and non-deletable Org Networking."
  value = <<EOT
Run Terraform serially to avoid VCFA BUSY/409 errors:

  terraform apply  -parallelism=1
  terraform destroy -parallelism=1

Full teardown despite non-deletable Org Networking:

  1) Destroy dependents:
       terraform destroy -target=vcfa_org_regional_networking.this -auto-approve -parallelism=1
       terraform destroy -target=vcfa_org_region_quota.this -auto-approve -parallelism=1

  2) Remove org networking from state:
       terraform state rm 'vcfa_org_networking.this'

  3) Destroy the remainder:
       terraform destroy -auto-approve -parallelism=1
EOT
}
