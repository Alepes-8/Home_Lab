# Home Lab

## General structure

homelab/
├── docker-compose/
│ ├── docker-compose.dev.yml # Old laptop optional
│ ├── docker-compose.staging.yml # Old PC staging
│ ├── docker-compose.prod.yml # Old PC prod
│ ├── docker-compose.jenkins.yml # Old PC Jenkins
│ └── docker-compose.monitoring.yml # Pi monitoring
│
├── nginx/
│ ├── nginx.conf
│ ├── sites/
│ │ ├── api.local.conf
│ │ ├── staging.local.conf
│ │ ├── jenkins.local.conf
│ │ └── grafana.local.conf
│ └── Dockerfile (if custom Nginx image)
│
├── wireguard/
│ ├── wg0.conf.template # Template with placeholders
│ ├── generate-client.sh # Script to create client configs
│ └── README.md
│
├── scripts/
│ ├── bootstrap-ubuntu.sh # Initial server setup
│ ├── backup-mongodb.sh # Cron job for backups
│ ├── verify-backups.sh # Backup verification
│ ├── deploy-to-staging.sh # Manual deploy helper
│ ├── rollback.sh # Rollback script
│ └── setup-static-ips.sh # DHCP reservation helper
│
├── prometheus/
│ └── prometheus.yml # Scrape configs for all environments
│
├── grafana/
│ └── dashboards/
│ ├── api-overview.json
│ └── infrastructure.json
│
├── ansible/ (optional - Phase 6)
│ └── playbooks/
│ ├── setup-old-pc.yml
│ └── setup-pi.yml
│
├── docs/
│ ├── architecture-decisions.md # Your ADRs
│ ├── runbook.md # How to operate the platform
│ ├── disaster-recovery.md # How to rebuild from scratch
│ └── network-topology.md # IP assignments, VLANs, etc
│
├── .env.example # Template for all env vars needed
└── README.md # How to deploy this entire infrastructure