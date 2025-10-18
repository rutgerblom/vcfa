# ---------------------------------------------------------------------------
# main.tf — parameterized org creation, admins, and regional quotas
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

# Create orgs
resource "vcfa_org" "labs" {
  for_each     = toset(local.all_orgs)
  name         = each.key
  display_name = each.key
  description  = replace(var.org_description_template, "$${name}", each.key)
  is_enabled   = var.org_enabled
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
}
