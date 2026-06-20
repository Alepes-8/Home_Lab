# Rollback

With different versions and different deployment processes, it is important to have a streamlined process to deploy and rollback an environment to a stable point if something breaks. In order to achieve this, the rollback script **rollback.sh** is created. This script allows the user to redeploy a specific version to the docker container through an automated process.

## How to use

The rollback script has its own `--help` flag that explains usage and supported options. The steps below cover how to use it correctly.

1. Open a terminal in the directory where `rollback.sh` is located
2. Run the following command, substituting `<location>` with `prod` or `staging`, and `<version>` with the desired version tag:
```bash
./rollback.sh <location> <version>
```

**Example:**
```bash
./rollback.sh prod v2.1.1
```

This would trigger a rollback deployment of `v2.1.1` onto the `prod` environment.