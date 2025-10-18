# ---------------------------------------------------------------------------
# main.tf — create 70 orgs in VCFA
# ---------------------------------------------------------------------------

locals {
  # Generate a list of 70 org names: Org01 .. Org70
  orgs = [for i in range(1, 71) : format("Org%02d", i)]
}

resource "vcfa_org" "labs" {
  for_each = toset(local.orgs)

  name        = each.key
  display_name = each.key
  description = "Automated lab org ${each.key}"
}
