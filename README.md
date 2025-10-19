# VMware Cloud Foundation Automation (VCFA) — Terraform Projects

This repository is a collection of **Terraform automation blueprints** for managing and extending **VMware Cloud Foundation Automation (VCFA)** environments.

Each subdirectory contains a **self-contained Terraform project** targeting a specific VCFA use case.

## Projects

- [`provider/`](./provider) — Provision multiple organizations, admin users, regional quotas, and both org-level and regional networking. (Start here.)

> As the repo grows, additional projects (e.g., `tenant/`, `catalog/`, `nsx/`) may be added alongside `provider/`.

## Getting Started

Most users should begin with the **`provider/`** project. See its README for full details:

➡️ [`provider/README.md`](./provider/README.md)
