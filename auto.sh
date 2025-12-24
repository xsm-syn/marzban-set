#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RED="\033[1;31m"
BLUE="\033[1;34m"
RESET="\033[0m"
BOLD="\033[1m"
GRAY="\033[1;30m"

# Fungsi Spinner
show_spinner() {
  local pid=$1
  local delay=0.1
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local n=0
  while [ "$(ps -p $pid -o pid=)" ]; do
    local i=$(( (n++) % 10 ))
    printf "\r${GRAY}•${RESET} %s... ${CYAN}%s${RESET}" "$msg" "${spin:$i:1}"
    sleep $delay
  done
}

print_done() {
  echo -e "\r${GREEN}✓${RESET} $1      "
}

print_fail() {
  echo -e "\r${RED}✗${RESET} $1      "
  echo -e "${GRAY}Last log entry:${RESET}"
  tail -n 5 /tmp/install.log
  exit 1
}

run_silent() {
  local msg="$1"
  local cmd="$2" 
  bash -c "$cmd" > /tmp/install.log 2>&1 &
  local pid=$!
  show_spinner $pid
  wait $pid
  local res=$?

  if [ $res -eq 0 ]; then
    print_done "$msg"
  else
    print_fail "$msg (Cek /tmp/install.log)"
  fi
}

rm -f /tmp/install.log

clear
echo -e "${BOLD}Starting Marzban Auto-Installer...${RESET}"

if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}Error: Skrip ini harus dijalankan sebagai root.${RESET}"
    exit 1
fi

supported_os=false
if [ -f /etc/os-release ]; then
    os_name=$(grep -E '^ID=' /etc/os-release | cut -d= -f2)
    os_version=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    case "$os_name" in
        debian)
            case "$os_version" in
                9|10|11|12) supported_os=true ;;
            esac
            ;;
        ubuntu)
            case "$os_version" in
                18.04|20.04|22.04|24.04) supported_os=true ;;
            esac
            ;;
    esac
fi

if [ "$supported_os" != true ]; then
    echo -e "${RED}Error: OS tidak didukung. Gunakan Debian 9-12 atau Ubuntu 18/20/22/24.${RESET}"
    exit 1
fi

#mkdir /etc/data
read -rp "Masukkan Domain: " domain
#echo "$domain" > /etc/data/domain

while true; do
    read -rp "Masukkan UsernamePanel (hanya huruf dan angka): " userpanel
    if [[ ! "$userpanel" =~ ^[A-Za-z0-9]+$ ]]; then
        echo -e "${YELLOW}Username hanya boleh huruf dan angka.${RESET}"
    elif [[ "$userpanel" =~ [Aa][Dd][Mm][Ii][Nn] ]]; then
        echo -e "${YELLOW}Username tidak boleh mengandung kata 'admin'.${RESET}"
    else
        break
    fi
done

read -rp "Masukkan Password Panel: " passpanel

mkdir -p /etc/data
echo "$domain" > /etc/data/domain
echo "$userpanel" > /etc/data/userpanel
echo "$passpanel" > /etc/data/passpanel

echo ""

step_prep_system() {
    apt-get -y --purge remove samba* apache2* sendmail* bind9* >/dev/null 2>&1
    echo 'DPkg::options { "--force-confdef"; "--force-confold"; };' > /etc/apt/apt.conf.d/99force
    mkdir -p /etc/needrestart/conf.d
    echo '$nrconf{restart} = "a";' > /etc/needrestart/conf.d/99-autorestart.conf
    apt-get update
}

step_sysctl_optim() {
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
    sysctl -p
}

step_install_dependencies() {
    apt-get install sudo curl -y
    apt-get install libio-socket-inet6-perl libsocket6-perl libcrypt-ssleay-perl libnet-libidn-perl sqlite3 perl libio-socket-ssl-perl libwww-perl libpcre3 libpcre3-dev zlib1g-dev dbus iftop zip unzip wget net-tools curl nano sed screen gnupg gnupg1 bc apt-transport-https build-essential dirmngr dnsutils sudo at htop iptables bsdmainutils cron lsof lnav -y
    apt-get install neofetch -y
    apt-get install iptables curl socat xz-utils wget apt-transport-https gnupg gnupg2 gnupg1 dnsutils lsb-release socat cron bash-completion -y
    timedatectl set-timezone Asia/Jakarta
}

