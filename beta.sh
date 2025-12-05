#!/bin/bash

# =================================================================================
#
#   Skrip Instalasi Marzban Profesional (Clean Output Edition)
#   Deskripsi: Mengotomatiskan instalasi Marzban dengan output terminal yang rapi.
#              Semua detail proses dialihkan ke file log.
#   Author: @after_sweet
#   Versi: 3.0 (Clean Output)
#
# =================================================================================

# Hentikan skrip jika terjadi error

# --- Definisi Variabel Global & Konstanta ---
readonly C_RESET='\e[0m'
readonly C_RED='\e[91m'
readonly C_GREEN='\e[92m'
readonly C_YELLOW='\e[93m'
readonly C_BLUE='\e[94m'
readonly C_CYAN='\e[96m'

readonly LOG_FILE="/root/marzban-install.log"
readonly DATA_DIR="/etc/data"
readonly STATUS_COL=$(($(tput cols) - 10)) # Kolom untuk status [ OK ] / [ FAIL ]

# --- Fungsi Bantuan (Helpers) ---

# Mengosongkan file log di awal
> "$LOG_FILE"

# Fungsi untuk mencetak teks berwarna
colorized_echo() {
    local color=$1
    local text=$2
    printf "${color}%s${C_RESET}\n" "${text}"
}

# Fungsi inti untuk menjalankan perintah dengan output yang rapi
execute() {
    local description="$1"
    local command="$2"
    
    # Cetak deskripsi, pad dengan titik-titik
    printf "  %-*s" $((STATUS_COL - 5)) "${description}..."
    
    # Jalankan perintah dan redirect semua output ke log file
    echo -e "\n# $(date '+%Y-%m-%d %H:%M:%S') - EXECUTING: ${description}\n" >> "$LOG_FILE"
    eval "${command}" >> "$LOG_FILE" 2>&1
    
    # Periksa exit code dari perintah terakhir
    if [ $? -eq 0 ]; then
        printf "${C_GREEN}%s${C_RESET}\n" "[  OK  ]"
    else
        printf "${C_RED}%s${C_RESET}\n" "[ FAIL ]"
        colorized_echo "${C_RED}" "\n  Terjadi kesalahan. Silakan periksa log di: ${LOG_FILE}"
        exit 1
    fi
}

print_header() {
    colorized_echo "${C_BLUE}" "+----------------------------------------------------------+"
    colorized_echo "${C_BLUE}" "|                                                          |"
    colorized_echo "${C_BLUE}" "|           Selamat Datang di Skrip Instalasi Marzban          |"
    colorized_echo "${C_BLUE}" "|                   by @after_sweet                          |"
    colorized_echo "${C_BLUE}" "|                                                          |"
    colorized_echo "${C_BLUE}" "+----------------------------------------------------------+"
    echo
}


# --- Modul Pra-Instalasi ---

check_prerequisites() {
    echo -e "${C_CYAN}Memeriksa prasyarat sistem...${C_RESET}"

    # 1. Periksa hak akses root
    if [ "$(id -u)" != "0" ]; then
        printf "  %-*s${C_RED}%s${C_RESET}\n" $((STATUS_COL - 5)) "Memeriksa hak akses root..." "[ FAIL ]"
        colorized_echo "${C_RED}" "  Skrip ini harus dijalankan sebagai root. Keluar."
        exit 1
    fi
    printf "  %-*s${C_GREEN}%s${C_RESET}\n" $((STATUS_COL - 5)) "Memeriksa hak akses root..." "[  OK  ]"

    # 2. Periksa sistem operasi yang didukung
    if [ -f /etc/os-release ]; then
        local os_name=$(grep -E '^ID=' /etc/os-release | cut -d= -f2)
        local os_version=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
        local supported_os=false

        case "$os_name" in
            debian)
                case "$os_version" in
                    9|10|11|12) supported_os=true ;;
                esac
            ;;
            ubuntu)
                case "$os_version" in
                    18.04|20.04|22.04) supported_os=true ;;
                esac
            ;;
        esac

        if [ "$supported_os" != true ]; then
            printf "  %-*s${C_RED}%s${C_RESET}\n" $((STATUS_COL - 5)) "Memeriksa OS yang didukung..." "[ FAIL ]"
            colorized_echo "${C_RED}" "  OS tidak didukung. Skrip ini hanya untuk Debian 9-12 dan Ubuntu 18.04-22.04."
            exit 1
        fi
        printf "  %-*s${C_GREEN}%s${C_RESET}\n" $((STATUS_COL - 5)) "Memeriksa OS (${os_name} ${os_version})..." "[  OK  ]"
    else
        printf "  %-*s${C_RED}%s${C_RESET}\n" $((STATUS_COL - 5)) "Memeriksa OS yang didukung..." "[ FAIL ]"
        colorized_echo "${C_RED}" "  Tidak dapat mendeteksi sistem operasi. Keluar."
        exit 1
    fi
    
    execute "Instalasi paket dasar (sudo, curl)" "apt-get update -y && apt-get install -y sudo curl lsb-release"
}

