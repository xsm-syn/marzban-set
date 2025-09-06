#!/bin/bash
colorized_echo() {
    local color=$1
    local text=$2
    
    case $color in
        "red")
        printf "\e[91m${text}\e[0m\n";;
        "green")
        printf "\e[92m${text}\e[0m\n";;
        "yellow")
        printf "\e[93m${text}\e[0m\n";;
        "blue")
        printf "\e[94m${text}\e[0m\n";;
        "magenta")
        printf "\e[95m${text}\e[0m\n";;
        "cyan")
        printf "\e[96m${text}\e[0m\n";;
        *)
            echo "${text}"
        ;;
    esac
}

# Check if the script is run as root
if [ "$(id -u)" != "0" ]; then
    colorized_echo red "Error: Skrip ini harus dijalankan sebagai root."
    exit 1
fi

# Check supported operating system
supported_os=false

if [ -f /etc/os-release ]; then
    os_name=$(grep -E '^ID=' /etc/os-release | cut -d= -f2)
    os_version=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

    case "$os_name" in
        debian)
            case "$os_version" in
                9|10|11|12)
                    supported_os=true
                ;;
            esac
        ;;
        ubuntu)
            case "$os_version" in
                18.04|20.04|22.04|24.04)
                    supported_os=true
                ;;
            esac
        ;;
    esac
fi

apt install sudo curl -y
if [ "$supported_os" != true ]; then
    colorized_echo red "Error: Skrip ini hanya support di Debian 9-12 dan Ubuntu 18.04, 20.04, 22.04, 24.04. Mohon gunakan OS yang di support."
    exit 1
fi

# Fungsi untuk menambahkan repo Debian
addDebianRepo() {
    local version=$1
    case "$version" in
        9)
            codename="stretch"
        ;;
        10)
            codename="buster"
        ;;
        11)
            codename="bullseye"
        ;;
        12)
            codename="bookworm"
        ;;
    esac

    echo "#mirror_kambing-sysadmind deb${version}
deb http://kartolo.sby.datautama.net.id/debian ${codename} main contrib non-free
deb http://kartolo.sby.datautama.net.id/debian ${codename}-updates main contrib non-free
deb http://kartolo.sby.datautama.net.id/debian-security ${codename}-security main contrib non-free" | sudo tee /etc/apt/sources.list > /dev/null
}

# Fungsi untuk menambahkan repo Ubuntu
addUbuntuRepo() {
    local version=$1
    case "$version" in
        18.04)
            codename="bionic"
        ;;
        20.04)
            codename="focal"
        ;;
        22.04)
            codename="jammy"
        ;;
        24.04)
            codename="noble"
        ;;
    esac

    echo "#mirror buaya klas ${version}
deb https://buaya.klas.or.id/ubuntu/ ${codename} main restricted universe multiverse
deb https://buaya.klas.or.id/ubuntu/ ${codename}-updates main restricted universe multiverse
deb https://buaya.klas.or.id/ubuntu/ ${codename}-security main restricted universe multiverse
deb https://buaya.klas.or.id/ubuntu/ ${codename}-backports main restricted universe multiverse
deb https://buaya.klas.or.id/ubuntu/ ${codename}-proposed main restricted universe multiverse" | sudo tee /etc/apt/sources.list > /dev/null
}

# Mendapatkan informasi kode negara dan OS
COUNTRY_CODE=$(curl -s https://ipinfo.io/country)
OS=$(lsb_release -si)

# Pemeriksaan IP Indonesia
if [[ "$COUNTRY_CODE" == "ID" ]]; then
    colorized_echo green "IP Indonesia terdeteksi, menggunakan repositories lokal Indonesia"

    # Menanyakan kepada pengguna apakah ingin menggunakan repo lokal atau repo default
    read -p "Apakah Anda ingin menggunakan repo lokal Indonesia? (y/n): " use_local_repo

    if [[ "$use_local_repo" == "y" || "$use_local_repo" == "Y" ]]; then
        # Pemeriksaan OS untuk menambahkan repo yang sesuai
        case "$OS" in
            Debian)
                VERSION=$(lsb_release -sr)
                case "$VERSION" in
                    9|10|11|12)
                        addDebianRepo "$VERSION"
                    ;;
                    *)
                        colorized_echo red "Versi Debian ini tidak didukung."
                    ;;
                esac
                ;;
            Ubuntu)
                VERSION=$(lsb_release -sr)
                case "$VERSION" in
                    18.04|20.04|22.04|24.04)
                        addUbuntuRepo "$VERSION"
                    ;;
                    *)
                        colorized_echo red "Versi Ubuntu ini tidak didukung."
                    ;;
                esac
                ;;
            *)
                colorized_echo red "Sistem Operasi ini tidak didukung."
                ;;
        esac
    else
        colorized_echo yellow "Menggunakan repo bawaan VM."
        # Tidak melakukan apa-apa, sehingga repo bawaan VM tetap digunakan
    fi
