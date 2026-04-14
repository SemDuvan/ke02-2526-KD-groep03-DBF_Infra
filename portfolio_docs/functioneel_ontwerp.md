# Functioneel Ontwerp (FO)
## DBF Casus - KE02 Automation (2025-2026)

---

## 1. Inleiding en Doel

Organisatie DBF levert netwerkinfrastructuren en webapplicaties voor klanten, maar staat
onder druk vanwege toenemende concurrentie en krappe doorlooptijden. Het doel van dit
project is een Minimum Viable Product (MVP) te bouwen: een schaalbare, snel uitrolbare
"Dienst" waarbij handmatige installaties volledig overbodig zijn.

Er is gekozen voor een **hybride model**:
- **Azure Cloud Platform**: voor de publiek bereikbare front-end webdienst.
- **Raspberry Pi Edge Platform**: als lokale beheer- en monitoringbackend met K3s.

---

## 2. Scope

### Binnen scope:
- Geautomatiseerd aanmaken van een netwerkinfrastructuur (VNet, Subnetten, NSG).
- Opleveren en configureren van front-end webservers via code.
- Volledig geautomatiseerde de-provisionering (afbreken) van de cloud-omgeving.
- Lokaal K3s-platform met containerisatie voor monitoring en beheerdiensten.

### Buiten scope (in overleg met de opdrachtgever):
- Back-end database (gedeactiveerd wegens Azure-beleidsbeperkingen en kostenoptimalisatie).
- Azure Portal, GUI-tools en Azure Console voor deployment.
- Identity management en Active Directory.

---

## 3. Actoren

| Actor | Omschrijving |
|---|---|
| **Eindgebruiker / Klant** | Bezoekt de webapplicatie via een browser op het publieke internet (poort 80/443). |
| **DBF Infrastructure Engineer** | Beheert de cloud via terminal. Voert `./bootstrap.sh` uit om de volledige omgeving op te zetten. |
| **DBF Beheerder** | Bekijkt monitoring dashboards (Grafana, Uptime Kuma) via het lokale Pi-netwerk. |

---

## 4. Use Cases

### UC-01: Zero-Tap Cloud Deploy
**Actoren:** DBF Infrastructure Engineer  
**Doel:** Webinfrastructuur in Azure aanmaken zonder handmatige stappen.  
**Stappen:**
1. Engineer draait `./bootstrap.sh --full` op de Raspberry Pi.
2. Script installeert Terraform, Ansible en alle afhankelijkheden.
3. Terraform maakt VNet, Subnet, NSG, Public IPs en twee VM's aan in Azure.
4. Ansible installeert automatisch Nginx op beide VM's.
5. Script toont de publieke IP-adressen van de webservers.  
**Resultaat:** Een werkende website bereikbaar via het internet, binnen 25 minuten.

---

### UC-02: Netwerk Beveiligen via NSG
**Actoren:** DBF Infrastructure Engineer  
**Doel:** Alle niet-geautoriseerd netwerkverkeer blokkeren.  
**Stappen:**
1. Terraform declareert een NSG met expliciete Allow-regels voor poort 22, 80 en 443.
2. NSG wordt gekoppeld aan het subnet (alle VM's worden automatisch beschermd).
3. Al het overige inkomende verkeer wordt impliciet geblokkeerd.  
**Resultaat:** Een hermetisch beveiligd netwerk dat uitsluitend noodzakelijk verkeer doorlaat.

---

### UC-03: Kostenbeheersing via Decommissioning
**Actoren:** DBF Cost Manager / Engineer  
**Doel:** Cloudkosten minimaliseren buiten werktijden.  
**Stappen:**
1. Engineer voert `destroyall` uit op de Pi.
2. Script verwijdert alle Azure resources én de K3s namespaces op de Pi.
3. Geen enkele betaalde Azure-resource blijft achter.  
**Resultaat:** Cloudkosten dalen naar €0 en de Pi is opgeschoond buiten activiteitsvensters.

---

### UC-04: Lokaal Beheer via Containerplatform
**Actoren:** DBF Beheerder  
**Doel:** Inzicht krijgen in de status van alle draaiende applicaties.  
**Stappen:**
1. K3s draait permanent op de Raspberry Pi.
2. Beheerder opent Homer op `http://192.168.1.133:30080` voor een centraal overzicht.
3. Beheerder beheert containers via Portainer op poort 30777.
4. Beheerder bekijkt uptime van services via Uptime Kuma op poort 30031.  
**Resultaat:** Volledig inzicht in de beschikbaarheid en gezondheid van de dienst.

---

### UC-05: Veilige Hybride Connectiviteit (Tailscale)
**Actoren:** DBF Infrastructure Engineer  
**Doel:** Servers beheren zonder poort 22 publiek open te stellen.  
**Stappen:**
1. Tailscale tunnel wordt automatisch opgezet bij deployment.
2. VM's krijgen een privé Tailscale-IP in de mesh.
3. Engineer logt in via het Tailscale IP vanaf de Pi of eigen laptop.  
**Resultaat:** Beheer is onzichtbaar en onbereikbaar voor aanvallers op het publieke internet.
