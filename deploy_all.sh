#!/bin/bash
# ============================================================
# deploy_all.sh
# Doel: Terraform + Ansible selectief of volledig uitvoeren
# ============================================================

set -e  # Stop bij een fout

AZURE_DIR=~/homelab/azure
INVENTORY=$AZURE_DIR/inventory_azure.yml

# Kleuren
GROEN='\033[0;32m'
BLAUW='\033[0;34m'
GEEL='\033[1;33m'
RESET='\033[0m'

echo "================================================"
echo "Homelab Deployer"
echo "================================================"
echo "Kies wat je wilt uitrollen:"
echo "  1) Alleen Azure Infrastructuur (Terraform)"
echo "  2) Alleen Azure Configuratie (Nginx/Tailscale)"
echo "  3) Alleen Lokale K3s Services (Homer/Portainer)"
echo "  4) VOLLEDIGE Deployment (Azure + K3s)"
echo ""
read -p "Keuze (1/2/3/4): " keuze

# --- Helper: Azure credentials laden ---
load_env() {
    if [ -f "$AZURE_DIR/setup_env.sh" ]; then
        source $AZURE_DIR/setup_env.sh
    else
        echo "Fout: setup_env.sh niet gevonden."
        exit 1
    fi
}

# --- Helper: IPs ophalen ---
get_ips() {
    cd $AZURE_DIR
    IP_0=$(terraform output -raw webserver_0_ip 2>/dev/null || echo "Onbekend")
    IP_1=$(terraform output -raw webserver_1_ip 2>/dev/null || echo "Onbekend")
}

# --- Stap: Azure Infra ---
deploy_infra() {
    echo -e "\n${BLAUW}[STAP] Azure Infrastructuur opbouwen...${RESET}"
    load_env
    cd $AZURE_DIR
    terraform init -upgrade
    terraform apply -auto-approve
    get_ips
    
    # Inventory bijwerken
    cat > $INVENTORY << EOF
all:
  children:
    azure_webservers:
      hosts:
        webserver-0:
          ansible_host: $IP_0
          ansible_user: adminuser
          ansible_ssh_private_key_file: ~/homelab/azure/id_rsa.pem
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
        webserver-1:
          ansible_host: $IP_1
          ansible_user: adminuser
          ansible_ssh_private_key_file: ~/homelab/azure/id_rsa.pem
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
EOF
}

# --- Stap: Azure Config ---
configure_azure() {
    echo -e "\n${BLAUW}[STAP] Azure VMs configureren (Ansible)...${RESET}"
    load_env
    get_ips
    
    if [ "$IP_0" == "Onbekend" ]; then
        echo "Fout: Geen Azure IPs gevonden. Run eerst stap 1."
        exit 1
    fi

    # Auth Key vragen
    if [ -z "$TAILSCALE_AUTHKEY" ]; then
        read -sp "Voer Tailscale Auth Key in: " TAILSCALE_AUTHKEY
        echo ""
    fi

    echo "Wachten op bereikbaarheid van VMs..."
    for IP in $IP_0 $IP_1; do
        until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i $AZURE_DIR/id_rsa.pem adminuser@$IP "echo ok" &>/dev/null; do
            echo -n "."
            sleep 5
        done
    done
    echo " VMs zijn online!"

    ansible-playbook $AZURE_DIR/playbook_azure_webservers.yml \
        -i $INVENTORY \
        --extra-vars "tailscale_authkey=$TAILSCALE_AUTHKEY"
}

# --- Stap: K3s Apps ---
deploy_k3s() {
    echo -e "\n${BLAUW}[STAP] Lokale K3s Services uitrollen...${RESET}"
    ansible-playbook $AZURE_DIR/playbook_k3s_homelab.yml
}

# --- Stap: Eindrapport ---
show_report() {
    get_ips
    # Tailscale IPs ophalen (indien mogelijk)
    TS_0=$(ssh -o StrictHostKeyChecking=no -i $AZURE_DIR/id_rsa.pem adminuser@$IP_0 "tailscale ip -4" 2>/dev/null || echo "Nog niet verbonden")
    TS_1=$(ssh -o StrictHostKeyChecking=no -i $AZURE_DIR/id_rsa.pem adminuser@$IP_1 "tailscale ip -4" 2>/dev/null || echo "Nog niet verbonden")

    echo -e "\n"
    echo "================================================"
    echo -e "         ${GROEN}HOMELAB DEPLOYMENT REPORT${RESET}"
    echo "================================================"
    echo -e "${GEEL}CLOUD INFRASTRUCTURE (Azure):${RESET}"
    echo "  - Webserver 0: http://$IP_0 (TS: $TS_0)"
    echo "  - Webserver 1: http://$IP_1 (TS: $TS_1)"
    echo ""
    echo -e "${GEEL}LOCAL SERVICES (Pi):${RESET}"
    echo "  - Homer Dashboard: http://192.168.1.133:30080"
    echo "  - Portainer:       http://192.168.1.133:30777"
    echo "  - Uptime Kuma:     http://192.168.1.133:30031"
    echo "  - Grafana:         http://192.168.1.133:30030"
    echo ""
    echo -e "${GEEL}SECURITY:${RESET}"
    echo "  - Port 22 is beperkt tot jouw Pi-IP (Data-Source in Terraform)"
    echo "  - Alle beheer kan voortaan veilig via Tailscale IPs."
    echo "================================================"
    
    # Portainer check
    echo -e "\n${GEEL}Portainer Tip:${RESET}"
    echo "Als Portainer om een restart vraagt (timeout):"
    echo "kubectl rollout restart deployment portainer -n portainer"
    echo "================================================"
}

# --- Hoofdlogica ---
case $keuze in
    1) deploy_infra ;;
    2) configure_azure ;;
    3) deploy_k3s ;;
    4) deploy_infra; configure_azure; deploy_k3s; show_report ;;
    *) echo "Ongeldige keuze."; exit 1 ;;
esac

# Rapportage altijd tonen aan het eind van een volledige deploy of na apps
if [ "$keuze" == "3" ] || [ "$keuze" == "4" ]; then
    show_report
fi