else
    colorized_echo yellow "IP di luar Indonesia."
    # Lanjutkan dengan repo bawaan OS
fi

mkdir -p /etc/data

#domain
clear
read -rp "Masukkan Domain: " domain
echo "$domain" > /etc/data/domain
domain=$(cat /etc/data/domain)

#email
#read -rp "Masukkan Email anda: " email

#username
while true; do
    read -rp "Masukkan UsernamePanel (hanya huruf dan angka): " userpanel

    # Memeriksa apakah userpanel hanya mengandung huruf dan angka
    if [[ ! "$userpanel" =~ ^[A-Za-z0-9]+$ ]]; then
        echo "UsernamePanel hanya boleh berisi huruf dan angka. Silakan masukkan kembali."
    elif [[ "$userpanel" =~ [Aa][Dd][Mm][Ii][Nn] ]]; then
        echo "UsernamePanel tidak boleh mengandung kata 'admin'. Silakan masukkan kembali."
    else
        echo "$userpanel" > /etc/data/userpanel
        break
    fi
done

read -rp "Masukkan Password Panel: " passpanel
echo "$passpanel" > /etc/data/passpanel

#Preparation
clear
cd;
apt-get update;

#Remove unused Module
apt-get -y --purge remove samba*;
apt-get -y --purge remove apache2*;
apt-get -y --purge remove sendmail*;
apt-get -y --purge remove bind9*;

#install bbr
echo 'fs.file-max = 500000
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 4096
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mem = 25600 51200 102400
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.rmem_max = 4000000
net.ipv4.tcp_mtu_probing = 1
net.ipv4.ip_forward = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1' >> /etc/sysctl.conf
sysctl -p;

#install toolkit
apt-get install libio-socket-inet6-perl libsocket6-perl libcrypt-ssleay-perl libnet-libidn-perl sqlite3 perl libio-socket-ssl-perl libwww-perl libpcre3 libpcre3-dev zlib1g-dev dbus iftop zip unzip wget net-tools curl nano sed screen gnupg gnupg1 bc apt-transport-https build-essential dirmngr dnsutils sudo at htop iptables bsdmainutils cron lsof lnav -y

#Set Timezone GMT+7
timedatectl set-timezone Asia/Jakarta;

#Install Marzban
sudo bash -c "$(curl -sL https://github.com/xsm-syn/Marzban-scripts/raw/master/marzban.sh)" @ install

#Install Subs
wget -q -N -P /var/lib/marzban/templates/subscription/  https://raw.githubusercontent.com/xsm-syn/marzban-set/main/index.html

#install env
wget -q -O /opt/marzban/.env "https://raw.githubusercontent.com/xsm-syn/marzban-set/main/env"

#install core Xray & Assets folder
mkdir -p /var/lib/marzban/assets
mkdir -p /var/lib/marzban/core
wget -q -O /var/lib/marzban/core/xray.zip "https://github.com/XTLS/Xray-core/releases/download/v1.8.24/Xray-linux-64.zip"  
cd /var/lib/marzban/core && unzip xray.zip && chmod +x xray
cd

#profile
echo -e 'profile' >> /root/.profile
wget -q -O /usr/bin/profile "https://raw.githubusercontent.com/xsm-syn/marzban-set/main/profile";
chmod +x /usr/bin/profile
apt install neofetch -y
wget -q -O /usr/bin/cekservice "https://raw.githubusercontent.com/xsm-syn/marzban-set/main/cekservice.sh"
chmod +x /usr/bin/cekservice

#install compose
wget -q -O /opt/marzban/docker-compose.yml "https://raw.githubusercontent.com/xsm-syn/marzban-set/main/docker-compose.yml"

#Install VNSTAT
apt -y install vnstat
/etc/init.d/vnstat restart
apt -y install libsqlite3-dev
wget -q https://github.com/xsm-syn/marzban-set/raw/main/vnstat-2.6.tar.gz
tar zxvf vnstat-2.6.tar.gz
cd vnstat-2.6
./configure --prefix=/usr --sysconfdir=/etc && make && make install 
cd
chown vnstat:vnstat /var/lib/vnstat -R
systemctl enable vnstat
/etc/init.d/vnstat restart
rm -f /root/vnstat-2.6.tar.gz 
rm -rf /root/vnstat-2.6

#Install Speedtest
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
sudo apt-get install speedtest -y

#install nginx
mkdir -p /var/log/nginx
touch /var/log/nginx/access.log
touch /var/log/nginx/error.log

