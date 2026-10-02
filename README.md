# Terraform infrastructure for Netiks Store on Azure

## Week 7 - Additional Task: Infrastructure as Code with Terraform

**Date**: 2nd October 2026 
**Lab**: Week 7 Additional Task - Infrastructure as Code

---

## **Executive Summary**

This submission documents the completion of the Infrastructure as Code (IaC) additional task for Week 7. The objective was to codify the manually-created Netiks Store infrastructure (VM, networking, container registry) using Terraform, enabling repeatable and consistent infrastructure provisioning.

**Key Achievements**:
- ✅ Created modular Terraform code covering all required infrastructure components
- ✅ Successfully imported existing staging infrastructure into Terraform state
- ✅ Verified clean `terraform plan` with no unexpected changes
- ✅ Documented module structure, usage patterns, and operational procedures
- ✅ Identified and documented gaps for future improvement

---

## **Part 1: Understanding and Explaining the Module Structure**

### **How the Modules Are Structured**

The Terraform code is organized into three distinct modules:

```
terraform-netiks/
├── main.tf                    # Root orchestration
├── variables.tf               # Configurable inputs
├── outputs.tf                 # Important values
└── modules/
    ├── compute/               # VM, public IP, NIC
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── cloud-init.yml
    ├── networking/            # VNet, subnet, NSG
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── registry/              # Azure Container Registry
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### **Why This Structure Was Chosen**

#### **1. Separation of Concerns**
Each module handles one infrastructure layer:
- **Compute Module**: Everything related to the virtual machine (VM itself, its public IP, network interface)
- **Networking Module**: Network infrastructure that multiple resources might use (VNet, subnet, security rules)
- **Registry Module**: Container registry that's independent of compute resources

This separation makes it clear which module to modify when you need to change something specific, like opening a new port (networking module) or changing VM size (compute module).

#### **2. Reusability**
These modules can be reused across different environments with different variable values:
- Same module structure for staging and production
- Same module structure for different projects
- Can be published to a module registry for organization-wide use

#### **3. Clear Dependency Management**
The module structure makes dependencies explicit:
```hcl
module "compute" {
  subnet_id = module.networking.subnet_id  # VM needs subnet from networking
}
```

This is clearer than having all resources in one file where dependencies are implicit.

#### **4. Parallel Development**
Different team members can work on different modules simultaneously without merge conflicts, since each module is in its own directory.

#### **5. Isolated Testing**
Each module can be tested independently before integration, making it easier to validate changes.

#### **6. Easier Troubleshooting**
When something breaks, the module structure tells you immediately where to look:
- VM won't start? → Check compute module
- Can't reach the application? → Check networking module
- Can't push images? → Check registry module

### **Alternative Structures Considered**

**Why NOT a single flat file?**
- Would become unmanageable as infrastructure grows
- Hard to find specific resources
- Difficult to reuse parts of the code
- More prone to errors and conflicts

**Why NOT more granular modules (e.g., separate modules for public IP, NIC)?**
- Over-engineering for this scale
- The current grouping (compute, networking, registry) matches Azure's logical boundaries
- Public IP and NIC are tightly coupled to the VM, separating them adds complexity without benefit

---

## **Part 2: Understanding Terraform State vs Reality (Drift)**

### **What is Terraform State?**

Terraform state (`terraform.tfstate`) is a JSON file that records:
- What resources Terraform has created or is managing
- The current configuration of those resources
- Metadata about dependencies and relationships

**Example from our state file**:
```json
{
  "resources": [
    {
      "type": "azurerm_linux_virtual_machine",
      "name": "main",
      "attributes": {
        "name": "vm-netiks-store",
        "size": "Standard_D2as_v7",
        "location": "westus2"
      }
    }
  ]
}
```

### **What is Drift?**

**Drift** occurs when the actual infrastructure in Azure differs from what Terraform's state file says it should be. This happens when changes are made outside of Terraform.

### **How Drift Can Happen**

#### **Example 1: Manual Change via Azure Portal**
```
Terraform State says:  VM size = Standard_D2as_v7
Azure Portal change:   Resize VM to Standard_D4as_v7
Result:               Drift detected
```

When you run `terraform plan`, it will show:
```
~ resource "azurerm_linux_virtual_machine" "main" {
    ~ size = "Standard_D4as_v7" -> "Standard_D2as_v7"
  }