configure_repositories() {
    echo -e "\n${C_CYAN}Mengonfigurasi repositori APT...${C_RESET}"
    if [[ "$(curl -s https://ipinfo.io/country)" == "ID" ]]; then
        read -p "  IP Indonesia terdeteksi. Gunakan repo lokal? (y/n): " use_local_repo
        if [[ "$use_local_repo" =~ ^[Yy]$ ]]; then
            local os=$(lsb_release -si)
            local version=$(lsb_release -sr)
            local repo_content=""
            case "$os" in
                Debian)
                    local codename
                    case "$version" in
                        9) codename="stretch" ;; 10) codename="buster" ;; 11) codename="bullseye" ;; 12) codename="bookworm" ;;
                    esac
                    repo_content="#mirror_kambing-sysadmind deb${version}\ndeb http://kartolo.sby.datautama.net.id/debian ${codename} main contrib non-free\ndeb http://kartolo.sby.datautama.net.id/debian ${codename}-updates main contrib non-free\ndeb http://kartolo.sby.datautama.net.id/debian-security ${codename}-security main contrib non-free"
                    ;;
                Ubuntu)
                    local codename
                    case "$version" in
                        18.04) codename="bionic" ;; 20.04) codename="focal" ;; 22.04) codename="jammy" ;; 24.04) codename="noble" ;;
                    esac
                    repo_content="#mirror buaya klas ${version}\ndeb https://buaya.klas.or.id/ubuntu/ ${codename} main restricted universe multiverse\ndeb https://buaya.klas.or.id/ubuntu/ ${codename}-updates main restricted universe multiverse\ndeb https://buaya.klas.or.id/ubuntu/ ${codename}-security main restricted universe multiverse\ndeb https://buaya.klas.or.id/ubuntu/ ${codename}-backports main restricted universe multiverse\ndeb https://buaya.klas.or.id/ubuntu/ ${codename}-proposed main restricted universe multiverse"
                    ;;
            esac
            execute "Mengganti ke repositori lokal Indonesia" "echo -e '${repo_content}' > /etc/apt/sources.list"
        else
            colorized_echo "${C_YELLOW}" "  Menggunakan repositori default sistem."
        fi
    else
        colorized_echo "${C_YELLOW}" "  IP di luar Indonesia, menggunakan repositori default sistem."
    fi
}

get_user_input() {
    echo -e "\n${C_CYAN}Meminta input dari pengguna...${C_RESET}"
    mkdir -p "$DATA_DIR"

    read -rp "  Masukkan Domain: " domain
    echo "$domain" > "${DATA_DIR}/domain"

    while true; do
        read -rp "  Masukkan Username Panel (hanya huruf dan angka): " userpanel
        if [[ "$userpanel" =~ ^[A-Za-z0-9]+$ && ! "$userpanel" =~ [Aa][Dd][Mm][Ii][Nn] ]]; then
            echo "$userpanel" > "${DATA_DIR}/userpanel"
            break
        else
            colorized_echo "${C_RED}" "    Username tidak valid. Coba lagi."
        fi
    done

    read -rp "  Masukkan Password Panel: " passpanel
    echo "$passpanel" > "${DATA_DIR}/passpanel"
    printf "  %-*s${C_GREEN}%s${C_RESET}\n" $((STATUS_COL - 5)) "Menyimpan input pengguna..." "[  OK  ]"
}

# --- Modul Instalasi & Konfigurasi ---

