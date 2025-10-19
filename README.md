# VMware Cloud Foundation Automation (VCFA) — Multi-Org Terraform Deployment

This Terraform project automates the deployment of multiple **organizations** in VMware Cloud Foundation Automation (VCFA).  
It creates organizations, regional quotas, org-level and regional networking — all parameterized, idempotent, and safe for shared use.

---

## 🧱 Features

| Component | Description |
|------------|-------------|
| **Organization creation** | Dynamically generates orgs such as `org_devs_001 … org_ops_035` using configurable families. |
| **Regional quotas** | Applies per-org CPU, memory, storage, and VM-class quotas in the selected region. |
| **Org networking** | Creates an organization networking object with a unique ≤ 8-char `log_name`. |
| **Regional networking** | Connects each org’s networking to the correct provider gateway and edge cluster per family. |
| **Safety guardrails** | Prevents accidental deletion of orgs and org networking using Terraform lifecycle rules. |
| **Concurrency control** | Designed for serial execution (`-parallelism=1`) to avoid VCFA API `BUSY`/409 conflicts. |

---

## ⚙️ Prerequisites

- Terraform **v1.7+**
- VMware **VCFA Terraform provider** (installed automatically via `terraform init`)
- API credentials with permissions to:
  - Create organizations
  - Apply regional quotas
  - Manage org and regional networking

Export your credentials before running Terraform (see the VCFA provider documentation).

---

## 🧩 Configuration

All variables are defined in [`variables.tf`](./variables.tf).  
An example configuration file is provided as [`terraform.tfvars.example`](./terraform.tfvars.example).

Copy it to begin:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` to match your environment (VCFA endpoint, region, provider gateways, etc.).

> 💡 **Tip:**  
> Never commit your real `terraform.tfvars` if it contains secrets.  
> Use environment variables for credentials instead:
> ```bash
> export TF_VAR_org_admin_password='ChangeMe123!'
> ```

### Example key settings

| Variable | Example | Description |
|-----------|----------|-------------|
| `vcfa_url` | `"https://pod-240-vcf-automation.sddc.lab"` | Base VCFA API URL |
| `vcfa_region_name` | `"eu-north-1"` | Target region |
| `org_families` | `[ { name = "devs", count = 35, provider_gateway_name = "provider_gw_org_devs", edge_cluster_name = "edge-cluster" }, { name = "ops", count = 35, provider_gateway_name = "provider_gw_org_ops", edge_cluster_name = "edge-cluster" } ]` | Defines org families and their capacities |
| `vcfa_region_storage_policy_name` | `"mgmt-cluster-1 - Optimal Datastore Default Policy - RAID1"` | Storage policy to apply in quotas |
| `org_admin_password` | (env var) | Optional admin password for lab use |

---

## 🚀 Usage

```bash
# Initialize provider and dependencies
terraform init

# Validate configuration
terraform validate

# Review what will be created
terraform plan

# Apply (always serialized to avoid VCFA BUSY conflicts)
terraform apply -parallelism=1
```

> ⚠️ **Important:**  
> The VCFA API can process only one org-related operation at a time.  
> Always run Terraform with `-parallelism=1` (or at most 2) for both **apply** and **destroy**.

---

## 🧩 Resource Relationships

```
vcfa_org.this
 ├─ vcfa_org_region_quota.this
 ├─ vcfa_org_networking.this
 │    └─ vcfa_org_regional_networking.this
```

Each org produces:
- 1 Organization  
- 1 Region quota  
- 1 Org networking object  
- 1 Regional networking connection

---

## 🔒 Safety and Lifecycle Protection

| Resource | Protection | Behavior |
|-----------|-------------|----------|
| `vcfa_org.this` | (Optional future protection) | Use `prevent_destroy = true` if you wish to lock org deletion. |
| `vcfa_org_networking.this` | `prevent_destroy = true` + `ignore_changes = [log_name]` | VCFA does not allow deleting org networking; Terraform will preserve it and skip changes. |

---

## 🧨 Safe Teardown Procedure

Because **`vcfa_org_networking`** cannot be destroyed via API, use the following sequence for full cleanup:

```bash
# 1️⃣ Destroy dependents first (safe to remove)
terraform destroy -target=vcfa_org_regional_networking.this -auto-approve -parallelism=1
terraform destroy -target=vcfa_org_region_quota.this -auto-approve -parallelism=1

# 2️⃣ Remove non-deletable org networking from Terraform state
terraform state rm 'vcfa_org_networking.this'

# 3️⃣ Destroy remaining resources
terraform destroy -auto-approve -parallelism=1
```

---

## 🧾 Expected Results

After successful apply, you’ll have:

- Multiple organizations (e.g. `org_devs_001`, `org_ops_035`)  
- Corresponding region quotas with CPU/MEM/storage/VM-class limits  
- One org networking per org (unique `log_name`)  
- One regional networking per org, mapped to correct gateways and edge clusters  

---

## 🧹 Troubleshooting

| Error | Cause | Resolution |
|-------|--------|------------|
| `BUSY_ENTITY` / `409 Conflict` | VCFA API concurrency limit hit | Re-run with `-parallelism=1` |
| `BAD_REQUEST: existing Regional Networking Setting found` | Networking object exists outside Terraform | Delete it manually in VCFA or import into state |
| `Cannot delete Org Networking` | VCFA prevents deletion | Use the safe teardown steps above |
| `log_name cannot be empty` | Provider attempted to clear the field | Handled via `ignore_changes` lifecycle |

---

## 🤝 Contributing

1. Fork or branch the repo.  
2. Adjust family names, counts, and region settings as needed.  
3. Test with a small subset (`count = 1`) before scaling up.  
4. Submit improvements or new automation examples via PR.

---

## 👤 Author

**Rutger Blom**  
VMware Cloud Foundation Architect @ Advania Sweden  
Specializing in VCF, NSX, and Infrastructure Automation

---
