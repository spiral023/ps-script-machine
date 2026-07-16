# ============================================================================
# Beispiel-Konfiguration für VMware-Umgebungen
# ============================================================================
# Kopiere diese Datei nach environments.psd1 und passe die Werte an.
# environments.psd1 wird von .gitignore ignoriert.

@{
    # Produktionsumgebung
    Production = @{
        vCenter   = "vcenter-prod.firma.local"
        Cluster   = @("Prod-Cluster-01", "Prod-Cluster-02")
        # Credential wird über Secret Vault oder Get-Credential geladen
        SecretName = "VMware-vCenter-Production"
    }

    # Testumgebung
    Test = @{
        vCenter   = "vcenter-test.firma.local"
        Cluster   = @("Test-Cluster-01")
        SecretName = "VMware-vCenter-Test"
    }

    # Entwicklungsumgebung
    Development = @{
        vCenter   = "vcenter-dev.firma.local"
        Cluster   = @("Dev-Cluster-01")
        SecretName = "VMware-vCenter-Dev"
    }

    # Standard-Ausgabepfade
    OutputPaths = @{
        Reports  = "C:\Reports"
        Logs     = "C:\Reports\Logs"
    }

    # Standard-Export-Format
    DefaultExportFormat = "CSV"  # CSV, JSON, oder beide
}