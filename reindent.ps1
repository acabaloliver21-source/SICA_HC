$ErrorActionPreference = 'Stop'
$p = 'C:\Users\moonzadax7\Documents\aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\3105\ThreeOneOSFive\helpers\KeyAuthClient.swift'
$t = Get-Content -Raw -Encoding UTF8 $p
$changes = 0
$t = $t -replace '(?m)^(\s*)static let shared = KeyAuthConfiguration\(', { $matches = $null; param($m) ; $script:changes++; '    static let shared = KeyAuthConfiguration('}
$t = $t -replace '(?m)^\s*guard KeyAuthConfiguration\.isConfigured', { $script:changes++; '        guard KeyAuthConfiguration.isConfigured'}
$t = $t -replace '(?m)^\s*let timestamp = \(expiry as\? NSNumber\)', { $script:changes++; '            let timestamp = (expiry as? NSNumber)'}
$t = $t -replace '(?m)^\s*private func request\(_ params', { $script:changes++; '    private func request(_ params'}
$t = $t -replace '(?m)^\s*// MARK: Helpers', { $script:changes++; '    // MARK: Helpers'}
[System.IO.File]::WriteAllText($p, $t, [System.Text.UTF8Encoding]::new($false))
'changes-applied=' + $script:changes