step_install_marzban_core() {
    sudo bash -c "$(curl -sL https://github.com/xsm-syn/Marzban-scripts/raw/master/marzban.sh)" @ install

    mkdir -p /var/lib/marzban/templates/subscription/
    wget -q -N -P /var/lib/marzban/templates/subscription/ https://raw.githubusercontent.com/xsm-syn/marzban-set/main/index.html
    wget -q -O /opt/marzban/.env "https://raw.githubusercontent.com/xsm-syn/marzban-set/main/env"
    
    mkdir -p /var/lib/marzban/assets
    mkdir -p /var/lib/marzban/core
    wget -q -O /var/lib/marzban/core/xray.zip "https://github.com/XTLS/Xray-core/releases/download/v1.8.24/Xray-linux-64.zip"
    cd /var/lib/marzban/core && unzip -o xray.zip && chmod +x xray

    echo -e 'profile' >> /root/.profile
    wget -q -O /usr/bin/profile "https://raw.githubusercontent.com/xsm-syn/marzban-set/main/profile"
    chmod +x /usr/bin/profile
    wget -q -O /usr/bin/cekservice "https://raw.githubusercontent.com/xsm-syn/marzban-set/main/cekservice.sh"
    chmod +x /usr/bin/cekservice
    wget -q -O /opt/marzban/docker-compose.yml "https://raw.githubusercontent.com/xsm-syn/marzban-set/main/docker-compose.yml"
}

step_install_vnstat() {
    apt-get install vnstat -y
    /etc/init.d/vnstat restart
    apt-get install libsqlite3-dev -y
    
    cd /root
    wget -q https://github.com/xsm-syn/marzban-set/raw/main/vnstat-2.6.tar.gz
    tar zxf vnstat-2.6.tar.gz
    cd vnstat-2.6
    ./configure --prefix=/usr --sysconfdir=/etc && make && make install
    cd /root
    chown vnstat:vnstat /var/lib/vnstat -R
    systemctl enable vnstat
    /etc/init.d/vnstat restart
    rm -f /root/vnstat-2.6.tar.gz
    rm -rf /root/vnstat-2.6
}

step_install_speedtest() {
    curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
    sudo apt-get install speedtest -y
}

step_setup_nginx() {
    mkdir -p /var/log/nginx
    touch /var/log/nginx/access.log
    touch /var/log/nginx/error.log
    
    wget -q -O /opt/marzban/nginx.conf "https://raw.githubusercontent.com/xsm-syn/marzban-set/main/nginx.conf"
    wget -q -O /opt/marzban/default.conf "https://raw.githubusercontent.com/xsm-syn/marzban-set/main/vps.conf"
    wget -q -O /opt/marzban/xray.conf "https://raw.githubusercontent.com/xsm-syn/marzban-set/main/xray.conf"
    mkdir -p /var/www/html
    echo "<pre>Setup by AutoScript @after_sweet</pre>" > /var/www/html/index.html
}

step_ssl_acme() {
    local DOMAIN=$(cat /etc/data/domain)
    
    mkdir -p /root/.acme.sh
    curl -s https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
    chmod +x /root/.acme.sh/acme.sh
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    /root/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone -k ec-256 --force
    /root/.acme.sh/acme.sh --installcert -d "$DOMAIN" --fullchainpath /var/lib/marzban/xray.crt --keypath /var/lib/marzban/xray.key --ecc
    
    wget -q -O /var/lib/marzban/xray_config.json "https://raw.githubusercontent.com/xsm-syn/marzban-set/main/xray_config.json"
    chown www-data:www-data /var/lib/marzban/xray.crt
    chown www-data:www-data /var/lib/marzban/xray.key
}

step_firewall_warp() {
    apt-get install ufw -y
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow http
    sudo ufw allow https
    sudo ufw allow 8081/tcp
    sudo ufw allow 1080/tcp
    sudo ufw allow 1080/udp
    yes | sudo ufw enable
    
    wget -q -O /var/lib/marzban/db.sqlite3 "https://github.com/xsm-syn/marzban-set/raw/main/db.sqlite3"
    
    wget -q -O /root/warp "https://raw.githubusercontent.com/hamid-gh98/x-ui-scripts/main/install_warp_proxy.sh"
    sudo chmod +x /root/warp
    sudo bash /root/warp -y
}

