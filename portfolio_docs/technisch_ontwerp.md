# Technisch Ontwerp (TO)
## DBF Casus - KE02 Automation (2025-2026)

---

## 1. Doel

Dit Technisch Ontwerp beschrijft de concrete technische realisatie van de in het
Functioneel Ontwerp beschreven architectuur. Het legt uit welke tools worden ingezet,
hoe de netwerktopologie is opgebouwd en welke keuzes zijn gemaakt met betrekking tot
beveiliging, automatisering en hardware-beperkingen.

---

## 2. Architectuuroverzicht

De oplossing bestaat uit twee lagen die samenwerken:

```
[ Internet ]
     |
     | TCP 80/443
     v
[ Azure Cloud ]
  VNet: 10.0.0.0/16
  Subnet: 10.0.1.0/24
  NSG: Allow 22 (Pi only), 80, 443, 41641 (UDP)
     |
     +-- Tailscale Mesh IP --> Webserver VM 0 (Ubuntu, Nginx)
     +-- Tailscale Mesh IP --> Webserver VM 1 (Ubuntu, Nginx)

[ Raspberry Pi - Lokaal Netwerk ]
  K3s Cluster (ARMv7, 32-bit) / Tailscale Bridge
     |
     +-- Portainer   (poort 30777)
     +-- Homer       (poort 30080)
     +-- Uptime Kuma (poort 30031)
     +-- Grafana     (poort 30030)
```

---

## 3. Azure Cloud Laag

### 3.1 Compute & Netwerk

| Resource | Waarde | Reden |
|---|---|---|
| VM-type | `Standard_B2ats_v2` | Enige door schoolbeleid toegestane SKU |
| OS | Ubuntu Server 22.04 LTS | Stabiel, breed ondersteund |
| Disk type | Standard HDD LRS | Kostenbesparend binnen €150 budget |
| Regio | `westeurope` | Dichtstbijzijnde beschikbare regio |
| Adresruimte VNet | `10.0.0.0/16` | Voldoende ruimte voor groei |
| Subnet | `10.0.1.0/24` | 254 bruikbare adressen |
| Public IPs | 2x Static, SKU Standard | Vereist voor Standard NSG |

### 3.2 Network Security Group (NSG) Regels

| Prioriteit | Naam | Poort | Protocol | Richting | Actie |
|---|---|---|---|---|---|
| 100 | Allow-SSH-Pi | 22 | TCP | Inbound | Allow (vanaf Pi-IP) |
| 110 | Allow-HTTP | 80 | TCP | Inbound | Allow |
| 120 | Allow-HTTPS | 443 | TCP | Inbound | Allow |
| 130 | Allow-Tailscale | 41641 | UDP | Inbound | Allow |
| * | (Standaard) | Alle | Alle | Inbound | Deny |

De NSG is gekoppeld aan het subnet zodat alle VM's automatisch worden beschermd.

### 3.3 SSH Sleutelbeheer

Terraform genereert bij elke `terraform apply` dynamisch een RSA-sleutelpaar (4096-bit)
via de `tls_private_key` module. De publieke sleutel wordt direct in de VM geplaatst.
De private sleutel (`id_rsa.pem`) wordt lokaal opgeslagen in `~/homelab/azure/` met
strikte rechten (`chmod 600`). Wachtwoord-authenticatie is uitgeschakeld op OS-niveau.

---

## 4. Raspberry Pi Edge Laag

### 4.1 Hardware & OS

| Eigenschap | Waarde |
|---|---|
| Hardware | Raspberry Pi (ARMv7l, 32-bit) |
| OS | Raspberry Pi OS (Debian-based) |
| RAM | 2 GB (krap, vereist efficiëntiemaatregelen) |

### 4.2 K3s Configuratie

K3s is geïnstalleerd met de volgende flags om geheugenverbruik te minimaliseren:
```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --disable servicelb" sh -
```

