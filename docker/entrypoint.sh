#!/bin/bash
# Menyalakan CUPS + menyiapkan antrian printer Epson dan port RAW 9100/9101.
set -u

Q="${QUEUE_RAW:-EpsonL120}"
QPS="${QUEUE_PS:-EpsonL120-PS}"
DEFQ="${DEFAULT_QUEUE:-$Q}"
URI_FIX="${PRINTER_URI:-}"

log() { echo "[print] $*"; }

# --- 1. cupsd ---
log "menyalakan cupsd"
/usr/sbin/cupsd -f &
CUPS_PID=$!
for i in $(seq 1 30); do
  lpstat -r >/dev/null 2>&1 && break
  sleep 1
done
lpstat -r || log "PERINGATAN: cupsd belum merespons"

# --- 2. antrian printer ---
setup_queue() {
  local uri="$1"
  [ -n "$uri" ] || { log "URI printer tidak ditemukan (printer USB belum tercolok?)"; return 1; }
  log "URI: $uri"

  lpadmin -x "$Q" 2>/dev/null
  lpadmin -x "$QPS" 2>/dev/null

  # antrian RAW: client pakai driver Epson sendiri
  lpadmin -p "$Q" -E -v "$uri" -m raw -D "Epson L120 (RAW)" -o printer-is-shared=true 2>/dev/null \
    || lpadmin -p "$Q" -E -v "$uri" -D "Epson L120 (RAW)" -o printer-is-shared=true

  # antrian PostScript: cadangan untuk client tanpa driver
  local ppd
  ppd="$(lpinfo -m 2>/dev/null | grep -i escpr | grep -i 'l120' | head -1 | awk '{print $1}')"
  [ -n "$ppd" ] || ppd="$(lpinfo -m 2>/dev/null | grep -i 'l120' | head -1 | awk '{print $1}')"
  [ -n "$ppd" ] || ppd="$(lpinfo -m 2>/dev/null | grep -i 'gutenprint' | grep -i 'l120' | head -1 | awk '{print $1}')"
  [ -n "$ppd" ] || ppd="$(lpinfo -m 2>/dev/null | grep -i '^everywhere' | head -1 | awk '{print $1}')"
  log "PPD: ${ppd:-<tidak ada>}"
  if [ -n "$ppd" ]; then
    lpadmin -p "$QPS" -E -v "$uri" -m "$ppd" -D "Epson L120 (PostScript)" \
      -o printer-is-shared=true -o PageSize=A4 2>/dev/null || true
  fi

  lpadmin -d "$DEFQ" 2>/dev/null || true
  cupsenable "$Q" 2>/dev/null; cupsaccept "$Q" 2>/dev/null
  [ -n "${ppd:-}" ] && { cupsenable "$QPS" 2>/dev/null; cupsaccept "$QPS" 2>/dev/null; }
  lpstat -t | head -10
  return 0
}

find_uri() {
  if [ -n "$URI_FIX" ]; then echo "$URI_FIX"; return 0; fi
  lpinfo -v 2>/dev/null | awk '/^direct usb:\/\/EPSON/ {print $2; exit}'
}

# coba sampai 20x (perangkat USB kadang muncul belakangan)
READY=0
for i in $(seq 1 20); do
  U="$(find_uri)"
  if [ -n "$U" ] && setup_queue "$U"; then READY=1; break; fi
  log "percobaan ${i}/20: printer USB belum terdeteksi (cek kabel/power)"
  sleep 3
done
[ "$READY" = 1 ] || log "PERINGATAN: antrian belum dibuat. Colok printer lalu: docker compose restart cups"

# --- 3. port RAW 9100 / 9101 untuk client Windows (JetDirect) ---
start_raw() {
  local port="$1" queue="$2" opt="$3"
  socat "TCP-LISTEN:${port},reuseaddr,fork" "EXEC:/usr/bin/lp -d ${queue} ${opt} -t WindowsJob" &
  log "port ${port} -> ${queue}"
}
start_raw 9100 "$Q" "-o raw"
start_raw 9101 "$QPS" ""

log "siap. panel: http://<ip>:631"
wait "$CUPS_PID"