: << 'EOF'
#apt install nginx -y
#wget -O /etc/nginx/nginx.conf "https://raw.githubusercontent.com/xsm-syn/marzban-set/main/nginx.conf"
#wget -O /etc/nginx/sites-available/default "https://raw.githubusercontent.com/xsm-syn/marzban-set/main/vps.conf"
#wget -O /etc/nginx/conf.d/xray.conf "https://raw.githubusercontent.com/xsm-syn/marzban-set/main/xray.conf"
EOF

wget -q -O /opt/marzban/nginx.conf "https://raw.githubusercontent.com/xsm-syn/marzban-set/main/nginx.conf"
wget -q -O /opt/marzban/default.conf "https://raw.githubusercontent.com/xsm-syn/marzban-set/main/vps.conf"
wget -q -O /opt/marzban/xray.conf "https://raw.githubusercontent.com/xsm-syn/marzban-set/main/xray.conf"
mkdir -p /var/www/html
echo "<pre>Setup by AutoScript @after_sweet</pre>" > /var/www/html/index.html

#install socat
apt install iptables -y
apt install curl socat xz-utils wget apt-transport-https gnupg gnupg2 gnupg1 dnsutils lsb-release -y 
apt install socat cron bash-completion -y

: << 'EOF'
#install cert
#curl https://get.acme.sh | sh -s email=$email
#/root/.acme.sh/acme.sh --server letsencrypt --register-account -m $email --issue -d $domain --standalone -k ec-256 --debug
#~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /var/lib/marzban/xray.crt --keypath /var/lib/marzban/xray.key --ecc
#wget -O /var/lib/marzban/xray_config.json "https://raw.githubusercontent.com/xsm-syn/marzban-set/main/xray_config.json"
EOF

mkdir /root/.acme.sh
curl https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
chmod +x /root/.acme.sh/acme.sh
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
/root/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /var/lib/marzban/xray.crt --keypath /var/lib/marzban/xray.key --ecc
wget -q -O /var/lib/marzban/xray_config.json "https://raw.githubusercontent.com/xsm-syn/marzban-set/main/xray_config.json"
chown www-data:www-data /var/lib/marzban/xray.crt
chown www-data:www-data /var/lib/marzban/xray.key

#install firewall
apt install ufw -y
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw allow 8081/tcp
sudo ufw allow 1080/tcp
sudo ufw allow 1080/udp

#install database
wget -q -O /var/lib/marzban/db.sqlite3 "https://github.com/xsm-syn/marzban-set/raw/main/db.sqlite3"

#install WARP Proxy
wget -q -O /root/warp "https://raw.githubusercontent.com/hamid-gh98/x-ui-scripts/main/install_warp_proxy.sh"
sudo chmod +x /root/warp
sudo bash /root/warp -y 

#finishing
apt autoremove -y
apt clean
cd /opt/marzban
sed -i "s/# SUDO_USERNAME = \"admin\"/SUDO_USERNAME = \"${userpanel}\"/" /opt/marzban/.env
sed -i "s/# SUDO_PASSWORD = \"admin\"/SUDO_PASSWORD = \"${passpanel}\"/" /opt/marzban/.env
docker compose down && docker compose up -d
#marzban cli admin import-from-env -y

cd && clear
echo "Tunggu 15 detik untuk generate token API"
sleep 15s

#instal token
curl -X 'POST' \
  "https://${domain}/api/admin/token" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=password&username=${userpanel}&password=${passpanel}&scope=&client_id=&client_secret=" > /etc/data/token.json
cd

# restart all service
systemctl enable ufw
systemctl restart ufw
sleep 2

sqlite3 "/var/lib/marzban/db.sqlite3" <<EOF
UPDATE hosts
SET address = '$domain',
    host = '$domain',
    sni = CASE WHEN security = 'tls' THEN '$domain' ELSE sni END
WHERE id BETWEEN 20 AND 34;
EOF


# latest install
touch /root/log-install.txt
profile
echo "Untuk data login dashboard Marzban: " | tee -a /root/log-install.txt
echo "-=================================-" | tee -a /root/log-install.txt
echo "URL HTTPS : https://${domain}/dashboard" | tee -a /root/log-install.txt
echo "username  : ${userpanel}" | tee -a /root/log-install.txt
echo "password  : ${passpanel}" | tee -a /root/log-install.txt
echo "-=================================-" | tee -a /root/log-install.txt
echo "Telegram : https://t.me/after_sweet" | tee -a /root/log-install.txt
echo "-=================================-" | tee -a /root/log-install.txt
colorized_echo green "Script telah berhasil di install"

marzban cli admin delete -u admin -y

echo -e "[\e[1;31mWARNING\e[0m] Silahkan reboot server [default y](y/n)? "
read answer
if [ "$answer" == "${answer#[Yy]}" ] ;then
exit 0
else
cat /dev/null > ~/.bash_history && history -c && reboot
fi