| Uitgeschakeld | Reden | Besparing |
|---|---|---|
| Traefik | Zware reverse proxy, niet nodig voor dit MVP | ~350 MB RAM |
| ServiceLB | Load balancer die conflicteert met NodePort aanpak | ~50 MB RAM |

### 4.3 Containerplatform Apps

| App | Type | NodePort | Functie |
|---|---|---|---|
| Portainer | Container | 30777 | Visueel K3s/container beheer |
| Homer | Static Dashboard | 30080 | Centrale startpagina |
| Uptime Kuma | Monitoring | 30031 | Beschikbaarheidsmonitoring |
| Grafana | Visualisatie | 30030 | Grafieken en dashboards |
| Prometheus | Metrics DB | 30090 | Dataverzameling voor Grafana |

---

## 5. Automatiseringslaag (IaC)

### 5.1 Toolketen

| Tool | Versie | Verantwoordelijkheid |
|---|---|---|
| Terraform | 1.8.x (ARM) | Infrastructuur aanmaken in Azure |
| Ansible | 2.x | Software configureren op VM's en Pi |
| Bash | 5.x | Orchestratie en glue-logic |

### 5.2 Bestandsstructuur

```
~/homelab/
├── azure/                    # Scripts & Infra
│   ├── main.tf               # Terraform: Azure infra
│   ├── deploy_all.sh         # Master Deploy Script (E2E)
│   ├── destroy_all.sh        # Master Destroy Script
│   ├── setup_env.sh          # Credentials
│   ├── playbook_k3s_homelab.yml
│   └── playbook_azure_webservers.yml
└── manifests/                # K3s YAML configs
    ├── homer.yml
    ├── homer-config.yml
```

### 5.3 Deploy Flow

```
./bootstrap.sh --full
       |
       v
  FASE 1: apt update, Ansible, Terraform, Tailscale installeren
       |
       v
  FASE 2: K3s + Helm installeren, aliases toevoegen
       |
       v
  FASE 3: K3s apps deployen via playbook_k3s_homelab.yml
       |
       v
  FASE 4: Azure credentials laden (bestand of handmatig)
       |  terraform init + apply
       |  IPs ophalen en inventory bijwerken
       |  Wachten op VMs
       |  Nginx deployen via playbook_azure_webservers.yml
       v
  Output: "Webserver 0: http://x.x.x.x"
```

---

## 6. Bekende Problemen & Oplossingen

| Probleem | Oorzaak | Oplossing |
|---|---|---|
| `RequestDisallowedByPolicy` | Schoolbeleid verbiedt `Standard_B1s` | Gebruik `Standard_B2ats_v2` |
| `SkuNotAvailable` | Regio heeft geen capaciteit | Wissel regio (`westeurope`, `eastus`) |
| `409 Conflict` | Oude resources hangen nog in Azure | Versie-suffix toevoegen (`-v4`) |
| `403 Forbidden` | Pi mag Azure providers niet registreren | `skip_provider_registration = true` |
| K3s OOM crashes | 2GB RAM te krap met Traefik | Traefik en ServiceLB uitschakelen |
| `Helm schema-validation error` | `bjw-s/app-template` v2+ schema wijziging | Gebruik nieuwe controller/service syntax |
| Terraform lock conflict (ARM vs x86) | `.lock.hcl` gegenereerd op andere CPU | `rm .terraform.lock.hcl` + `terraform init` |

---

## 7. Toekomstige Verbeteringen (Out of Scope voor MVP)

- **Azure Key Vault**: Centrale opslag van SSH private keys, zodat deze niet als lokale bestanden bewaard hoeven te worden.
- **Auto-Scaling**: Het automatisch bijschalen van webservers op basis van verkeersdrukte via Terraform/Azure Monitor.
- **CI/CD Pipeline**: Het integreren van GitHub Actions om de bestanden automatisch naar de Pi te pushen bij een commit.