prepare_system() {
    echo -e "\n${C_CYAN}Mempersiapkan sistem dasar...${C_RESET}"
    cd
    execute "Memperbarui daftar paket" "apt-get update"
    execute "Menghapus paket yang tidak diperlukan" "apt-get -y --purge remove samba\* apache2\* sendmail\* bind9\*"
    
    local sysctl_conf='fs.file-max = 500000\nnet.core.rmem_max = 67108864\nnet.core.wmem_max = 67108864\nnet.core.netdev_max_backlog = 250000\nnet.core.somaxconn = 4096\nnet.ipv4.tcp_syncookies = 1\nnet.ipv4.tcp_tw_reuse = 1\nnet.ipv4.tcp_fin_timeout = 30\nnet.ipv4.tcp_keepalive_time = 1200\nnet.ipv4.ip_local_port_range = 10000 65000\nnet.ipv4.tcp_max_syn_backlog = 8192\nnet.ipv4.tcp_max_tw_buckets = 5000\nnet.ipv4.tcp_fastopen = 3\nnet.ipv4.tcp_mem = 25600 51200 102400\nnet.ipv4.tcp_rmem = 4096 87380 67108864\nnet.ipv4.tcp_wmem = 4096 65536 67108864\nnet.core.rmem_max = 4000000\nnet.ipv4.tcp_mtu_probing = 1\nnet.ipv4.ip_forward = 1\nnet.core.default_qdisc = fq\nnet.ipv4.tcp_congestion_control = bbr\nnet.ipv6.conf.all.disable_ipv6 = 1\nnet.ipv6.conf.default.disable_ipv6 = 1\nnet.ipv6.conf.lo.disable_ipv6 = 1'
    execute "Mengoptimalkan sysctl (BBR)" "echo -e \"${sysctl_conf}\" > /etc/sysctl.conf && sysctl -p"

    execute "Menginstall paket-paket yang dibutuhkan" "apt-get install -y libio-socket-inet6-perl libsocket6-perl libcrypt-ssleay-perl libnet-libidn-perl sqlite3 perl libio-socket-ssl-perl libwww-perl libpcre3 libpcre3-dev zlib1g-dev dbus iftop zip unzip wget net-tools curl nano sed screen gnupg gnupg1 bc apt-transport-https build-essential dirmngr dnsutils at htop iptables bsdmainutils cron lsof lnav"
    execute "Mengatur zona waktu ke Asia/Jakarta" "timedatectl set-timezone Asia/Jakarta"
}

install_marzban_core() {
    echo -e "\n${C_CYAN}Memulai instalasi Marzban...${C_RESET}"
    execute "Menjalankan skrip instalasi Marzban" "bash -c \"\$(curl -sL https://github.com/xsm-syn/Marzban-scripts/raw/master/marzban.sh)\" @ install"
}

configure_marzban_assets() {
    echo -e "\n${C_CYAN}Mengonfigurasi aset dan file Marzban...${C_RESET}"
    execute "Mengunduh template subscription" "wget -q -N -P /var/lib/marzban/templates/subscription/ https://raw.githubusercontent.com/xsm-syn/project/main/index.html"
    execute "Mengunduh file .env" "wget -q -O /opt/marzban/.env https://raw.githubusercontent.com/xsm-syn/project/main/env"
    execute "Mengunduh file docker-compose.yml" "wget -q -O /opt/marzban/docker-compose.yml https://raw.githubusercontent.com/xsm-syn/project/main/docker-compose.yml"
    
    mkdir -p /var/lib/marzban/assets /var/lib/marzban/core
    execute "Mengunduh Xray Core" "wget -q -O /var/lib/marzban/core/xray.zip https://github.com/XTLS/Xray-core/releases/download/v1.8.24/Xray-linux-64.zip"
    execute "Mengekstrak Xray Core" "unzip -o /var/lib/marzban/core/xray.zip -d /var/lib/marzban/core && chmod +x /var/lib/marzban/core/xray && rm /var/lib/marzban/core/xray.zip"
}

