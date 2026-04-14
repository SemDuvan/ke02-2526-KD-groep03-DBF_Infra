# Requirements Document
## DBF Casus - KE02 Automation (2025-2026)

Dit document beschrijft de 12 gestelde requirements waaraan het Minimum Viable Product
(MVP) van "de dienst" dient te voldoen. De eisen zijn opgesteld volgens de
SMART-methodiek (Specifiek, Meetbaar, Acceptabel, Realistisch, Tijdgebonden).

---

## 1. Functionele Requirements

**F-REQ-01: Volledige IaC Provisioning**
De volledige cloud-infrastructuur (netwerk, Network Security Groups, public IP's en
Virtual Machines) wordt 100% middels code (Terraform) aangemaakt in Microsoft Azure.
Dit is gedemonstreerd door succesvolle uitvoering van `terraform apply` zonder manuele
handelingen in de Azure Portal.

**F-REQ-02: Geautomatiseerde Serverconfiguratie**
De configuratie en installatie van de benodigde software op de front-end webservers in
Azure verloopt geautomatiseerd via Ansible. Het succes is meetbaar door binnen 5 minuten
na provisionering een werkende (HTTP 200) Nginx-webpagina te valideren.

**F-REQ-03: Externe Connectiviteit**
Er worden maximaal twee publieke IPv4-adressen vanuit Azure toegewezen aan de
front-end servers, waardoor eindgebruikers de dienst via TCP-poorten 80 en 443 kunnen
bezoeken vanaf elke willekeurige locatie met internetverbinding.

**F-REQ-04: Network Security Group Beheer**
Alle verkeersstromen in en richting het cloud-netwerk worden beveiligd door een via
Terraform gedeclareerde Network Security Group (NSG), die al het inkomende verkeer
standaard blokkeert en uitsluitend verkeer toestaat op poort 22, 80 en 443.

**F-REQ-05: Geautomatiseerde Ontmanteling (Decommissioning)**
De infrastructuur biedt een geïntegreerd ontmantelingsplan: via het script `./destroy_all.sh` (of de alias `destroyall`) wordt de gehele Azure-omgeving inclusief K3s-vlakken, zonder menselijke interventie binnen 10 minuten volledig verwijderd.

**F-REQ-09: Secure Hybrid Networking**
Er is een veilige, geëncrypteerde verbinding (Tailscale Mesh VPN) actief tussen de Raspberry Pi en de Azure Virtual Machines. Dit maakt beheer over een private tunnel mogelijk en biedt een extra beveiligingslaag bovenop de NSG.

**F-REQ-06: Containerisatie van Applicaties**
De monitoring- en beheerdiensten op de Raspberry Pi maken gebruik van containerisatie:
minimaal 4 applicaties (Portainer, Homer, Uptime Kuma, Grafana/Prometheus) draaien als
permanente containerized diensten op het K3s Kubernetes-platform.

**F-REQ-07: Key-based SSH Authorisatie**
Toegang via poort 22 tot de Azure VM's is uitsluitend mogelijk met asymmetrische
RSA-sleutelparen (4096-bit), die Terraform dynamisch genereert bij deployment.
Wachtwoord-authenticatie is expliciet uitgeschakeld.

**F-REQ-08: Beschikbaarheids Monitoring**
Er is verifieerbaar een monitoring-service geïnstalleerd en geconfigureerd (Uptime Kuma
en/of Grafana/Prometheus), die de beschikbaarheid van applicaties en hosts bewaakt en
zichtbaar maakt via een dashboard.

---

## 2. Niet-Functionele Requirements

**NF-REQ-01: Financiële Beheersbaarheid**
De cloudkosten op Microsoft Azure mogen het budget van €150 niet overstijgen. Dit is
technisch gewaarborgd door gebruik van low-cost SKU's (`Standard_B2ats_v2`, Standard
HDD LRS) en het uitschakelen van ongebruikte componenten buiten werktijden.

**NF-REQ-02: Hardware-efficiëntie op Edge-devices**
De K3s-omgeving op de ARMv7 Raspberry Pi is dusdanig geconfigureerd (o.a. uitschakeling
van Traefik en ServiceLB) dat het totale werkgeheugenverbruik onder normale
omstandigheden onder de 1.5 GB blijft, ter voorkoming van systeeminstabiliteit.

**NF-REQ-03: Portabiliteit van de Codebase**
De IaC-codebase vereist geen Azure-portaltoegang of grafische interfaces. De volledige
omgeving kan via één enkel commando (`./bootstrap.sh --full`) worden opgebouwd vanaf
elke machine met een terminal en internetverbinding.

**NF-REQ-04: Resiliency tegen Azure Policies**
De IaC-code anticipeert op beperkende Azure Management Group policies (zoals het 
verbod op bepaalde VM-groottes) door gebruik van de toegestane `Standard_B2ats_v2`
instance-type en `skip_provider_registration = true`, waardoor betrouwbare deployment
binnen de beheerde schoolomgeving is gegarandeerd.
