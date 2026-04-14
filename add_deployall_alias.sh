#!/bin/bash
# Verwijder oude alias als die er al in staat
sed -i '/alias deployall=/d' ~/.bashrc

# Voeg nieuwe alias toe
cat >> ~/.bashrc << 'EOF'
alias deployall='bash ~/homelab/azure/deploy_all.sh'
EOF

echo "Alias deployall toegevoegd!"