install_additional_tools() {
    echo -e "\n${C_CYAN}Menginstall alat tambahan...${C_RESET}"
    execute "Menyiapkan command 'profile' & 'neofetch'" "echo -e '\nprofile' >> /root/.profile && wget -q -O /usr/bin/profile https://raw.githubusercontent.com/xsm-syn/project/main/profile && chmod +x /usr/bin/profile && apt-get install -y neofetch"
    execute "Menyiapkan command 'cekservice'" "wget -q -O /usr/bin/cekservice https://raw.githubusercontent.com/xsm-syn/project/main/cekservice.sh && chmod +x /usr/bin/cekservice"

    execute "Menginstall vnstat & dependensi" "apt-get install -y vnstat libsqlite3-dev"
#    execute "Mengunduh source code vnstat" "wget -q https://github.com/xsm-syn/project/raw/main/vnstat-2.6.tar.gz"
#    execute "Mengkompilasi dan install vnstat" "tar zxvf vnstat-2.6.tar.gz && (cd vnstat-2.6 && ./configure --prefix=/usr --sysconfdir=/etc && make && make install) && chown vnstat:vnstat /var/lib/vnstat -R && systemctl enable vnstat && /etc/init.d/vnstat restart && rm -rf vnstat-2.6.tar.gz vnstat-2.6"
    
#    execute "Menambahkan repositori Speedtest" "curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash"
#    execute "Menginstall Speedtest CLI" "apt-get install -y speedtest"
}

configure_nginx_and_web() {
    echo -e "\n${C_CYAN}Mengonfigurasi Nginx sebagai reverse proxy...${C_RESET}"
    mkdir -p /var/log/nginx /var/www/html
    touch /var/log/nginx/access.log /var/log/nginx/error.log
    
    execute "Mengunduh konfigurasi Nginx" "wget -q -O /opt/marzban/nginx.conf https://raw.githubusercontent.com/xsm-syn/project/main/nginx.conf"
    execute "Mengunduh konfigurasi virtual host" "wget -q -O /opt/marzban/default.conf https://raw.githubusercontent.com/xsm-syn/project/main/vps.conf"
    execute "Mengunduh konfigurasi Xray" "wget -q -O /opt/marzban/xray.conf https://raw.githubusercontent.com/xsm-syn/project/main/xray.conf"
    execute "Membuat halaman index sederhana" "echo '<pre>Setup by AutoScript @after_sweet</pre>' > /var/www/html/index.html"
}

setup_ssl_certificate() {
    domain=$(cat "${DATA_DIR}/domain")
    echo -e "\n${C_CYAN}Memasang sertifikat SSL untuk domain: ${domain}${C_RESET}"
    execute "Menginstall socat" "apt-get install -y socat cron bash-completion"
    execute "Create Directory" "mkdir /root/.acme.sh"
    execute "Menginstall acme.sh" "curl https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh && chmod +x /root/.acme.sh/acme.sh"
    execute "Upgrade dan atur default CA acme.sh" "/root/.acme.sh/acme.sh --upgrade --auto-upgrade && /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt"
    execute "Menerbitkan sertifikat SSL" "/root/.acme.sh/acme.sh --issue -d \"${domain}\" --standalone -k ec-256"
    execute "Menginstall sertifikat ke path Marzban" "/root/.acme.sh/acme.sh --installcert -d \"${domain}\" --fullchainpath /var/lib/marzban/xray.crt --keypath /var/lib/marzban/xray.key --ecc"
    execute "Mengunduh xray_config.json" "wget -q -O /var/lib/marzban/xray_config.json https://raw.githubusercontent.com/xsm-syn/project/main/xray_config.json"
    execute "Mengatur kepemilikan sertifikat" "chown www-data:www-data /var/lib/marzban/xray.crt /var/lib/marzban/xray.key"
}

configure_firewall_and_db() {
    echo -e "\n${C_CYAN}Mengonfigurasi Firewall (UFW) dan database awal...${C_RESET}"
    execute "Menginstall UFW" "apt-get install -y ufw"
    execute "Mengatur aturan default UFW" "ufw default deny incoming && ufw default allow outgoing"
    execute "Membuka port yang diperlukan" "ufw allow ssh && ufw allow http && ufw allow https && ufw allow 8081/tcp && ufw allow 1080/tcp && ufw allow 1080/udp"
    execute "Mengaktifkan UFW" "ufw --force enable"
    execute "Mengunduh database awal" "wget -q -O /var/lib/marzban/db.sqlite3 https://github.com/xsm-syn/project/raw/main/db.sqlite3"
}

