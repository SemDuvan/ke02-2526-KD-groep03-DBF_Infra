#!/bin/bash
# ============================================================
# bootstrap.sh
# Master bootstrap script voor het DBF Homelab
# ============================================================

set -e

# --- Kleuren voor output ---
GROEN='\033[0;32m'
GEEL='\033[1;33m'
ROOD='\033[0;31m'
BLAUW='\033[0;34m'
RESET='\033[0m'

# --- Instellingen & Config ---
CONFIG_FILE="$HOME/.homelab_config"

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        # Eerste keer draaien: Vraag de gebruiker om een naam
        echo -e "${GEEL}Welkom bij de DBF Homelab Installer!${RESET}"
        read -p "Hoe wil je de projectmap noemen? [Standaard: homelab]: " chosen_name < /dev/tty
        HOMELAB_NAME=${chosen_name:-homelab}
        echo "HOMELAB_NAME=$HOMELAB_NAME" > "$CONFIG_FILE"
        export HOMELAB_NAME
    fi
    HOMELAB_DIR="$HOME/$HOMELAB_NAME"
    PLAYBOOKS_DIR="$HOMELAB_DIR/playbooks"
    MANIFESTS_DIR="$HOMELAB_DIR/manifests"
}

load_config

log_stap()  { echo -e "\n${BLAUW}[STAP]${RESET} $1"; }
log_ok()    { echo -e "${GROEN}[OK]${RESET} $1"; }
log_skip()  { echo -e "${GEEL}[SKIP]${RESET} $1 (al geinstalleerd)"; }
log_fout()  { echo -e "${ROOD}[FOUT]${RESET} $1"; exit 1; }

# ============================================================
# FASE 0: SMART INSTALLER LOGICA
# ============================================================
fase_0() {
    log_stap "Pre-flight checks uitvoeren..."

    # 1. Controleer op Git
    if ! command -v git &>/dev/null; then
        log_stap "Git niet gevonden. Bezig met installeren..."
        sudo apt-get update -qq && sudo apt-get install -y -qq git
        log_ok "Git succesvol geinstalleerd."
    fi

    # 2. Controleer op Repository
    REPO_URL="https://github.com/SemDuvan/ke02-2526-KD-groep03-DBF_Infra.git"
    if [ ! -d "$HOMELAB_DIR/.git" ]; then
        log_stap "Repository $HOMELAB_NAME instellen op $HOMELAB_DIR..."
        
        if [ -d "$HOMELAB_DIR" ]; then
            # Map bestaat al, maar is geen Git repo. We gaan hem omzetten.
            log_stap "Bestaande map gevonden. Omzetten naar Git repository..."
            cd "$HOMELAB_DIR"
            git init -q
            git remote add origin "$REPO_URL"
            git fetch -q origin
            git checkout -f main
        else
            # Map bestaat nog helemaal niet, gewoon clonen.
            log_stap "Bezig met clonen van repository..."
            mkdir -p "$HOMELAB_DIR"
            git clone -q "$REPO_URL" "$HOMELAB_DIR"
        fi
        
        log_ok "Repository succesvol gesynchroniseerd."
        
        # Herstarten vanaf de officiële repository zodat alle paden kloppen
        log_stap "Herstarten vanaf de nieuwe locatie ($HOMELAB_DIR)..."
        exec bash "$HOMELAB_DIR/bootstrap.sh" "$@"
    fi

    # 3. Indien we al in de repo zijn maar niet in de juiste map, wissel van map
    if [[ "$(pwd)" != "$(realpath $HOMELAB_DIR)" ]]; then
        cd "$HOMELAB_DIR" || log_fout "Kon niet wisselen naar $HOMELAB_DIR"
    fi
}

# Voer Fase 0 ALTIJD uit bij het starten
fase_0 "$@"

# ============================================================
# WELKOMSTSCHERM
# ============================================================
clear
echo "=============================================="
echo "  DBF Homelab - Master Bootstrap Script"
echo "=============================================="
echo ""
echo "Kies een modus:"
echo "  1) --full         Alles installen + Azure deployen"
echo "  2) --azure-only   Alleen Azure deployen"
echo "  3) --k3s-only     Alleen K3s apps deployen"
echo "  4) --destroy-all  ALLES VERWIJDEREN (Azure + K3s + Config)"
echo ""