download_menu() {
    echo -e "\n${C_CYAN}Mengunduh semua menu...${C_RESET}"

    GITHUB_RAW="https://raw.githubusercontent.com/xsm-syn/marzban-set/main/SC-MARZBAN"
    BIN_PATH="/usr/bin"

    menus=(
        addtr
        addtrgrpc
        addtrhu
        addtrws
        addvl
        addvlgrpc
        addvlhu
        addvlws
        addvm
        addvmgrpc
        addvmhu
        addvmws
        cek
        delete
        user
    )

    for file in "${menus[@]}"; do
        execute "Download $file" \
        "wget -q -O ${BIN_PATH}/${file} ${GITHUB_RAW}/${file} && chmod +x ${BIN_PATH}/${file}"
    done
}

step_finalize() {
    local USER=$(cat /etc/data/userpanel)
    local PASS=$(cat /etc/data/passpanel)
    local DOM=$(cat /etc/data/domain)
    
    apt-get autoremove -y
    apt-get clean
    
    cd /opt/marzban
    sed -i "s/# SUDO_USERNAME = \"admin\"/SUDO_USERNAME = \"${USER}\"/" /opt/marzban/.env
    sed -i "s/# SUDO_PASSWORD = \"admin\"/SUDO_PASSWORD = \"${PASS}\"/" /opt/marzban/.env
    docker compose down && docker compose up -d
    sleep 15

    curl -s -X 'POST' \
      "https://${DOM}/api/admin/token" \
      -H 'accept: application/json' \
      -H 'Content-Type: application/x-www-form-urlencoded' \
      -d "grant_type=password&username=${USER}&password=${PASS}&scope=&client_id=&client_secret=" > /etc/data/token.json

    sqlite3 "/var/lib/marzban/db.sqlite3" <<EOF
UPDATE hosts
SET address = '$DOM',
    host = '$DOM',
    sni = CASE WHEN security = 'tls' THEN '$DOM' ELSE sni END
WHERE id BETWEEN 20 AND 34;
EOF

    marzban cli admin delete -u admin -y
}

export -f step_prep_system step_sysctl_optim step_install_dependencies step_install_marzban_core
export -f step_install_vnstat step_install_speedtest step_setup_nginx step_ssl_acme step_firewall_warp download_menu step_finalize

run_silent "Preparing System" "step_prep_system"
run_silent "Optimizing Kernel (Sysctl)" "step_sysctl_optim"
run_silent "Installing Dependencies" "step_install_dependencies"
run_silent "Installing Marzban Core & Assets" "step_install_marzban_core"
run_silent "Compiling & Installing Vnstat 2.6" "step_install_vnstat"
run_silent "Installing Speedtest CLI" "step_install_speedtest"
run_silent "Configuring Nginx" "step_setup_nginx"
run_silent "Requesting SSL Certificate" "step_ssl_acme"
run_silent "Setting up Firewall & Warp" "step_firewall_warp"
runfsilent "Installing Menu" "download_menu"
run_silent "Finalizing Installation & Starting Docker" "step_finalize"

clear

domain=$(cat /etc/data/domain)
userpanel=$(cat /etc/data/userpanel)
passpanel=$(cat /etc/data/passpanel)

touch /root/log-install.txt
echo "Untuk data login dashboard Marzban: " | tee -a /root/log-install.txt
echo "-=================================-" | tee -a /root/log-install.txt
echo "URL HTTPS : https://${domain}/dashboard" | tee -a /root/log-install.txt
echo "username  : ${userpanel}" | tee -a /root/log-install.txt
echo "password  : ${passpanel}" | tee -a /root/log-install.txt
echo "-=================================-" | tee -a /root/log-install.txt
echo "Telegram : https://t.me/after_sweet" | tee -a /root/log-install.txt
echo "-=================================-" | tee -a /root/log-install.txt

echo -e "${GREEN}Script telah berhasil di install${RESET}"

echo -e "[\e[1;31mWARNING\e[0m] Silahkan reboot server [default y](y/n)? "
read answer
if [ "$answer" == "${answer#[Yy]}" ] ;then
    exit 0
else
    cat /dev/null > ~/.bash_history && history -c && reboot
fi
