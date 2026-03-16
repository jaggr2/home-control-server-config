# Home Control Server Config

This repository contains configuration files and setup instructions for my Home Control Server.

## Features
- Centralized configuration management
- Easy deployment and updates

## Getting Started
On a fresh debian installation, follow ./scripts/01-system.sh

# Architecture overview
```
/home/homelab/                    # central config dir, git managed
├── docker-compose.yml            
├── .env                          
├── renovate.json                 
├── services/
│   ├── cloudflared/
│   │   └── config.yml
│   ├── homeassistant/
│   │   └── configuration.yaml
│   ├── freepbx/
│   │   └── ... (config files)
│   └── nodered/
│       └── settings.js
├── setup/                        # system setup scripts 
│   ├── 01-system-base.sh
│   ├── 02-docker.sh
│   ├── 03-lcd-display.sh
│   └── 04-auto-update.sh
└── scripts/
    ├── apply-config.sh           # applies container versions
    └── check-updates.sh          # check for updates
```

## Contributing
Contributions are welcome! Please open issues or submit pull requests.

## License
See file LICENSE