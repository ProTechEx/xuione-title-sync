# XUI-One Auto Title Sync

Automated title synchronization for XUI-One IPTV panel.

## Install

```bash
chmod +x installer.sh
./installer.sh
```

## Manual Run

```bash
./title_sync.sh
```

Log files saved inside the same directory:

- `sync.log` – info log (only last 7 days kept if Python3 is available, otherwise last 20 runs)
- `provider.json` – latest provider response snapshot
