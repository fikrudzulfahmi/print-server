# Print Server (CUPS + JetDirect)

Appliance print server untuk printer USB (contoh: Epson L120) supaya bisa dipakai
banyak PC Windows di LAN. Dua jalur cetak:

1. **Port 9100 (RAW)** — client memakai driver Epson sendiri (kualitas penuh, rekomendasi).
2. **Port 9101 (PostScript)** — cadangan untuk client tanpa driver.

## Jalankan dengan Docker
```bash
git clone https://github.com/fikrudzulfahmi/print-server.git && cd print-server
mkdir -p data && cp .env.example data/.env && nano data/.env
docker compose up -d --build
docker compose logs -f cups
```
CUPS: `http://<ip-server>:631` · Antrian: `EpsonL120` (RAW) dan `EpsonL120-PS`.

Prasyarat: printer tercolok USB, dan container diberi akses `/dev/bus/usb`.
Kalau printer dicabut/pasang ulang, jalankan `docker compose restart cups` agar antrian
menemukan URI baru.

### Tanpa Docker (cara lama, di host)
```bash
sudo bash setup-server.sh
```
Script ini meng-install CUPS + driver, membuat kedua antrian, port 9100/9101 via
systemd socket, nama NetBIOS `NGEMIS-AI`, dan LLMNR.

## Client Windows
`client/Pasang-Printer-L120.bat` (jalankan sebagai Administrator, sekali per PC):
mencari server, memasang printer via port 9100, lalu tes cetak.

**Perbedaan penting Docker vs host:** di Docker tidak ada nama NetBIOS `NGEMIS-AI`
(nmbd tidak ikut). Ubah `SERVER=` di dalam `.bat` menjadi **IP statis server**
(mis. `192.168.1.50`) atau hostname DNS. Di mode host, `SERVER=NGEMIS-AI` tetap jalan.

## Variabel (`.env`)
| Variabel | Default | Keterangan |
|---|---|---|
| `QUEUE_RAW` | `EpsonL120` | nama antrian RAW (port 9100) |
| `QUEUE_PS` | `EpsonL120-PS` | nama antrian PostScript (port 9101) |
| `DEFAULT_QUEUE` | `EpsonL120` | antrian default |
| `PRINTER_URI` | kosong | isi manual `usb://EPSON/...` bila autodetect gagal |
| `SERVER_NAME` | `NGEMIS-AI` | hanya untuk dokumentasi/banner |

## Catatan keamanan
`docker/cupsd.conf` membuka admin CUPS **tanpa password** untuk jaringan lokal
(`127.0.0.1`, `172.16.0.0/12`, `192.168.0.0/16`) — ini appliance LAN, bukan server publik.
Jangan expose port 631 ke internet.
