#!/bin/bash

# Cek apakah skrip dijalankan dengan sudo
if [ "$EUID" -ne 0 ]; then
    echo "Harap jalankan skrip ini sebagai root (gunakan sudo)."
    exit 1
fi

# Tentukan interface yang digunakan untuk keluar ke internet
INTERFACE=$(ip route | grep default | awk '{print $5}')

if [ -z "$INTERFACE" ]; then
    echo "Gagal mendeteksi interface jaringan. Pastikan server memiliki koneksi internet."
    exit 1
fi

echo "Menggunakan interface: $INTERFACE"

# Aktifkan NAT
echo "Mengaktifkan IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward

# Konfigurasi iptables untuk NAT
echo "Menyiapkan iptables untuk NAT..."
iptables -t nat -A POSTROUTING -o "$INTERFACE" -j MASQUERADE

echo "Konfigurasi selesai! Server ini sekarang bisa meneruskan koneksi dari server lain."