```

Terraform wants to change it BACK to what's in the code.

#### **Example 2: Adding Security Rule via Azure CLI**
```
Terraform State:  NSG has 3 rules (SSH, HTTP, HTTP-Staging)
Manual CLI add:   Add rule for port 443 (HTTPS)
Result:          Drift detected
```

`terraform plan` will show it wants to REMOVE the manually-added rule because it's not in the code.

#### **Example 3: VM Software Installation**
```
Terraform State:  VM has cloud-init config
Manual SSH:       Install PostgreSQL manually on VM
Result:          NOT detected as drift
```

**Why not?** Terraform only tracks infrastructure resources it manages. Software installed inside the VM isn't in Terraform's scope unless it's part of cloud-init or a provisioner.

### **Detecting Drift**

**Command**: `terraform plan`

This compares:
- What Terraform code describes
- What Terraform state records
- What actually exists in Azure (via Azure API)

If all three match → No changes needed  
If they differ → Drift detected, plan shows corrections

### **Preventing Drift**

**Best Practice**: Make ALL infrastructure changes through Terraform, never manually.

**Workflow**:
1. Change Terraform code
2. Run `terraform plan` to preview
3. Run `terraform apply` to execute
4. Commit code to version control

**NOT**:
1. ❌ Open Azure Portal
2. ❌ Click to change VM size
3. ❌ Forget about it
4. ❌ Terraform apply next week overwrites your change

### **When Drift is Acceptable**

- **Emergency hotfixes** (fix manually, then update Terraform code after)
- **Troubleshooting** (temporary changes to diagnose issues, then revert)
- **Things Terraform doesn't manage** (application state, database content)

**But always**: Document the drift and update Terraform code to match the desired state.

---

## **Part 3: What's Covered vs What's Not Covered**

### **✅ Fully Covered by Terraform**

| Resource Type | Specific Resource | Managed? |
|---------------|-------------------|----------|
| **Resource Group** | `rg-netiks-store` | ✅ Yes |
| **Virtual Machine** | `vm-netiks-store` | ✅ Yes |
| **Public IP** | Static IP for VM | ✅ Yes |
| **Network Interface** | NIC attached to VM | ✅ Yes |
| **Virtual Network** | `vnet-netiks-store` | ✅ Yes |
| **Subnet** | `subnet-internal` | ✅ Yes |
| **Network Security Group** | Security rules for ports 22, 80, 8080 | ✅ Yes |
| **Container Registry** | `acrnetiksstore.azurecr.io` | ✅ Yes |
| **Cloud-init Config** | Initial VM setup (Docker, Nginx, Node.js) | ✅ Yes |

### **❌ Not Yet Covered (Known Gaps)**

#### **1. VM Runtime Configuration**

**What's Missing**:
- Docker Compose files (`docker-compose.yml`, `docker-compose.prod.yml`, `docker-compose.staging.yml`)
- Environment variables (`.env` files)
- Nginx site configuration (`/etc/nginx/sites-available/netiks-store`)
- SSL certificates (if using HTTPS)

**Why It Matters**: If the VM is destroyed and recreated, these would need to be set up manually again.

**Future Solution**: Use Terraform provisioners, Ansible, or cloud-init to deploy these configurations.

#### **2. Azure Managed Identity and Permissions**

**What's Missing**:
- System-assigned managed identity on the VM
- Role assignment (AcrPull permission on the container registry)

**Why It Matters**: The CI/CD pipeline relies on this for secure image pulling without long-lived credentials.

**Terraform Solution**:
```hcl
# In compute module
resource "azurerm_linux_virtual_machine" "main" {
  identity {
    type = "SystemAssigned"
  }
}

