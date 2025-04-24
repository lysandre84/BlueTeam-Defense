# BlueTeam-Defense

Un ensemble d’outils et de scripts pour renforcer la défense de votre infrastructure.

## Structure du projet

Voir le dépôt pour la structure complète.

## Prérequis

- Python 3.8+
- Go 1.16+
- PowerShell 5.1+
- Bash

Installer les dépendances Python :
```bash
pip install -r requirements.txt
```

## Utilisation

### Bash
```bash
bash Scripts/Bash/security_audit.sh
```

### Python
```bash
python3 Scripts/Python/vuln_report_generator.py --input logs/alert.log
```

### PowerShell
```powershell
.\Scripts\Powershellirewall_status.ps1
```

### Go
```bash
go run Scripts/Go/port_checker.go --host 10.0.0.1 --ports 22,80,443
```

## CI & Qualité

- Tests Python avec pytest
- Linting Bash & Go
- Workflow GitHub Actions dans `.github/workflows/ci.yml`

## Licence

MIT. Voir [LICENSE](LICENSE).
