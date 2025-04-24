# Règles de Détection

## SIEM (Splunk)
`index=os sourcetype=wineventlog Logon_Type=3 Logon_Process=NtLmSsp` -> Bruteforce

## YARA
- Règles YARA pour malwares connus