# In registry module or main.tf
resource "azurerm_role_assignment" "acr_pull" {
  principal_id         = module.compute.vm_identity_principal_id
  role_definition_name = "AcrPull"
  scope                = module.registry.acr_id
}
```

**Priority**: HIGH - This should be added next.

#### **3. Secrets Management**

**What's Missing**:
- GitHub repository secrets (AZURE_REGISTRY_NAME, etc.)
- Database passwords
- Application secrets

**Why It Matters**: Manual secret rotation and management is error-prone and insecure.

**Future Solution**: Use Azure Key Vault (managed by Terraform) and GitHub Actions integration.

#### **4. Application State**

**What's Missing**:
- Database schema and data
- Deployed Docker images
- Application runtime state
- User data

**Why It Matters**: This represents the APPLICATION state, not INFRASTRUCTURE state.

**Why NOT Terraform?**: Terraform is for infrastructure. Application deployment should use CI/CD pipelines, and data should have separate backup/restore processes.

#### **5. Monitoring and Observability**

**What's Missing**:
- Azure Monitor workspace
- Log Analytics workspace
- Alert rules for CPU, memory, disk
- Application Insights (if used)

**Why It Matters**: Proactive monitoring prevents outages.

**Future Solution**: Add these as a separate Terraform module (`modules/monitoring/`).

#### **6. Backup and Disaster Recovery**

**What's Missing**:
- Azure Backup vault
- VM backup policy
- Database backup configuration
- Recovery procedures

**Why It Matters**: Critical for business continuity.

**Future Solution**: Create `modules/backup/` with Recovery Services Vault and backup policies.

#### **7. DNS and Custom Domain**

**What's Missing**:
- Azure DNS zone (if using custom domain)
- DNS records pointing to VM public IP
- Domain registration

**Why It Matters**: Currently using raw IP address; production should use a domain name.

**Future Solution**: Add Azure DNS zone and records to networking module.

### **Why These Gaps Exist**

**Honest Assessment**:

1. **Time constraints**: This is the first IaC implementation for this project
2. **Learning curve**: First time working with Terraform modules
3. **Scope prioritization**: Focused on the core infrastructure first
4. **Sensitive data**: Some items require careful secrets management strategy
5. **Application vs Infrastructure**: Some items belong in the CI/CD pipeline, not IaC

**What I'd Add Next** (in priority order):
1. Azure Managed Identity + Role Assignments
2. Monitoring and alerting resources
3. Nginx configuration via cloud-init
4. Azure Key Vault for secrets
5. Backup policies

---

## **Part 4: Evidence of Working Terraform Setup**

### **4.1 Terraform Plan Output**

<img width="1150" height="748" alt="image" src="https://github.com/user-attachments/assets/6fa59016-3074-45ed-830e-e6a2da3a3382" />

Shows: No changes. Your infrastructure matches the configuration.

### What This Proves
- Terraform successfully imported existing infrastructure
- State file accurately reflects reality
- No drift between code and actual resources
- Ready for ongoing management

### **4.2 Terraform State List**

<img width="758" height="381" alt="image" src="https://github.com/user-attachments/assets/de9fc45e-a135-47f0-9879-1ba3ca8c2f80" />

Shows: All 9 resources listed above

**What This Proves** 
All major infrastructure components are under Terraform management.

### **4.3 Terraform Output**

<img width="574" height="201" alt="image" src="https://github.com/user-attachments/assets/8552c89d-12e8-4a6c-8c71-4859f7c606dc" />

Shows: The three outputs above with actual values

**What This Proves**: Terraform can extract and display useful information from managed resources.

### **4.4 Module Structure Validation**

<img width="739" height="283" alt="image" src="https://github.com/user-attachments/assets/7df95fac-5cd6-41f4-811e-0d38493450d6" />

Shows: Success message confirming syntax validity

### **4.5 Azure Resource Verification**

<img width="1064" height="348" alt="image" src="https://github.com/user-attachments/assets/87c90510-b8c3-4b1f-b712-086fd745cc87" />

Shows: All resources that match what Terraform manages

**What This Proves**: Terraform state matches actual Azure resources.

---

## **Part 5: Using Terraform Import (Key Learning)**

### **Why Import Was Necessary**

The staging VM and networking were created manually in earlier weeks. Two options existed:

**Option 1**: Destroy everything and let Terraform create from scratch  
❌ **Rejected because**:
- Downtime for staging environment
- Risk of losing configuration
- Unnecessary cost of rebuilding

**Option 2**: Import existing resources into Terraform state  
✅ **Chosen because**:
- No downtime
- No duplicate resources
- No additional costs
- Real-world skill (most companies adopt IaC for existing infrastructure)

### **How Import Was Done**

#### **Step 1: Write Terraform Code to Match Existing Resources**

Before importing, I had to describe the existing infrastructure in Terraform code exactly as it exists in Azure. This required:

1. Checking actual VM properties:
```bash
az vm show --resource-group rg-netiks-store --name vm-netiks-store
```
<img width="1162" height="796" alt="image" src="https://github.com/user-attachments/assets/7c4a67cb-22f4-469a-b58c-2ad9cb83e591" />

2. Writing matching Terraform code:
```hcl
resource "azurerm_linux_virtual_machine" "main" {
  name     = "vm-netiks-store"
  size     = "Standard_D2as_v7"
  location = "westus2"
  # ... other properties matching existing VM
}
```

#### **Step 2: Import Each Resource**

**General Pattern**:
```bash
terraform import <terraform_address> <azure_resource_id>
```

**Example - Resource Group**:
```bash
terraform import azurerm_resource_group.main \
  /subscriptions/b29d9318-d7d8-42c6-b98c-38e1d051c5ff/resourceGroups/rg-netiks-store
