# Marzban Modified

Ini adalah [Marzban](https://github.com/Gozargah/Marzban) yang sudah saya tambahkan nginx untuk konfigurasi koneksi WebSocket, HTTP Upgrade dan gRPC single port. </br>
WebSocket sudah support untuk 443 TLS, 80 HTTP dan Wildcard path, contoh /enter-your-custom-path/trojan </br>
gRPC sudah support untuk 443 TLS </br>

Disclaimer: Proyek ini hanya untuk pembelajaran dan komunikasi pribadi, mohon jangan menggunakannya untuk tujuan ilegal. </br>
Credit aplikasi full to [Gozargah Marzban](https://github.com/Gozargah), saya hanya edit sedikit untuk instalasi sederhana bagi pemula . </br>

# Special Thanks to
- [Gozargah](https://github.com/Gozargah/Marzban)
- [hamid-gh98](https://github.com/hamid-gh98)
- [x0sina](https://github.com/x0sina/marzban-sub)

# List Protocol yang support
- VLess
- VMess
- Trojan

# Yang harus dipersiapkan
- VPS dengan minimal spek 1 Core 1 GB ram
- Domain yang sudah di pointing ke CloudFlare
- Pemahaman dasar perintah Linux

# Sistem VM yang dapat digunakan
- Debian 11 </br>
- Debian 12 </br>
- Ubuntu 20.04 </br>
- Ubuntu 22.04 </br>
- Ubuntu 24.04 </br>

# Re-Install VPS debian 11
 ```html
 curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh debian 11 && reboot
 ```

# Re-Install VPS Ubuntu 20.04
 ```html
 curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh Ubuntu 20.04 && reboot
 ```
 
# Instalasi Marzban AIO
 ```html
 apt-get update && apt-get upgrade -y && apt dist-upgrade -y && update-grub && wget https://raw.githubusercontent.com/xsm-syn/marzban-set/main/install.sh && chmod +x install.sh && ./install.sh
 ```

Buka panel Marzban dengan mengunjungi https://domain.com/dashboard <br>

Jika ingin mengubah konfigurasi env variable 
```html
nano /opt/marzban/.env
 ```
Perintah Restart service Marzban 
```html
marzban restart
 ```
Perintah Cek Logs service Marzban 
```html
marzban logs
 ```
Perintah Cek update service Marzban
```html
marzban update
 ```