if [ "$1" == "--full" ] || [ "$1" == "--azure-only" ] || [ "$1" == "--k3s-only" ] || [ "$1" == "--destroy-all" ]; then
    MODUS=$1
else
    read -p "Keuze (1/2/3/4): " keuze < /dev/tty
    case $keuze in
        1) MODUS="--full" ;;
        2) MODUS="--azure-only" ;;
        3) MODUS="--k3s-only" ;;
        4) MODUS="--destroy-all" ;;
        *) log_fout "Ongeldige keuze. Gebruik 1, 2, 3 of 4." ;;
    esac
fi

echo ""
echo "Gekozen modus: $MODUS"
echo "----------------------------------------------"

# ============================================================
# FASE 1: PI BASIS INSTALLATIE
# ============================================================
fase_1() {
    echo ""
    echo "=============================================="
    echo "  FASE 1: Pi Basis Installatie"
    echo "=============================================="

    log_stap "Systeem bijwerken..."
    sudo apt-get update -qq && sudo apt-get upgrade -y -qq
    log_ok "Systeem bijgewerkt"

    log_stap "Essentiële tools installeren (curl, jq, unzip)..."
    sudo apt-get install -y -qq curl jq unzip sshpass
    log_ok "Basis tools geinstalleerd"

    # --- Ansible ---
    log_stap "Ansible controleren..."
    if ! command -v ansible &>/dev/null; then
        sudo apt-get install -y -qq ansible
        log_ok "Ansible geinstalleerd ($(ansible --version | head -1))"
    else
        log_skip "Ansible"
    fi

    # --- Terraform (ARM32 versie voor Pi) ---
    log_stap "Terraform controleren..."
    if ! command -v terraform &>/dev/null; then
        TF_VERSION="1.8.5"
        TF_ARCH="linux_arm"
        curl -sLO "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_${TF_ARCH}.zip"
        unzip -o "terraform_${TF_VERSION}_${TF_ARCH}.zip" -d /tmp/
        sudo mv /tmp/terraform /usr/local/bin/terraform
        sudo chmod +x /usr/local/bin/terraform
        rm "terraform_${TF_VERSION}_${TF_ARCH}.zip"
        log_ok "Terraform geinstalleerd ($(terraform version | head -1))"
    else
        log_skip "Terraform"
    fi

    # --- Tailscale ---
    log_stap "Tailscale controleren..."
    if ! command -v tailscale &>/dev/null; then
        curl -fsSL https://tailscale.com/install.sh | sh
        log_ok "Tailscale geinstalleerd"
        echo ""
        echo "----------------------------------------------"
        echo "Tailscale instellen. Kies een methode:"
        echo "  1) Ik log in met een link (eigen account)"
        echo "  2) Ik gebruik een Auth Key (gekregen van beheerder)"
        echo "  3) Tailscale nu overslaan (doe ik later zelf)"
        read -p "Keuze (1/2/3): " ts_keuze < /dev/tty
        case $ts_keuze in
            1)
                sudo tailscale up
                log_ok "Tailscale verbonden via account"
                ;;
            2)
                read -p "Plak hier je Auth Key: " ts_key < /dev/tty
                sudo tailscale up --authkey="$ts_key"
                log_ok "Tailscale verbonden via Auth Key"
                ;;
            3)
                log_skip "Tailscale (handmatig instellen via: sudo tailscale up)"
                ;;
        esac
    else
        log_skip "Tailscale"
    fi
}

