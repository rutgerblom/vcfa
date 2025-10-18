# VMware Cloud Foundation Automation (VCFA) — Multi-Org Terraform Deployment

This Terraform project automates the deployment of multiple **organizations** in VMware Cloud Foundation Automation (VCFA).  
It creates organizations, local admin users, regional quotas, and both org-scoped and regional networking — all parameterized and repeatable.

---

## 🧱 Features

| Component | Description |
|------------|-------------|
| **Organization creation** | Automatically generates and enables orgs such as `org_it_001 … org_ot_035`. |
| **Admin users** | Adds one Organization Administrator user per org (e.g. `admin_it_001`). |
| **Regional quotas** | Assigns CPU, memory, storage, and VM class quotas for each org in the target region. |
| **Org networking** | Creates an organization networking object with a unique short `log_name`. |
| **Regional networking** | Connects each org’s networking to the correct provider gateway (IT or OT) and edge cluster. |
| **Safety guardrails** | Protects orgs and org networking from accidental deletion using Terraform lifecycle rules. |

---

## ⚙️ Prerequisites

- Terraform **v1.7+**
- VMware **VCFA Terraform provider** (installed automatically via `terraform init`)
- API credentials with permissions to:
  - Create organizations and users
  - Apply region quotas
  - Manage org and regional networking

You must also export credentials before running Terraform (see the VCFA provider docs).

---

## 🧩 Configuration

All inputs are defined in [`variables.tf`](./variables.tf).  
To make setup easier, this repository includes an example configuration file:  
👉 [`terraform.tfvars.example`](./terraform.tfvars.example)

Copy it before your first run:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Then edit the new `terraform.tfvars` file with values for your environment (VCFA endpoint, region, etc.).

> 💡 **Tip:**  
> Never commit your real `terraform.tfvars` file if it contains sensitive data such as passwords.  
> The `.example` file should remain generic and safe for sharing.

Example key settings:

| Variable | Example | Description |
|-----------|----------|-------------|
| `vcfa_url` | `"https://vcfa.example.lab"` | Base VCFA API URL |
| `vcfa_region_name` | `"lab-region-1"` | Target region |
| `org_groups` | `[ { prefix = "org_it", count = 2 }, { prefix = "org_ot", count = 2 } ]` | Number and naming of orgs |
| `vcfa_edge_cluster_name` | `"edge-cluster-1"` | Edge cluster for regional networking |
| `vcfa_provider_gateway_name_it` | `"pgw_it"` | Provider gateway for IT orgs |
| `vcfa_provider_gateway_name_ot` | `"pgw_ot"` | Provider gateway for OT orgs |
| `org_admin_password` | (env var) | Admin password for all orgs |

> 💡 **Tip:** Don’t hardcode passwords.  
> Use environment variables instead:  
> ```bash
> export TF_VAR_org_admin_password='ChangeMe123!'
> ```

---

## 🚀 Usage

```bash
# Initialize provider and modules
terraform init

# Validate configuration
terraform validate

# Review what will be created
terraform plan

# Apply (serialized to avoid VCFA busy conflicts)
terraform apply -parallelism=1
```

> ⚠️ The VCFA API can be slow when creating many orgs.  
> Use `-parallelism=1` or `-parallelism=2` to avoid `BUSY_ENTITY` errors.

---

## 🧩 Resource Relationships

```
vcfa_org.labs
 ├─ vcfa_org_local_user.admins
 ├─ vcfa_org_region_quota.quota
 ├─ vcfa_org_networking.this
 │    └─ vcfa_org_regional_networking.this
```

Each org produces:
- 1 Organization  
- 1 Admin user  
- 1 Region quota  
- 1 Org networking  
- 1 Regional networking (linked to provider gateway)

---

## 🔒 Safety and Lifecycle Protection

| Resource | Protection | Behavior |
|-----------|-------------|----------|
| `vcfa_org.labs` | `prevent_destroy = true` | Protects orgs from accidental deletion. |
| `vcfa_org_networking.this` | `prevent_destroy = true` & `ignore_changes = [log_name]` | Prevents deletion and avoids provider trying to clear `log_name`. |

To delete protected resources:
1. Temporarily set `prevent_destroy = false` in `main.tf`.  
2. Run `terraform destroy` in the correct order (see below).  
3. Re-enable protection afterwards.

---

## 🧨 Safe Deletion Order

If full teardown is needed:

1. `vcfa_org_regional_networking.this`  
2. `vcfa_org_networking.this`  
3. `vcfa_org_region_quota.quota`  
4. `vcfa_org_local_user.admins`  
5. `vcfa_org.labs`

Example command to destroy only regional networking:

```bash
terraform destroy -target='vcfa_org_regional_networking.this' -parallelism=1
```

---

## 🧾 Example Results

After applying successfully, you’ll have:

- Multiple organizations (e.g., `org_it_001` → `org_ot_002`)  
- One admin user per org (`admin_it_001`, etc.)  
- One region quota per org  
- One org networking object per org  
- One regional networking connection per org attached to correct gateways  

---

## 🧹 Troubleshooting

| Error | Cause | Resolution |
|-------|--------|------------|
| `BUSY_ENTITY` | VCFA still processing a previous task | Re-run with `-parallelism=1` or wait a few minutes |
| `BAD_REQUEST: existing Regional Networking Setting found` | Resource already exists outside Terraform | Manually delete in VCFA before re-applying |
| `Variables not allowed in lifecycle` | Terraform limitation | Use hardcoded booleans in lifecycle blocks |
| `log_name cannot be empty` | Provider tried to revert to default | Handled by `ignore_changes` in lifecycle |

---

## 🤝 Contributing

1. Fork and branch the repo.  
2. Adjust prefixes, counts, and region settings as needed.  
3. Test with a small subset (e.g., `count = 1`) before scaling up.  
4. Submit PRs with improvements or new lab configurations.

---

## 👤 Author

**Rutger Blom**  
VMware Cloud Foundation Architect @ Advania Sweden  
Specializing in NSX, VCF, and automation

---
