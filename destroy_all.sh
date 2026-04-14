#!/bin/bash
# ============================================================
# destroy_all.sh
# Doel: Alles verwijderen (Azure + K3s + Config)
# ============================================================

# --- Instellingen & Config Laden ---
CONFIG_FILE="$HOME/.homelab_config"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    HOMELAB_DIR="$HOME/$HOMELAB_NAME"
else
    # Fallback naar standaard als config ontbreekt
    HOMELAB_NAME="homelab"
    HOMELAB_DIR="$HOME/$HOMELAB_NAME"
fi

PLAYBOOKS_DIR="$HOMELAB_DIR/playbooks"
MANIFESTS_DIR="$HOMELAB_DIR/manifests"
KUBECONFIG=~/.kube/config

# Kleuren
ROOD='\033[0;31m'
GEEL='\033[1;33m'
BLAUW='\033[0;34m'
RESET='\033[0m'

echo "=============================================="
echo "  HOMELAB DESTROYER - PROJECT: $HOMELAB_NAME"
echo "=============================================="
echo -e "${ROOD}WAARSCHUWING: Dit gaat ALLES verwijderen!${RESET}"
read -p "Weet je dit zeker? [j/N]: " bevestig < /dev/tty
if [[ ! "$bevestig" =~ ^[jJ]$ ]]; then
    echo "Afgebroken."
    exit 0
fi

# --- Functie: Azure Destroy ---
destroy_azure() {
    echo -e "\n${ROOD}[STAP] Azure infrastructuur vernietigen...${RESET}"
    if [ -f "$HOMELAB_DIR/setup_env.sh" ]; then
        source "$HOMELAB_DIR/setup_env.sh"
        cd "$HOMELAB_DIR"
        terraform destroy -auto-approve
    else
        echo "   Skip: setup_env.sh niet gevonden, infrastructure mogelijk al weg."
    fi
}

# --- Functie: K3s Apps opruimen ---
destroy_k3s_apps() {
    echo -e "\n${GEEL}[STAP] K3s applicaties verwijderen...${RESET}"
    export KUBECONFIG=$KUBECONFIG
    
    namespaces=("portainer" "monitoring" "homer" "uptime-kuma")
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" &>/dev/null; then
            echo "   Verwijderen namespace: $ns..."
            kubectl delete namespace "$ns" --timeout=60s --ignore-not-found
        fi
    done
}

# --- Functie: Hard Reset ---
hard_reset() {
    echo -e "\n${ROOD}[STAP] HARD RESET: Project volledig wissen...${RESET}"
    
    # 1. K3s deinstalleren
    if [ -f "/usr/local/bin/k3s-uninstall.sh" ]; then
        echo "   K3s Cluster verwijderen..."
        sudo /usr/local/bin/k3s-uninstall.sh
    fi

    # 2. Aliassen verwijderen uit .bashrc
    echo "   Aliassen verwijderen uit .bashrc..."
    sed -i '/# === Homelab Aliases ===/,/EOF/d' ~/.bashrc
    
    # 3. Config en Projectmap verwijderen
    echo "   Configuratie en projectmap verwijderen..."
    rm -f "$CONFIG_FILE"
    
    # Let op: we verwijderen de map waar we nu in staan pas als laatste
    cd ~
    rm -rf "$HOMELAB_DIR"
    
    echo -e "\n${ROOD}Project $HOMELAB_NAME is volledig verwijderd.${RESET}"
    echo "Je kunt nu opnieuw beginnen met de bootstrap installer."
}

# Uitvoering
destroy_k3s_apps
destroy_azure

echo ""
read -p "Wil je ook K3s en de projectmap zelf verwijderen (Hard Reset)? [j/N]: " reset_keuze < /dev/tty
if [[ "$reset_keuze" =~ ^[jJ]$ ]]; then
    hard_reset
else
    echo -e "\n${GEEL}Schoonmaak voltooid. De projectmap is behouden.${RESET}"
fi
