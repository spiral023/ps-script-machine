BeforeAll {
    # Das Skript dot-sourcen, um die Funktionen verfügbar zu machen.
    # Da das Skript interaktive Eingaben enthält, definieren wir die
    # Hilfsfunktionen hier direkt nach, damit Tests isoliert laufen.

    function ConvertTo-CleanText {
        param (
            [Parameter()]
            [AllowNull()]
            [object]$Value
        )

        if ($null -eq $Value) {
            return ""
        }

        if ($Value -is [System.Array]) {
            $text = $Value -join ", "
        }
        else {
            $text = [string]$Value
        }

        return ([regex]::Replace($text, "\s+", " ")).Trim()
    }

    function Export-Windows1252Csv {
        param (
            [Parameter(Mandatory)]
            [object[]]$InputObject,

            [Parameter(Mandatory)]
            [string]$Path
        )

        if ($PSVersionTable.PSEdition -eq "Core") {
            try {
                [System.Text.Encoding]::RegisterProvider(
                    [System.Text.CodePagesEncodingProvider]::Instance
                )
            }
            catch {
                Write-Verbose "Windows-1252-Codepage-Provider war bereits registriert."
            }
        }

        $encoding = [System.Text.Encoding]::GetEncoding(1252)

        $csvContent = $InputObject |
            ConvertTo-Csv -Delimiter ";" -NoTypeInformation

        [System.IO.File]::WriteAllLines($Path, $csvContent, $encoding)
    }
}

Describe "ConvertTo-CleanText" {
    It "Gibt leeren String bei null zurück" {
        ConvertTo-CleanText -Value $null | Should -Be ""
    }

    It "Gibt leeren String bei leerem String zurück" {
        ConvertTo-CleanText -Value "" | Should -Be ""
    }

    It "Gibt den Wert bei einfachem String zurück" {
        ConvertTo-CleanText -Value "Switch1" | Should -Be "Switch1"
    }

    It "Verbindet Array-Elemente mit Komma" {
        $result = ConvertTo-CleanText -Value @("a", "b", "c")
        $result | Should -Be "a, b, c"
    }

    It "Ersetzt mehrere Leerzeichen durch eines" {
        $result = ConvertTo-CleanText -Value "  Hallo   Welt  "
        $result | Should -Be "Hallo Welt"
    }

    It "Ersetzt Tabs und Newlines durch einzelne Leerzeichen" {
        $result = ConvertTo-CleanText -Value "Hallo`t`tWelt`r`nTest"
        $result | Should -Be "Hallo Welt Test"
    }

    It "Entfernt führende und nachfolgende Leerzeichen" {
        $result = ConvertTo-CleanText -Value "   Test   "
        $result | Should -Be "Test"
    }

    It "Behält Zahlen als String bei" {
        $result = ConvertTo-CleanText -Value 42
        $result | Should -Be "42"
    }

    It "Behandelt Integer-Arrays" {
        $result = ConvertTo-CleanText -Value @(1, 2, 3)
        $result | Should -Be "1, 2, 3"
    }
}

Describe "Export-Windows1252Csv" {
    BeforeEach {
        $script:testPath = Join-Path $env:TEMP "test_export_$(Get-Random).csv"
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:testPath) {
            Remove-Item -LiteralPath $script:testPath -Force
        }
    }

    It "Erstellt eine CSV-Datei" {
        $data = [PSCustomObject]@{
            Name = "Test"
            Wert = "123"
        }

        Export-Windows1252Csv -InputObject $data -Path $script:testPath

        Test-Path -LiteralPath $script:testPath | Should -Be $true
    }

    It "Schreibt Header mit Semikolon-Trennzeichen" {
        $data = [PSCustomObject]@{
            Name = "Test"
            Wert = "123"
        }

        Export-Windows1252Csv -InputObject $data -Path $script:testPath

        $content = Get-Content -LiteralPath $script:testPath -Encoding UTF8
        $content[0] | Should -Be '"Name";"Wert"'
    }

    It "Schreibt Datenzeilen korrekt" {
        $data = [PSCustomObject]@{
            Name = "TestHost"
            Wert = "Wert1"
        }

        Export-Windows1252Csv -InputObject $data -Path $script:testPath

        $content = Get-Content -LiteralPath $script:testPath -Encoding UTF8
        $content[1] | Should -Be '"TestHost";"Wert1"'
    }

    It "Verarbeitet mehrere Objekte" {
        $data = @(
            [PSCustomObject]@{ Name = "A"; Wert = "1" }
            [PSCustomObject]@{ Name = "B"; Wert = "2" }
        )

        Export-Windows1252Csv -InputObject $data -Path $script:testPath

        $content = Get-Content -LiteralPath $script:testPath -Encoding UTF8
        $content.Count | Should -Be 3  # Header + 2 Datenzeilen
    }

    It "Verarbeitet Sonderzeichen (Umlaute)" {
        $data = [PSCustomObject]@{
            Name = "Täst"
            Wert = "Ünïcödé"
        }

        Export-Windows1252Csv -InputObject $data -Path $script:testPath

        # Datei mit Windows-1252 lesen, da sie so geschrieben wurde
        if ($PSVersionTable.PSEdition -eq "Core") {
            [System.Text.Encoding]::RegisterProvider(
                [System.Text.CodePagesEncodingProvider]::Instance
            )
        }
        $encoding1252 = [System.Text.Encoding]::GetEncoding(1252)
        $content = [System.IO.File]::ReadAllLines($script:testPath, $encoding1252)
        $content[1] | Should -Match 'Täst'
    }
}