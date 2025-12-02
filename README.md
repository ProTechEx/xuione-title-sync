\
# XUI-One Auto Title Sync (cron.d version)

Automated title synchronization for XUI-One IPTV panel.

## Install

Must be run as root:

```bash
chmod +x installer.sh
sudo ./installer.sh
```

The installer will:

- Auto-detect DB credentials from any `*/xuione/credentials.txt`
- Ask for provider URL (IP or domain), username, password
- Test provider connection via `/player_api.php`
- Ask how often to run the sync
- Install a cron entry in `/etc/cron.d/xuione-title-sync` that calls `title_sync.sh` with absolute path as root
- Create `config.env`

## Manual Run

```bash
sudo ./title_sync.sh
```

## Logs

Logs are in the same directory as the scripts:

- `sync.log` – human-readable log with newest runs at the top.
  - If Python3 is available and passed sanity test: keeps last 7 days of entries.
  - Otherwise (fallback): keeps last 20 sync blocks.
- `provider.json` – latest provider response snapshot (overwritten each run).