```

**Example - Virtual Machine**:
```bash
terraform import module.compute.azurerm_linux_virtual_machine.main \
  /subscriptions/b29d9318-d7d8-42c6-b98c-38e1d051c5ff/resourceGroups/rg-netiks-store/providers/Microsoft.Compute/virtualMachines/vm-netiks-store
```

**Example - Container Registry**:
```bash
terraform import module.registry.azurerm_container_registry.main \
  /subscriptions/b29d9318-d7d8-42c6-b98c-38e1d051c5ff/resourceGroups/rg-netiks-store/providers/Microsoft.ContainerRegistry/registries/acrnetiksstore
```

#### **Step 3: Verify with Plan**

After each import (or all imports), verify:
```bash
terraform plan
```

**Critical Check**: The plan should show either:
- "No changes" (perfect match)
- Only minor attribute updates (acceptable)

**Red Flag**: If plan shows creating new resources or destroying/recreating existing ones, STOP and investigate.

#### **Step 4: Address Any Drift**

If the plan showed differences, I had two options:

**Option A**: Update Terraform code to match Azure
```hcl
# Change code to match what Azure actually has
size = "Standard_D2as_v7"  # Not D4as_v7
```

**Option B**: Let Terraform update Azure to match code
```bash
terraform apply  # Apply the changes shown in plan
```

For this task, I chose **Option A** - making code match reality, since the existing infrastructure was already working correctly.

### **Challenges Encountered**

#### **Challenge 1: Finding Correct Resource IDs**

**Problem**: Import commands need exact Azure resource IDs.

**Solution**: Used Azure CLI to get IDs:
```bash
az resource show --resource-group rg-netiks-store --name vm-netiks-store --resource-type "Microsoft.Compute/virtualMachines" --query id --output tsv
```

#### **Challenge 2: Module Paths in Import**

**Problem**: Resources inside modules need module prefix:
```bash
# Wrong:
terraform import azurerm_linux_virtual_machine.main ...

