# XUI-One Auto Title Sync

Automated title synchronization for XUI-One IPTV panel.

## Install

Must be run as root:

```bash
chmod +x installer.sh
sudo ./installer.sh
```

## Manual Run

```bash
sudo ./title_sync.sh
```

Logs (in same directory):

- `sync.log` – human-readable info log (newest at top, 7 days kept if Python3 OK, otherwise last 20 runs)
- `provider.json` – latest provider response snapshot (overwritten each run)
