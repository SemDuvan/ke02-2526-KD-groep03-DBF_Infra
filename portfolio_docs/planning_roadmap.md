# Project Roadmap & Planning
## DBF Casus - KE02 Automation (2025-2026)

Dit document beschrijft de voortgang van het project en de geplande stappen voor de volgende fasen van de automatisering en professionalisering.

---

## Fase 1: Fundament (Huidige Status)
*Status: Gerealiseerd*

In deze fase is de basis gelegd voor de hybride cloud omgeving.
- [x] **IaC Provisioning**: Azure infrastructuur volledig via Terraform.
- [x] **Hybride Networking**: Beveiligde Tailscale Mesh VPN tussen Pi en Azure.
- [x] **Edge Computing**: K3s cluster op de Raspberry Pi met resource-optimalisatie.
- [x] **Monitoring Stack**: Portainer, Homer, Grafana en Uptime Kuma (via Helm).
- [x] **Orchestratie**: Master bootstrap en deploy scripts voor "one-command" setup.

---

## Fase 2: Professionalisering (Gepland)
*Focus: Portabiliteit en Beveiliging*

Deze fase richt zich op het maken van een robuuste, herbruikbare toolketen.

### 2.1 Git-Centric Workflow
*   **Doel**: Het `bootstrap.sh` script volledig onafhankelijk maken van lokale bestanden.
*   **Actie**: Toevoegen van `git clone` / `git pull` logica aan het begin van de bootstrap.
*   **Resultaat**: Installatie op een nieuwe Pi vereist alleen het downloaden van één script.

### 2.2 Security Hardening
*   **SSH**: Volledige uitschakeling van publieke SSH poorten (SSH uitsluitend via Tailscale tunnel).
*   **Key Management**: Onderzoeken van Azure Key Vault integratie voor de opslag van de `id_rsa.pem`.
*   **Secrets**: Ansible Vault gebruiken voor het versleutelen van gevoelige variabelen (bijv. Tailscale keys).

### 2.3 Persistence & Storage
*   **Doel**: Dataverlies bij herstart van containers voorkomen.
*   **Actie**: Implementeren van Persistent Volume Claims (PVC) voor Uptime Kuma en Grafana.
*   **Optie**: Gebruik maken van een lokale StorageClass of Azure File Share (indien budget toelaat).

---

## Fase 3: Schaalbaarheid & CI/CD (Toekomst)
*Focus: Enterprise-grade Automatisering*

### 3.1 CI/CD Pipelines
*   Implementatie van GitHub Actions: bij elke `push` naar de repository worden de playbooks automatisch gevalideerd (`ansible-lint`) en eventueel uitgevoerd op de Pi.

### 3.2 Dynamic Scaling
*   Configureren van de Azure Virtual Machine Scale Sets (VMSS) via Terraform om automatisch bij te schalen wanneer de belasting op de Nginx servers toeneemt.

### 3.3 Dashboard Consolidatie
*   Alle monitoring-data (Azure metrics + Pi metrics) samenvoegen in één centraal Grafana dashboard via Prometheus Federation.

---

## Tijdlijn & Prioriteiten

1.  **Prioriteit 1**: Git-integratie in `bootstrap.sh` (Directe impact op gebruiksgemak).
2.  **Prioriteit 2**: Poort-consistentie en Dashboard updates (Afronding portfolio).
3.  **Prioriteit 3**: Security hardening (Vaststellen van het TO resultaat).
