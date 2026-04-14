#!/bin/bash
# fix_2gb.sh - Fix Cgroups voor K3s op Raspberry Pi (2GB/4GB/8GB modellen)
# Dit script zet de benodigde kernel flags aan die K3s nodig heeft om te kunnen starten.

echo "=============================================="
echo "  Raspberry Pi K3s Cgroup Fixer"
echo "=============================================="

# Bepaal het pad naar de cmdline.txt (verschilt per OS versie)
if [ -f /boot/firmware/cmdline.txt ]; then
    FILE=/boot/firmware/cmdline.txt
elif [ -f /boot/cmdline.txt ]; then
    FILE=/boot/cmdline.txt
else
    echo "Fout: cmdline.txt niet gevonden!"
    exit 1
fi

echo "Controleren van $FILE..."

# Check of de fix al aanwezig is
if grep -q "cgroup_enable=memory" "$FILE"; then
    echo "De Cgroup fix is al aanwezig in $FILE."
    echo "Status: OK"
else
    echo "Fix nog niet aanwezig. Toevoegen..."
    # Maak een backup voor de zekerheid
    sudo cp "$FILE" "${FILE}.bak"
    
    # Voeg de flags toe aan het einde van de eerste regel
    sudo sed -i '$ s/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1/' "$FILE"
    
    echo "Succes! De instellingen zijn toegevoegd aan $FILE."
    echo "=============================================="
    echo "  BELANGRIJK: Start de Pi nu opnieuw op!"
    echo "  Command: sudo reboot"
    echo "=============================================="
fi
