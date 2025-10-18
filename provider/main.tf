# ---------------------------------------------------------------------------
# main.tf — parameterized org creation, admins, quotas, and networking
# ---------------------------------------------------------------------------

# Build a flat list of org names from groups (prefix + count)
locals {
  all_orgs = flatten([
    for g in var.org_groups : [
      for i in range(1, g.count + 1) :
      format("${g.prefix}_%03d", i)
    ]
  ])
}

# ----------------------------------------------------------------------------
# Orgs
# ----------------------------------------------------------------------------
resource "vcfa_org" "labs" {
  for_each     = toset(local.all_orgs)
  name         = each.key
  display_name = each.key
  description  = replace(var.org_description_template, "$${name}", each.key)
  is_enabled   = var.org_enabled

  # 🔒 Destruction guardrail: blocks accidental deletes of orgs.
  # Turn off by applying with: -var='protect_orgs=false'
  lifecycle {
    prevent_destroy = var.protect_orgs
  }
}

# ---------------------------------------------------------------------------
# Add an Organization Administrator user to each org
# ---------------------------------------------------------------------------

# Lookup the org-scoped role (parametric name)
data "vcfa_role" "org_admin" {
  for_each = vcfa_org.labs
  org_id   = each.value.id
  name     = var.org_admin_role_name
}

# Create one local admin user per org (parametric username pattern + password)
resource "vcfa_org_local_user" "admins" {
  for_each = vcfa_org.labs

  org_id   = each.value.id
  username = replace(each.key, var.admin_user_replace_from, var.admin_user_replace_to)
  password = var.org_admin_password
  role_ids = [data.vcfa_role.org_admin[each.key].id]

  # 🔒 Optional guardrail for users (defaults to false).
  lifecycle {
    prevent_destroy = var.protect_org_users
  }
}

# ---------------------------------------------------------------------------
# Region / Supervisor / Zone / VM classes / Storage policy lookups
# ---------------------------------------------------------------------------

data "vcfa_vcenter" "vc" {
  name = var.vcfa_vcenter_name
}

data "vcfa_supervisor" "supervisor" {
  name       = var.vcfa_supervisor_name
  vcenter_id = data.vcfa_vcenter.vc.id
}

data "vcfa_region" "target" {
  name = var.vcfa_region_name
}

data "vcfa_region_zone" "target" {
  region_id = data.vcfa_region.target.id
  name      = var.vcfa_region_zone_name
}

# Resolve region-scoped VM class IDs from names
data "vcfa_region_vm_class" "vmc" {
  for_each  = toset(var.vcfa_vm_class_names)
  name      = each.key
  region_id = data.vcfa_region.target.id
}

# Resolve region storage policy by name
data "vcfa_region_storage_policy" "sp" {
  name      = var.vcfa_region_storage_policy_name
  region_id = data.vcfa_region.target.id
}

# ---------------------------------------------------------------------------
# One org_region_quota per org
# ---------------------------------------------------------------------------
resource "vcfa_org_region_quota" "quota" {
  for_each = vcfa_org.labs

  org_id         = each.value.id
  region_id      = data.vcfa_region.target.id
  supervisor_ids = [data.vcfa_supervisor.supervisor.id]

  zone_resource_allocations {
    region_zone_id         = data.vcfa_region_zone.target.id
    cpu_limit_mhz          = var.vcfa_quota_cpu_limit_mhz
    cpu_reservation_mhz    = var.vcfa_quota_cpu_reservation_mhz
    memory_limit_mib       = var.vcfa_quota_memory_limit_mib
    memory_reservation_mib = var.vcfa_quota_memory_reservation_mib
  }

  region_vm_class_ids = [for _, v in data.vcfa_region_vm_class.vmc : v.id]

  region_storage_policy {
    region_storage_policy_id = data.vcfa_region_storage_policy.sp.id
    storage_limit_mib        = var.vcfa_quota_storage_limit_mib
  }

  # 🔒 Optional guardrail for quotas.
  lifecycle {
    prevent_destroy = var.protect_org_region_quota
  }
}

# ---------------------------------------------------------------------------
# Org networking (one per org). log_name ≤ 8 chars, derived from org name.
# ---------------------------------------------------------------------------

locals {
  # Build short names (e.g., org_it_014 → it014, org_ot_007 → ot007)
  org_log_short = {
    for k in keys(vcfa_org.labs) :
    k => "${split("_", k)[1]}${split("_", k)[2]}"
  }

  # Determine which orgs get networking
  networking_target_orgs = length(var.networking_target_org_names) > 0 ? {
    for k, v in vcfa_org.labs : k => v
    if contains(var.networking_target_org_names, k)
  } : vcfa_org.labs
}

resource "vcfa_org_networking" "this" {
  for_each = var.enable_org_networking ? local.networking_target_orgs : {}

  org_id = each.value.id

  # Construct short log name, trimmed to max 8 characters
  log_name = substr(
    "${var.network_log_name_prefix}${local.org_log_short[each.key]}${var.network_log_name_suffix}",
    0,
    8
  )

  # 🔒 Guardrails:
  #  - ignore_changes keeps Terraform from “helpfully” changing log_name later.
  #  - prevent_destroy protects org networking unless you disable it on purpose.
  lifecycle {
    ignore_changes  = [log_name]
    prevent_destroy = var.protect_org_networking
  }
}

# ---------------------------------------------------------------------------
# Regional networking per org (reuses data.vcfa_region.target)
# ---------------------------------------------------------------------------

# Edge cluster lookup in the existing region
data "vcfa_edge_cluster" "target" {
  name      = var.vcfa_edge_cluster_name
  region_id = data.vcfa_region.target.id
}

# Provider gateways (IT / OT) in the same region
data "vcfa_provider_gateway" "it" {
  name      = var.vcfa_provider_gateway_name_it
  region_id = data.vcfa_region.target.id
}

data "vcfa_provider_gateway" "ot" {
  name      = var.vcfa_provider_gateway_name_ot
  region_id = data.vcfa_region.target.id
}

# One regional networking per org networking
resource "vcfa_org_regional_networking" "this" {
  for_each = vcfa_org_networking.this

  # Parametric name; inserts the org name
  name = replace(var.org_regional_networking_name_template, "$${name}", each.key)

  # Per docs: org_id should be the *org networking* ID (it contains the org link)
  org_id    = each.value.id
  region_id = data.vcfa_region.target.id

  # Choose provider gateway by org prefix — keep ternary on one line
  provider_gateway_id = startswith(each.key, "org_it_") ? data.vcfa_provider_gateway.it.id : data.vcfa_provider_gateway.ot.id

  edge_cluster_id = data.vcfa_edge_cluster.target.id

  # 🔒 Optional guardrail for regional networking.
  lifecycle {
    prevent_destroy = var.protect_org_regional_networking
  }
}
