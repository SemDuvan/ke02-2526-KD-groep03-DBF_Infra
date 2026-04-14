#!/bin/bash
# Verwijder oude aliases
sed -i '/alias tf-azure=/d' ~/.bashrc
sed -i '/alias tfazure=/d' ~/.bashrc
sed -i '/alias k3sdeploy=/d' ~/.bashrc
sed -i '/alias azuredeploy=/d' ~/.bashrc

# Voeg nieuwe aliases toe
cat >> ~/.bashrc << 'EOF'

# === Homelab Aliases ===
alias tfazure='cd ~/homelab/azure && source setup_env.sh'
alias tf-azure='cd ~/homelab/azure && source setup_env.sh'
alias k3sdeploy='ansible-playbook ~/homelab/azure/playbook_k3s_homelab.yml'
alias azuredeploy='ansible-playbook ~/homelab/azure/playbook_azure_webservers.yml -i ~/homelab/azure/inventory_azure.yml'
EOF

echo "Aliases succesvol bijgewerkt!"
grep "alias" ~/.bashrc | tail -6