# ============================================================
# FASE 2: K3S + HELM
# ============================================================
fase_2() {
    echo ""
    echo "=============================================="
    echo "  FASE 2: K3s Cluster Opzetten"
    echo "=============================================="

    # --- K3s ---
    log_stap "K3s controleren..."
    if ! command -v k3s &>/dev/null; then
        curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --disable servicelb" sh -
        log_ok "K3s geinstalleerd"
        sleep 10  # Even wachten tot K3s volledig opstart
    else
        log_skip "K3s"
    fi

    log_stap "Kubeconfig instellen..."
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $(id -u):$(id -g) ~/.kube/config
    sudo chmod 600 ~/.kube/config
    export KUBECONFIG=~/.kube/config
    log_ok "Kubeconfig ingesteld"

    # --- Helm ---
    log_stap "Helm controleren..."
    if ! command -v helm &>/dev/null; then
        curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        log_ok "Helm geinstalleerd ($(helm version --short))"
    else
        log_skip "Helm"
    fi

    # --- Aliases toevoegen ---
    log_stap "Homelab aliases instellen..."
    if ! grep -q "=== Homelab Aliases ===" ~/.bashrc; then
        cat >> ~/.bashrc << EOF

# === Homelab Aliases ===
export HOMELAB_NAME="$HOMELAB_NAME"
export HOMELAB_DIR="$HOMELAB_DIR"
alias tfazure='cd \$HOMELAB_DIR && source setup_env.sh'
alias k3sdeploy='ansible-playbook \$HOMELAB_DIR/playbooks/playbook_k3s_homelab.yml'
alias azuredeploy='ansible-playbook \$HOMELAB_DIR/playbooks/playbook_azure_webservers.yml -i \$HOMELAB_DIR/inventory_azure.yml'
alias deployall='bash \$HOMELAB_DIR/deploy_all.sh'
alias destroyall='bash \$HOMELAB_DIR/destroy_all.sh'
EOF
        log_ok "Aliases toegevoegd aan .bashrc"
    else
        log_skip "Aliases (staan al in .bashrc)"
    fi
}

# ============================================================
# FASE 3: K3S APPS DEPLOYEN
# ============================================================
fase_3() {
    echo ""
    echo "=============================================="
    echo "  FASE 3: K3s Apps Deployen"
    echo "  (Portainer, Homer, Grafana, Uptime Kuma)"
    echo "=============================================="

    if [ ! -f "$PLAYBOOKS_DIR/playbook_k3s_homelab.yml" ]; then
        log_fout "Bestand niet gevonden: $PLAYBOOKS_DIR/playbook_k3s_homelab.yml"
    fi

    export KUBECONFIG=~/.kube/config
    ansible-playbook "$PLAYBOOKS_DIR/playbook_k3s_homelab.yml"
    log_ok "K3s apps succesvol gedeployed"
}

