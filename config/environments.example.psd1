@{
    <#
        Example environment configuration for ps-script-machine.
        Copy this file to 'environments.psd1' and replace with your actual values.
        NEVER commit the real configuration file - it is in .gitignore.

        Use SecretManagement for credentials - never store passwords here.
    #>
    Environments = @{
        Production = @{
            vCenter   = 'vcenter.prod.example.com'  # Replace with your vCenter FQDN
            Port      = 443
            Protocol  = 'https'
            # Credentials: Use SecretManagement
            # SecretName = 'vcenter-prod-cred'
            # VaultName  = 'MyVault'
        }
        Test = @{
            vCenter   = 'vcenter.test.example.com'  # Replace with your test vCenter FQDN
            Port      = 443
            Protocol  = 'https'
            # Credentials: Use SecretManagement
            # SecretName = 'vcenter-test-cred'
            # VaultName  = 'MyVault'
        }
        Lab = @{
            vCenter   = 'vcenter.lab.example.com'  # Replace with your lab vCenter FQDN
            Port      = 443
            Protocol  = 'https'
            # Credentials: Use SecretManagement
            # SecretName = 'vcenter-lab-cred'
            # VaultName  = 'MyVault'
        }
    }

    # Default environment to use when not specified
    DefaultEnvironment = 'Test'

    # Logging configuration
    Logging = @{
        Enabled   = $true
        Level     = 'Information'  # Information, Warning, Error, Debug
        LogFile   = ''             # Optional: Path to log file
        Console   = $true          # Write to console
    }

    # Export configuration
    Export = @{
        DefaultPath    = 'C:\Exports'  # Default export path
        DefaultFormats = @('CSV', 'JSON')
    }
}