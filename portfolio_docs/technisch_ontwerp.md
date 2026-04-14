# Technisch Ontwerp (TO)
## DBF Casus - KE02 Automation (2025-2026)

---

## 1. Doel

Dit Technisch Ontwerp beschrijft de concrete technische realisatie van het DBF Homelab. Het legt uit hoe automatisering (IaC), netwerkbeveiliging (Tailscale) en data-persistentie (PVC) zijn ingericht voor een robuuste en reproduceerbare deployment.

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

| App | Type | NodePort | Storage | Functie |
|---|---|---|---|---|
| Portainer | Container | 30777 | - | Visueel container beheer |
| Homer | Dashboard | 30080 | ConfigMap | Centrale startpagina |
| Uptime Kuma | Monitoring | 30031 | **PVC (1Gi)** | Beschikbaarheidsmonitoring |
| Grafana | Dashboard | 30030 | - | Visualisatie van metrics |
| Prometheus | DB | 30090 | - | Dataverzameling |

*Noot: Uptime Kuma maakt gebruik van `local-path` storage op de Pi, waardoor monitor-instellingen bewaard blijven bij een crash of herstart.*

---

## 5. Automatiseringslaag (IaC)

### 5.1 Toolketen

| Tool | Versie | Verantwoordelijkheid |
|---|---|---|
| Terraform | 1.8.x (ARM) | Infrastructuur aanmaken in Azure |
| Ansible | 2.x | Software configureren op VM's en Pi |
| Bash | 5.x | Orchestratie en glue-logic |

#### 5.2 Bestandsstructuur

De repository is georganiseerd volgens het principe van *separation of concerns*:

```
/ (Root)
├── playbooks/                # Ansible playbooks (k3s, azure, site)
├── manifests/                # Kubernetes YAML manifests (homer)
├── portfolio_docs/          # [GEÏGNOREERD] Project documentatie
├── misc/                    # [GEÏGNOREERD] Debugging en tijdelijke bestanden
├── main.tf                  # Terraform Azure infra
├── setup_env.sh.example     # Template voor Azure credentials
├── bootstrap.sh             # Master Smart Installer
├── deploy_all.sh            # Management script
└── destroy_all.sh           # Cleanup script (incl. Hard Reset)
```

### 5.3 Deploy Flow

```
./bootstrap.sh [--full | --express]
       |
       v
  FASE 0: Git check & Auto-pull (Script haalt eigen updates op)
       |
       v
  FASE 1: Systeem update (optioneel in Express), Ansible & Terraform installeren
       |
       v
  FASE 2: K3s node setup + Homelab Aliases toevoegen
       |
       v
  FASE 3: K3s Apps (incl. PVC voor Uptime Kuma) via Ansible
       |
       v
  FASE 4: Azure Cloud Infra setup via Terraform
       v
  Output: "Deployment succesvol - Dashboard bereikbaar op [IP]"
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

---

## 7. Beveiligingsanalyse

Hoewel dit project een Proof of Concept is, zijn er bewuste keuzes gemaakt om de veiligheid te waarborgen. Hieronder volgt een analyse van de huidige status en potentiële risico's.

### 7.1 Sterke Punten
*   **Zero-Exposed Ports**: Dankzij de Tailscale Mesh VPN zijn er geen poorten (zoals SSH) open naar het publieke internet. Alle communicatie verloopt via een versleutelde private tunnel.
*   **Key-based Authentication**: Wachtwoord-authenticatie is volledig uitgeschakeld. Toegang is alleen mogelijk via RSA (4096-bit) of Ed25519 sleutels.
*   **Infrastructure-as-Code (IaC) Secrets**: Gevoelige bestanden zoals `setup_env.sh` en SSH-sleutels worden via `.gitignore` uit de versiebeheer gehouden.

### 7.2 Bekende Risico's & Enterprise Verbeteringen
In een professionele productieomgeving zouden de volgende stappen ondernomen worden om de beveiliging naar een hoger niveau te tillen:
*   **Secret Management**: Momenteel staan de Azure credentials in platte tekst in `setup_env.sh`. *Oplossing:* Implementatie van **Azure Key Vault** of HashiCorp Vault.
*   **Terraform State Security**: De "state" van de infrastructuur staat momenteel lokaal. *Oplossing:* Gebruik van een **Remote Backend** (bijv. Azure Blob Storage) met encryptie en State Locking.
*   **Ansible Vault**: Sensitieve variabelen worden als "extra vars" meegegeven. *Oplossing:* Gebruik van **Ansible Vault** om geheimen binnen playbooks te versleutelen.
*   **Least Privilege**: De Azure Service Principal heeft momenteel de rol "Contributor". *Oplossing:* Rechten beperken tot strikt noodzakelijke acties binnen een specifieke Resource Group.

---

## 8. Toekomstige Verbeteringen (Out of Scope)

- **CI/CD Pipeline**: Het integreren van GitHub Actions om wijzigingen automatisch te testen en uit te rollen.
- **Dynamic Scaling**: Automatisch bijschalen van webservers op basis van CPU-belasting.
- **Central Logging**: Het verzamelen van logs uit Azure en K3s in een centraal ELK- of Grafana Loki-systeem.