# ============================================================
# FASE 4: AZURE DEPLOYEN
# ============================================================
fase_4() {
    echo ""
    echo "=============================================="
    echo "  FASE 4: Azure Cloud Deployen"
    echo "=============================================="

    # --- Credentials keuzescherm ---
    echo ""
    echo "Hoe wil je je Azure credentials laden?"
    echo "  1) Uit een bestaand .sh bestand"
    echo "  2) Handmatig invoeren"
    echo ""
    read -p "Keuze (1/2): " cred_keuze < /dev/tty

    if [ "$cred_keuze" == "1" ]; then
        read -p "Volledig pad naar je credentials bestand (bijv. ~/homelab/setup_env.sh): " cred_pad < /dev/tty
        cred_pad="${cred_pad/#\~/$HOME}"  # ~ omzetten naar echte path
        if [ ! -f "$cred_pad" ]; then
            log_fout "Bestand niet gevonden: $cred_pad"
        fi
        source "$cred_pad"
        log_ok "Credentials geladen uit: $cred_pad"

    elif [ "$cred_keuze" == "2" ]; then
        echo "Voer je Azure credentials in (input wordt niet getoond):"
        read -sp "  ARM_CLIENT_ID:       " ARM_CLIENT_ID < /dev/tty;       echo ""
        read -sp "  ARM_CLIENT_SECRET:   " ARM_CLIENT_SECRET < /dev/tty;   echo ""
        read -sp "  ARM_TENANT_ID:       " ARM_TENANT_ID < /dev/tty;       echo ""
        read -sp "  ARM_SUBSCRIPTION_ID: " ARM_SUBSCRIPTION_ID < /dev/tty; echo ""
        export ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_TENANT_ID ARM_SUBSCRIPTION_ID
        log_ok "Credentials handmatig ingesteld"
    else
        log_fout "Ongeldige keuze voor credentials"
    fi

    # --- Tailscale Auth Key ---
    echo ""
    echo "Tailscale Auth Key voor Azure VMs:"
    echo "  1) Laad uit omgevingsvariabele (TAILSCALE_AUTHKEY)"
    echo "  2) Handmatig invoeren"
    read -p "Keuze (1/2): " ts_keuze < /dev/tty
    if [ "$ts_keuze" == "1" ]; then
        if [ -z "$TAILSCALE_AUTHKEY" ]; then
            log_fout "TAILSCALE_AUTHKEY is niet ingesteld als omgevingsvariabele."
        fi
        log_ok "Tailscale auth key geladen uit omgevingsvariabele."
    else
        read -sp "  Tailscale Auth Key: " TAILSCALE_AUTHKEY < /dev/tty
        echo ""
        log_ok "Tailscale auth key handmatig ingesteld."
    fi

    # --- Terraform init + apply ---
    log_stap "Klaar voor Azure deployment!"
    read -p "Druk op Enter om Terraform te starten..." < /dev/tty

    cd "$HOMELAB_DIR"

    log_stap "Terraform initialiseren..."
    rm -f .terraform.lock.hcl
    terraform init -upgrade
    log_ok "Terraform geinitialiseerd"

    log_stap "Terraform apply uitvoeren..."
    terraform apply -auto-approve
    log_ok "Infrastructuur aangemaakt in Azure"

    # --- IPs ophalen en inventory bijwerken ---
    log_stap "IP-adressen ophalen uit Terraform output..."
    IP_0=$(terraform output -raw webserver_0_ip)
    IP_1=$(terraform output -raw webserver_1_ip)
    log_ok "Webserver 0: $IP_0"
    log_ok "Webserver 1: $IP_1"

    log_stap "Ansible inventory bijwerken..."
    cat > "$HOMELAB_DIR/inventory_azure.yml" << EOF
# inventory_azure.yml
# Automatisch gegenereerd door bootstrap.sh op $(date)
all:
  children:
    azure_webservers:
      hosts:
        webserver-0:
          ansible_host: $IP_0
          ansible_user: adminuser
          ansible_ssh_private_key_file: \$HOMELAB_DIR/id_rsa.pem
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
        webserver-1:
          ansible_host: $IP_1
          ansible_user: adminuser
          ansible_ssh_private_key_file: \$HOMELAB_DIR/id_rsa.pem
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
EOF
    log_ok "Inventory bijgewerkt"

    # --- Wachten tot VMs bereikbaar zijn ---
    log_stap "Wachten tot Azure VMs bereikbaar zijn (max 3 min)..."
    for IP in $IP_0 $IP_1; do
        echo -n "   Wachten op $IP "
        for i in $(seq 1 36); do
            if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
               -i "$HOMELAB_DIR/id_rsa.pem" adminuser@$IP \
               "echo ok" &>/dev/null; then
                echo " - Bereikbaar!"
                break
            fi
            echo -n "."
            sleep 5
        done
    done

    # --- Ansible playbook uitvoeren ---
    log_stap "Nginx installeren via Ansible..."
    ansible-playbook "$PLAYBOOKS_DIR/playbook_azure_webservers.yml" \
        -i "$HOMELAB_DIR/inventory_azure.yml"
    log_ok "Webservers geconfigureerd"

    echo ""
    echo "=============================================="
    echo "  Azure Deploy Compleet!"
    echo "=============================================="
    echo "  Webserver 0: http://\$IP_0"
    echo "  Webserver 1: http://\$IP_1"
    echo "=============================================="
}

# ============================================================
# HOOFDLOGICA: Welke fases uitvoeren?
# ============================================================
case $MODUS in
    --full)
        fase_1
        fase_2
        fase_3
        fase_4
        ;;
    --azure-only)
        fase_4
        ;;
    --k3s-only)
        fase_3
        ;;
    --destroy-all)
        bash "$HOMELAB_DIR/destroy_all.sh"
        ;;
esac

echo ""
echo "=============================================="
echo "  Bootstrap voltooid!"
echo "  Herstart terminal of: source ~/.bashrc"
echo "=============================================="