# Right:
terraform import module.compute.azurerm_linux_virtual_machine.main ...
```

**Solution**: Checked Terraform code structure to get correct paths.

#### **Challenge 3: Sensitive Attributes**

**Problem**: Some attributes (like `custom_data`) are stored as hashes in state, so they always show as "changed" in plan.

**Solution**: Used `lifecycle` blocks to ignore certain attributes:
```hcl
lifecycle {
  ignore_changes = [custom_data]
}
```

### **What I Learned**

1. **Import is the right approach for existing infrastructure** - It's how real companies adopt IaC
2. **Code must match reality before importing** - Can't import into wrong configuration
3. **Azure resource IDs have a specific format** - Must be exact for import to work
4. **Terraform plan is your friend** - Always verify after importing
5. **Some drift is acceptable** - Not everything needs perfect alignment

---

## **Part 6: How to Use This Code (Operational Procedures)**

### **Scenario 1: Someone New Needs to Understand the Infrastructure**

**Steps**:
1. Clone the repository
2. Read `terraform-netiks/README.md` (the comprehensive README I created)
3. Review `main.tf` to see module orchestration
4. Explore each module directory to understand components
5. Run `terraform state list` to see what's managed
6. Run `terraform output` to see current values

**Time**: ~30 minutes to understand the full setup

### **Scenario 2: Need to Open a New Port**

**Steps**:
1. Edit `modules/networking/main.tf`
2. Add a new security rule block:
```hcl
security_rule {
  name                       = "HTTPS"
  priority                   = 1004
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "443"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
}
```
3. Run `terraform plan` to preview
4. Run `terraform apply` to execute
5. Commit changes to version control

**Time**: ~5 minutes

### **Scenario 3: Need to Change VM Size**

**Steps**:
1. Edit `modules/compute/main.tf`
2. Change the `size` attribute:
```hcl
size = "Standard_D4as_v7"  # Was D2as_v7
```
3. Run `terraform plan` to preview (will show VM replacement needed)
4. ⚠️ **WARNING**: This will recreate the VM (downtime expected)
5. Schedule maintenance window
6. Run `terraform apply`
7. Re-run cloud-init or manual setup if needed

**Time**: ~20 minutes + downtime

### **Scenario 4: Deploying to a Completely New Environment**

**Steps**:
1. Copy the `terraform-netiks/` directory
2. Create a new `terraform.tfvars` file:
```hcl
resource_group_name = "rg-netiks-prod"
location           = "East US"
vm_name            = "vm-netiks-prod"
acr_name           = "acrnetiksprod"  # Must be globally unique
```
3. Update SSH key path if different
4. Run `terraform init`
5. Run `terraform plan -out=tfplan`
6. Review plan carefully
7. Run `terraform apply tfplan`
8. Capture outputs: `terraform output > outputs.txt`
9. Configure DNS to point to new VM IP
10. Deploy application via CI/CD

**Time**: ~1 hour for infrastructure, plus application deployment

### **Scenario 5: Recovering from Accidental Resource Deletion**

**If someone deletes the VM from Azure Portal**:

1. Terraform will detect it on next plan:
```bash
terraform plan
# Shows: VM needs to be created
```

2. Recreate with Terraform:
```bash
terraform apply
```

3. Redeploy application:
```bash
# SSH to new VM
# Run docker compose commands
```

**Time**: ~30 minutes (infrastructure) + app redeployment time

### **Scenario 6: Auditing Infrastructure Changes**

**Steps**:
1. Review Git commit history:
```bash
git log --oneline terraform-netiks/
```

2. Check Terraform state history (if using remote state with versioning)

3. Compare current vs previous state:
```bash
terraform show > current.txt
git show HEAD~1:terraform.tfstate | terraform show > previous.txt
diff current.txt previous.txt
```

**Time**: ~10 minutes

---

## **Part 7: Repository and Submission**

### **Repository Structure**

```
netiks_store_wk4/
├── terraform-netiks/              # Infrastructure as Code
│   ├── main.tf                   # Root module
│   ├── variables.tf              # Input variables
│   ├── outputs.tf                # Output values
│   ├── README.md                 # Comprehensive documentation
│   ├── terraform.tfstate         # State file (managed by Terraform)
│   ├── .terraform.lock.hcl       # Provider lock file
│   └── modules/
│       ├── compute/              # VM infrastructure
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   └── cloud-init.yml
│       ├── networking/           # Network infrastructure
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── registry/             # Container registry
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
├── Week7_IaC_Submission.md       # This document
└── [other project files...]
```

### **GitHub Repository Link**

**Repository**: `https://github.com/laoluafolami/netiks_IaC/edit/main/README.md`

**Terraform Code Location**: `terraform-netiks/` directory

