# ---------------------------------------------------------------------------
# main.tf — parameterized org creation, admins, quotas, and networking
# ---------------------------------------------------------------------------

locals {
  all_orgs = flatten([
    for g in var.org_groups : [
      for i in range(1, g.count + 1) :
      format("${g.prefix}_%03d", i)
    ]
  ])
}

# ----------------------------------------------------------------------------
# Orgs (protected from accidental destroy)
# ----------------------------------------------------------------------------
resource "vcfa_org" "labs" {
  for_each     = toset(local.all_orgs)
  name         = each.key
  display_name = each.key
  description  = replace(var.org_description_template, "$${name}", each.key)
  is_enabled   = var.org_enabled

  # 🔒 Guardrail: prevent accidental deletion of orgs.
  # To intentionally delete orgs, temporarily change this to `false`,
  # then run your destroy. Switch back to `true` afterwards.
  lifecycle {
    prevent_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Add an Organization Administrator user to each org
# ---------------------------------------------------------------------------

data "vcfa_role" "org_admin" {
  for_each = vcfa_org.labs
  org_id   = each.value.id
  name     = var.org_admin_role_name
}

resource "vcfa_org_local_user" "admins" {
  for_each = vcfa_org.labs

  org_id   = each.value.id
  username = replace(each.key, var.admin_user_replace_from, var.admin_user_replace_to)
  password = var.org_admin_password
  role_ids = [data.vcfa_role.org_admin[each.key].id]

  # (No prevent_destroy here so you can tear users down freely.)
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

data "vcfa_region_vm_class" "vmc" {
  for_each  = toset(var.vcfa_vm_class_names)
  name      = each.key
  region_id = data.vcfa_region.target.id
}

data "vcfa_region_storage_policy" "sp" {
  name      = var.vcfa_region_storage_policy_name
  region_id = data.vcfa_region.target.id
}

# ---------------------------------------------------------------------------
# One org_region_quota per org (no prevent_destroy so you can clean up easily)
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
}

# ---------------------------------------------------------------------------
# Org networking (protected + ignore log_name drift)
# ---------------------------------------------------------------------------

locals {
  org_log_short = {
    for k in keys(vcfa_org.labs) :
    k => "${split("_", k)[1]}${split("_", k)[2]}"
  }

  networking_target_orgs = length(var.networking_target_org_names) > 0 ? {
    for k, v in vcfa_org.labs : k => v
    if contains(var.networking_target_org_names, k)
  } : vcfa_org.labs
}

resource "vcfa_org_networking" "this" {
  for_each = var.enable_org_networking ? local.networking_target_orgs : {}

  org_id = each.value.id

  # Ensure ≤ 8 chars total; derived from org name
  log_name = substr(
    "${var.network_log_name_prefix}${local.org_log_short[each.key]}${var.network_log_name_suffix}",
    0, 8
  )

  # 🔒 Guardrails:
  #  - ignore_changes prevents the provider from trying to “revert” log_name.
  #  - prevent_destroy avoids accidental deletes of org networking.
  #    To delete orgs, set this to false temporarily and destroy networking first.
  lifecycle {
    ignore_changes  = [log_name]
    prevent_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Regional networking per org (no prevent_destroy; serialize applies instead)
# ---------------------------------------------------------------------------

data "vcfa_edge_cluster" "target" {
  name      = var.vcfa_edge_cluster_name
  region_id = data.vcfa_region.target.id
}

data "vcfa_provider_gateway" "it" {
  name      = var.vcfa_provider_gateway_name_it
  region_id = data.vcfa_region.target.id
}

data "vcfa_provider_gateway" "ot" {
  name      = var.vcfa_provider_gateway_name_ot
  region_id = data.vcfa_region.target.id
}

resource "vcfa_org_regional_networking" "this" {
  for_each = vcfa_org_networking.this

  name        = replace(var.org_regional_networking_name_template, "$${name}", each.key)
  org_id      = each.value.id
  region_id   = data.vcfa_region.target.id
  provider_gateway_id = startswith(each.key, "org_it_") ? data.vcfa_provider_gateway.it.id : data.vcfa_provider_gateway.ot.id
  edge_cluster_id     = data.vcfa_edge_cluster.target.id

  # (No prevent_destroy — destroy/apply these in serialized batches with -parallelism=1.)
}
