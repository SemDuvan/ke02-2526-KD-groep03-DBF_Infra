# ke02-2526-KD-groep03-DBF_Infra

Dit is de repository voor het hybride cloud homelab project van **Groep 03** voor de casus **KE02 Automation**.

## Project Overzicht
Dit project automatiseert de uitrol van een hybride cloud infrastructuur bestaande uit:
1.  **Azure Cloud**: Nginx webservers geconfigureerd via Terraform en Ansible.
2.  **Raspberry Pi (Edge)**: Een K3s Kubernetes cluster voor monitoring en beheer dashboards.
3.  **Tailscale Mesh VPN**: Een veilige verbinding tussen alle componenten.

## Bestandsstructuur
*   `main.tf`: Terraform configuratie voor Azure resources.
*   `playbook_k3s_homelab.yml`: Ansible playbook voor de lokale diensten op de Pi.
*   `playbook_azure_webservers.yml`: Ansible playbook voor de webservers in de cloud.
*   `bootstrap.sh`: Master script om de volledige omgeving vanaf nul op te bouwen.
*   `portfolio_docs/`: Bevat alle officiële documentatie (Requirements, FO, TO).

## Installatie
1.  Clone deze repository:
    ```bash
    git clone https://github.com/SemDuvan/ke02-2526-KD-groep03-DBF_Infra.git
    ```
    Of:
    ```bash
    curl -sSL https://raw.githubusercontent.com/SemDuvan/ke02-2526-KD-groep03-DBF_Infra/main/bootstrap.sh | bash

    ```
3.  Kopieer het voorbeeld-credential bestand en vul de gegevens in(of voer ze handmatig in):
    ```bash
    cp setup_env.sh.example setup_env.sh
    nano setup_env.sh
    ```
4.  Draai het bootstrap script:
    ```bash
    bash bootstrap.sh
    ```
    

## Stabiliteit & Versiebeheer
Om een voorspelbare en stabiele installatie te garanderen, maakt dit project gebruik vooral van specifieke versies van tools (zoals Terraform 1.8.5). 
*   **Version Pinning**: Softwareversies zijn vastgezet in de scripts om compatibiliteitsproblemen bij toekomstige updates te voorkomen.
*   **One-time Setup**: Het project is ontworpen als een statische 'Proof of Concept'.

## Fixes
Als jullie een probleem hebben met een raspberry pi dat te zwak is voor kubernetes (k3s) voer de fix_2gb.sh file uit
```bash
curl -sSL https://raw.githubusercontent.com/SemDuvan/ke02-2526-KD-groep03-DBF_Infra/main/fix_2gb.sh | bash
```


---
*Gerealiseerd door Groep 03 (2026)*
