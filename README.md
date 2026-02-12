# Passwall
[![visitor badge](https://img.shields.io/badge/Chat%20on-Telegram-blue.svg)](https://t.me/AmirHosseinTSL) [![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
# How to install Passwall + Xray & Sing-Box on openwrt




# System Requirements :

- CPU : `+700 MHz ✅`

- RAM : `+256 MB ✅`

- ⚠️ Before Installation, Make sure `Wan Address` And `Lan address` are not same !
     
# INSTALL PASSWALL : 

## Passwall 1 (128MB+ RAM)
```bash
rm -f install-passwall1.sh && wget -O install-passwall1.sh https://raw.githubusercontent.com/nooblk-98/passwall-installer/refs/heads/main/install-passwall1.sh && chmod +x install-passwall1.sh && sh install-passwall1.sh
```

## Passwall 2 (256MB+ RAM)
```bash
rm -f install-passwall2.sh && wget -O install-passwall2.sh https://raw.githubusercontent.com/nooblk-98/passwall-installer/refs/heads/main/install-passwall2.sh && chmod +x install-passwall2.sh && sh install-passwall2.sh
```

Done !

# Script Features:

✅ **Install** - Fresh installation from SourceForge official feeds  
✅ **Update** - Update existing installation (keeps your configuration)  
✅ **Reinstall** - Clean reinstall (removes and reinstalls fresh)  
✅ **Uninstall** - Removes only the specific Passwall app (keeps core packages)  

**Note:** 
- All Passwall packages are installed from official SourceForge feeds, not from custom third-party repositories
- Uninstalling Passwall 1 does NOT remove Passwall 2 (and vice versa)
- Core packages (xray-core, sing-box, etc.) are preserved as they may be used by other apps


