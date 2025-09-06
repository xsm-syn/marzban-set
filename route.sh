#!/bin/bash

# Cek apakah skrip dijalankan dengan sudo
if [ "$EUID" -ne 0 ]; then
    echo "Harap jalankan skrip ini sebagai root (gunakan sudo)."
    exit 1
fi

# Pastikan argumen benar
if [ "$#" -ne 2 ]; then
    echo "Penggunaan: $0 <domain> <ip_server_tujuan>"
    echo "Contoh: $0 m.youtube.com 203.0.113.10"
    exit 1
fi

DOMAIN="$1"
SERVER_TUJUAN="$2"

# Pastikan tabel routing ISP belum ada, jika belum tambahkan
if ! grep -q "200 ispB" /etc/iproute2/rt_tables; then
    echo "200 ispB" >> /etc/iproute2/rt_tables
fi

# Resolusi domain ke IP
IP_LIST=$(nslookup "$DOMAIN" | awk '/^Address: / { print $2 }' | tail -n +2)

if [ -z "$IP_LIST" ]; then
    echo "Gagal mendapatkan IP dari $DOMAIN."
    exit 1
fi

echo "Domain $DOMAIN memiliki IP berikut:"
echo "$IP_LIST"

# Tambahkan routing
echo "Menambahkan routing ke $SERVER_TUJUAN..."
ip route add default via "$SERVER_TUJUAN" table ispB

# Tambahkan aturan untuk setiap IP
for IP in $IP_LIST; do
    echo "Menambahkan aturan routing untuk $IP..."
    ip rule add to "$IP" lookup ispB
done

echo "Routing selesai! Semua koneksi ke $DOMAIN akan melewati $SERVER_TUJUAN."
