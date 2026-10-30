#!/bin/bash
# Setup print server Epson L120 di ngemis-ai
# Jalankan: sudo bash ~/printserver/setup-server.sh
set -e
[ "$(id -u)" = 0 ] || { echo "Jalankan pakai sudo"; exit 1; }

Q=EpsonL120          # antrian RAW (dipakai client dengan driver Epson L120)
QPS=EpsonL120-PS     # antrian PostScript (cadangan, client tanpa driver Epson)

echo "== 1. Install paket =="
# Repo Ookla speedtest (packagecloud) 404 untuk noble -> bikin apt-get update gagal. Nonaktifkan.
for f in $(grep -l 'packagecloud.io/ookla' /etc/apt/sources.list.d/* 2>/dev/null); do mv "$f" "$f.disabled"; echo "Nonaktifkan repo rusak: $f"; done
apt-get update || echo "PERINGATAN: apt-get update ada error, lanjut install..."
DEBIAN_FRONTEND=noninteractive apt-get install -y cups printer-driver-escpr printer-driver-gutenprint samba-common-bin samba avahi-daemon

echo "== 2. Konfigurasi CUPS =="
systemctl enable --now cups
cupsctl --share-printers --remote-any --no-remote-admin
grep -q '^ServerAlias \*' /etc/cups/cupsd.conf || sed -i '1i ServerAlias *' /etc/cups/cupsd.conf
systemctl restart cups; sleep 2

URI=$(lpinfo -v 2>/dev/null | grep -m1 -o 'usb://EPSON[^ ]*')
[ -n "$URI" ] || { echo "Printer EPSON tidak terdeteksi di USB! Cek kabel/power."; exit 1; }
echo "URI printer: $URI"

lpadmin -x $Q 2>/dev/null || true
lpadmin -p $Q -E -v "$URI" -m raw -D "Epson L120 (RAW)" -o printer-is-shared=true 2>/dev/null \
  || lpadmin -p $Q -E -v "$URI" -D "Epson L120 (RAW)" -o printer-is-shared=true
PPD=$(lpinfo -m | grep -i 'escpr' | grep -i 'L120' | head -1 | awk '{print $1}')
[ -n "$PPD" ] || PPD=$(lpinfo -m | grep -i 'L120' | head -1 | awk '{print $1}')
echo "PPD cadangan: $PPD"
lpadmin -x $QPS 2>/dev/null || true
lpadmin -p $QPS -E -v "$URI" -m "$PPD" -D "Epson L120 (PostScript)" -o printer-is-shared=true -o PageSize=A4
lpadmin -d $Q
cupsenable $Q $QPS; cupsaccept $Q $QPS

echo "== 3. Port RAW 9100 / 9101 (JetDirect) untuk Windows =="
mk() { # $1=port $2=queue $3=opsi
cat > /etc/systemd/system/print$1.socket <<EOF
[Unit]
Description=Print listener port $1 -> $2
[Socket]
ListenStream=$1
Accept=yes
[Install]
WantedBy=sockets.target
EOF
cat > /etc/systemd/system/print$1@.service <<EOF
[Unit]
Description=Print job port $1 -> $2
[Service]
ExecStart=/usr/bin/lp -d $2 $3 -t WindowsJob
StandardInput=socket
StandardOutput=null
User=nobody
EOF
}
mk 9100 $Q "-o raw"
mk 9101 $QPS ""
systemctl daemon-reload
systemctl enable --now print9100.socket print9101.socket

echo "== 4. Nama server tetap (IP boleh berubah): NetBIOS + LLMNR + mDNS =="
[ -f /etc/samba/smb.conf.orig ] || cp /etc/samba/smb.conf /etc/samba/smb.conf.orig 2>/dev/null || true
cat > /etc/samba/smb.conf <<EOF
[global]
   workgroup = WORKGROUP
   netbios name = NGEMIS-AI
   server string = Print Server
   disable netbios = no
   wins support = no
   dns proxy = no
   load printers = no
   printing = bsd
   printcap name = /dev/null
   disable spoolss = yes
   log file = /var/log/samba/log.%m
EOF
systemctl enable --now nmbd; systemctl restart nmbd
systemctl disable --now smbd 2>/dev/null || true
mkdir -p /etc/systemd/resolved.conf.d
printf '[Resolve]\nLLMNR=yes\nMulticastDNS=no\n' > /etc/systemd/resolved.conf.d/llmnr.conf
systemctl restart systemd-resolved
systemctl enable --now avahi-daemon

if systemctl is-active -q ufw; then ufw allow 631/tcp; ufw allow 9100:9101/tcp; ufw allow 137:138/udp; ufw allow 5355; fi

echo
echo "== SELESAI =="
lpstat -t | head -20
ss -ltnup | grep -E ':(631|9100|9101|137|5355) ' || true
echo "Client menghubungi server lewat nama: NGEMIS-AI (port 9100)"