**Key Files to Review**:
- `terraform-netiks/README.md` - Complete documentation
- `terraform-netiks/main.tf` - Root module showing structure
- `terraform-netiks/modules/` - Individual module implementations

---

## **Deliverables Checklist**

| Deliverable | Status | Location |
|-------------|--------|----------|
| ✅ Terraform code covering VM, networking, registry | Complete | `terraform-netiks/` |
| ✅ Code organized into modules | Complete | `terraform-netiks/modules/` |
| ✅ Evidence of clean `terraform plan` | Complete | See Part 4, Screenshots |
| ✅ README explaining structure and usage | Complete | `terraform-netiks/README.md` |
| ✅ Explanation of module structure choice | Complete | See Part 1 |
| ✅ Understanding of Terraform state vs drift | Complete | See Part 2 |
| ✅ Honest assessment of coverage gaps | Complete | See Part 3 |
| ✅ Documentation of import process | Complete | See Part 5 |
| ✅ Operational procedures | Complete | See Part 6 |

---

## **What Good Looks Like - Self Assessment**

### **Can I explain (not just show) why modules are structured this way?**

✅ **Yes**: See Part 1 for detailed explanation of:
- Why three modules (compute, networking, registry) instead of one or five
- How this structure supports reusability, testing, and collaboration
- What alternatives were considered and rejected
- How dependencies flow between modules

### **Do I understand the difference between what Terraform describes vs what's running (drift)?**

✅ **Yes**: See Part 2 for detailed explanation of:
- What Terraform state represents
- How drift occurs with concrete examples
- How to detect and handle drift
- When drift is acceptable vs problematic

### **Can I honestly say what parts are and aren't yet covered by code?**

✅ **Yes**: See Part 3 for complete accounting of:
- What's fully managed (9 resource types)
- What's not yet covered (7 categories)
- Why each gap exists
- What should be prioritized next

### **Do I understand how to use this code in real scenarios?**

✅ **Yes**: See Part 6 for operational procedures covering:
- Onboarding new team members
- Making common infrastructure changes
- Deploying to new environments
- Recovering from failures
- Auditing changes

---

## **Reflection and Learning**

### **What I Learned**

1. **Infrastructure as Code is about repeatability**: The real value isn't just automating creation, it's being able to recreate identically.

2. **Module design matters**: Good module boundaries make code maintainable; bad boundaries create coupling and confusion.

3. **Import is a critical real-world skill**: Most companies don't start with IaC; they adopt it for existing infrastructure.

4. **State management is crucial**: Terraform state is the source of truth for what's managed, and protecting it is essential.

5. **Documentation is infrastructure too**: Code without documentation is hard to maintain and hard to hand off.

### **What Surprised Me**

1. **How much work goes into matching existing resources**: Writing Terraform code to match existing infrastructure required carefully inspecting every attribute.

2. **The import process is tedious but necessary**: Each resource needed individual import commands with exact resource IDs.

3. **Not everything belongs in Terraform**: Application state, secrets, and dynamic data shouldn't be in IaC.

4. **Terraform plan is incredibly powerful**: Seeing exactly what would change before applying gives confidence.

### **What I'd Do Differently**

1. **Start with IaC from day one**: If rebuilding this project, I'd use Terraform from the beginning rather than manual setup then adoption.

2. **Use remote state from the start**: Local state works for learning but isn't suitable for team collaboration.

3. **Add more granular modules**: Could separate NSG rules into their own submodule for easier management.

4. **Implement automated testing**: Use tools like Terratest to validate infrastructure changes.

### **Future Improvements**

**Short term** (next 2 weeks):
1. Add Azure Managed Identity and role assignments
2. Move state to Azure Storage (remote state)
3. Add monitoring resources (Log Analytics, alerts)

**Medium term** (next month):
1. Create separate environments (staging vs production)
2. Implement Azure Key Vault for secrets
3. Add backup policies and disaster recovery

**Long term** (ongoing):
1. Build reusable module library for organization
2. Implement policy-as-code with Azure Policy
3. Create automated compliance scanning

---

**End of Submission Document**
