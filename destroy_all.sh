#!/bin/bash
# ============================================================
# destroy_all.sh
# Doel: Azure infrastructuur en/of K3s apps selectief verwijderen
# ============================================================

AZURE_DIR=~/homelab/azure
MANIFEST_DIR=~/homelab/manifests

# Kleuren voor output
ROOD='\033[0;31m'
GEEL='\033[1;33m'
RESET='\033[0m'

echo "================================================"
echo "Homelab Destroy Pipeline"
echo "================================================"
echo "Kies wat je wilt verwijderen:"
echo "  1) Alleen K3s apps (Homer, Portainer, etc.)"
echo "  2) Alleen Azure infrastructuur (VMs, Netwerk)"
echo "  3) ALLES verwijderen (Azure + K3s)"
echo ""
read -p "Keuze (1/2/3): " keuze

# --- Functie: Azure Destroy ---
destroy_azure() {
    echo ""
    echo "${ROOD}STAP 1: Azure infrastructuur vernietigen...${RESET}"
    if [ -f "$AZURE_DIR/setup_env.sh" ]; then
        source "$AZURE_DIR/setup_env.sh"
        cd "$AZURE_DIR"
        terraform destroy -auto-approve
    else
        echo "Fout: $AZURE_DIR/setup_env.sh niet gevonden."
        exit 1
    fi
}

# --- Functie: K3s Destroy ---
destroy_k3s() {
    echo ""
    echo "${GEEL}STAP 2: K3s applicaties verwijderen...${RESET}"
    export KUBECONFIG=~/.kube/config
    # Forceer gebruik van de juiste K3s kubectl om 'Exec format error' te voorkomen
    KUBECTL=/usr/local/bin/kubectl
    
    # Namespaces verwijderen
    namespaces=("portainer" "monitoring" "homer")
    for ns in "${namespaces[@]}"; do
        if $KUBECTL get namespace "$ns" &>/dev/null; then
            echo "   Verwijderen namespace: $ns..."
            $KUBECTL delete namespace "$ns" --timeout=60s
        else
            echo "   Namespace $ns bestaat niet, overslaan."
        fi
    done

    # Losse manifests verwijderen
    if [ -d "$MANIFEST_DIR" ]; then
        echo "   STAP 3: Losse manifests verwijderen..."
        $KUBECTL delete -f "$MANIFEST_DIR/uptime-kuma.yml" --ignore-not-found
    fi
}

# --- Hoofdlogica ---
case $keuze in
    1)
        destroy_k3s
        ;;
    2)
        destroy_azure
        ;;
    3)
        destroy_k3s
        destroy_azure
        ;;
    *)
        echo "Ongeldige keuze. Script afgebroken."
        exit 1
        ;;
esac

echo ""
echo "================================================"
echo "Vernietiging voltooid!"
echo "================================================"