install_warp() {
    echo -e "\n${C_CYAN}Menginstall WARP Proxy...${C_RESET}"
    execute "Mengunduh skrip instalasi WARP" "wget -q -O /root/warp https://raw.githubusercontent.com/hamid-gh98/x-ui-scripts/main/install_warp_proxy.sh"
    execute "Menjalankan instalasi WARP" "chmod +x /root/warp && bash /root/warp -y && rm /root/warp"
}


# --- Modul Finalisasi ---

finalize_installation() {
    echo -e "\n${C_CYAN}Menyelesaikan instalasi dan memulai layanan...${C_RESET}"
    
    local userpanel=$(cat "${DATA_DIR}/userpanel")
    local passpanel=$(cat "${DATA_DIR}/passpanel")
    local domain=$(cat "${DATA_DIR}/domain")
    
    cd /opt/marzban
    execute "Mengatur username & password di .env" "sed -i \"s/# SUDO_USERNAME = \\\"admin\\\"/SUDO_USERNAME = \\\"${userpanel}\\\"/\" .env && sed -i \"s/# SUDO_PASSWORD = \\\"admin\\\"/SUDO_PASSWORD = \\\"${passpanel}\\\"/\" .env"
    execute "Menjalankan container Docker Marzban" "docker compose down && docker compose up -d"
    
    echo "  Menunggu 15 detik agar API siap..."
    sleep 15
    
    execute "Mengambil token API admin" "curl -s -X 'POST' 'https://${domain}/api/admin/token' -H 'accept: application/json' -H 'Content-Type: application/x-www-form-urlencoded' -d 'grant_type=password&username=${userpanel}&password=${passpanel}&scope=&client_id=&client_secret=' > '${DATA_DIR}/token.json'"
    
    local sql_command="UPDATE hosts SET address = '${domain}', host = '${domain}', sni = CASE WHEN security = 'tls' THEN '${domain}' ELSE sni END WHERE id BETWEEN 20 AND 34;"
    execute "Memperbarui hosts di database" "sqlite3 /var/lib/marzban/db.sqlite3 \"${sql_command}\""

    execute "Menghapus user admin default" "marzban cli admin delete -u admin -y"
    execute "Membersihkan paket sisa" "apt-get autoremove -y && apt-get clean"
}

display_summary() {
    local domain=$(cat "${DATA_DIR}/domain")
    local userpanel=$(cat "${DATA_DIR}/userpanel")
    local passpanel=$(cat "${DATA_DIR}/passpanel")

    clear
    profile

    local summary
    summary=$(cat <<EOF
+----------------------------------------------------------+
|             Instalasi Marzban Berhasil Selesai             |
+----------------------------------------------------------+

  Informasi Login Dashboard:
  -=================================-
  URL HTTPS : https://${domain}/dashboard
  Username  : ${userpanel}
  Password  : ${passpanel}
  -=================================-
  Telegram  : https://t.me/after_sweet
  -=================================-

  * Detail login juga tersimpan di /root/log-install.txt
  * Log instalasi lengkap tersimpan di ${LOG_FILE}
EOF
)
    echo "$summary"
    echo "$summary" > /root/log-install.txt
}

prompt_reboot() {
    echo
    read -rp "  Disarankan untuk me-reboot server. Reboot sekarang? [Y/n]: " answer
    if [[ ! "$answer" =~ ^[Nn]$ ]]; then
        colorized_echo "${C_YELLOW}" "  Server akan di-reboot sekarang!"
        cat /dev/null > ~/.bash_history && history -c && reboot
    else
        colorized_echo "${C_GREEN}" "  Instalasi selesai tanpa reboot."
        exit 0
    fi
}

# --- Fungsi Utama (Execution Flow) ---

main() {
    clear
    print_header
    
    check_prerequisites
#    configure_repositories
    get_user_input
    
    clear
    echo -e "${C_BLUE}Memulai tahap instalasi utama...${C_RESET}"

    prepare_system
    install_marzban_core
    configure_marzban_assets
    install_additional_tools
    configure_nginx_and_web
    setup_ssl_certificate
    configure_firewall_and_db
    install_warp
    
    finalize_installation
    display_summary
    prompt_reboot
}

# Jalankan skrip
main
