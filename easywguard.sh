#!/bin/bash

# Cesty a výchozí hodnoty
SERVER_CONF="wg0.conf"
PUB_KEY_FILE="serverpub.key"
DEF_IP="192.168.0.1"
DEF_PORT="3030"
DEF_NET="10.10"

dialog --title "WireGuard - Install script by OK4MD" --yesno "Konfigurovat SERVER? (Ne = KLIENT)" 10 60
if [ $? -eq 0 ]; then
    # --- SERVER ---
    S_IP=$(dialog --inputbox "Veřejná IP serveru:" 8 60 "$DEF_IP" 3>&1 1>&2 2>&3)
    S_PORT=$(dialog --inputbox "Port:" 8 60 "$DEF_PORT" 3>&1 1>&2 2>&3)
    S_NET=$(dialog --inputbox "Síť (např. 10.10):" 8 60 "$DEF_NET" 3>&1 1>&2 2>&3)

    SRV_PRIVATE=$(wg genkey)
    SRV_PUBLIC=$(echo "$SRV_PRIVATE" | wg pubkey)
    echo "$SRV_PUBLIC" > "$PUB_KEY_FILE"

    cat <<EOF > "$SERVER_CONF"
[Interface]
Address = ${S_NET}.0.1/16
ListenPort = $S_PORT
PrivateKey = $SRV_PRIVATE
#SaveConfig = true
# PublicIP: $S_IP
EOF
    dialog --msgbox "Server hotov. Veřejný klíč uložen do $PUB_KEY_FILE" 10 60
else
    # --- KLIENT ---
    # 1. Načtení VEŘEJNÉHO klíče serveru
    if [ -f "$PUB_KEY_FILE" ]; then
        SERVER_PUB=$(cat "$PUB_KEY_FILE")
    else
        SERVER_PUB=$(dialog --inputbox "Vložte VEŘEJNÝ klíč serveru:" 8 60 3>&1 1>&2 2>&3)
    fi

    # 2. Načtení parametrů ze serveru
    if [ -f "$SERVER_CONF" ]; then
        S_IP=$(grep "PublicIP" "$SERVER_CONF" | awk '{print $NF}')
        S_PORT=$(grep "ListenPort" "$SERVER_CONF" | awk '{print $NF}')
        S_NET=$(grep "Address" "$SERVER_CONF" | awk '{print $NF}' | cut -d. -f1,2)
    fi
    : ${S_IP:=$DEF_IP}; : ${S_PORT:=$DEF_PORT}; : ${S_NET:=$DEF_NET}

    # 3. GENERACE KLÍČŮ KLIENTA
    CLIENT_PRIVATE=$(wg genkey)
    CLIENT_PUBLIC=$(echo "$CLIENT_PRIVATE" | wg pubkey)
    
    C_IP=$(dialog --inputbox "IP klienta:" 8 60 "${S_NET}.0.10" 3>&1 1>&2 2>&3)

    # 4. ZÁPIS KONFIGURACE KLIENTA (Zde MUSÍ být CLIENT_PRIVATE)
    cat <<EOF > wg0_client.conf
[Interface]
PrivateKey = $CLIENT_PRIVATE
Address = $C_IP/16
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUB
Endpoint = $S_IP:$S_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

    # 5. ZÁPIS NA SERVER (Zde MUSÍ být CLIENT_PUBLIC)
    if [ -f "$SERVER_CONF" ]; then
        echo -e "\n[Peer]\n# Klient $C_IP\nPublicKey = $CLIENT_PUBLIC\nAllowedIPs = $C_IP/32" >> "$SERVER_CONF"
    fi

    clear
    echo "========= KONTROLA KLÍČŮ (NESMÍ BÝT STEJNÉ) ========="
    echo "1. Soukromý klíč klienta (v souboru): $CLIENT_PRIVATE"
    echo "2. Veřejný klíč klienta (na serveru): $CLIENT_PUBLIC"
    echo "3. Veřejný klíč serveru (v peerech):  $SERVER_PUB"
    echo "====================================================="
    qrencode -t ansiutf8 < wg0_client.conf
    read -p "Nyní jsou klíče správně odděleny. Pokračujte Enterem..."
fi
clear
