param(
    [Parameter()]
    [ValidatePattern('^[a-z0-9]([-a-z0-9]*[a-z0-9])?$')]
    [string]$ChartName = 'helm-charts-implementation'
)

$ErrorActionPreference = 'Stop'
$chartPath = Join-Path $PSScriptRoot "..\charts\$ChartName"
$directories = @(
    $chartPath,
    (Join-Path $chartPath 'templates'),
    (Join-Path $chartPath 'templates\tests'),
    (Join-Path $chartPath 'charts')
)

foreach ($directory in $directories) {
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
}

$files = @(
    'Chart.yaml',
    'values.yaml',
    '.helmignore',
    'templates\_helpers.tpl',
    'templates\deployment.yaml',
    'templates\service.yaml',
    'templates\serviceaccount.yaml',
    'templates\ingress.yaml',
    'templates\hpa.yaml',
    'templates\metrics-configmap.yaml',
    'templates\servicemonitor.yaml',
    'templates\prometheusrule.yaml',
    'templates\NOTES.txt',
    'templates\tests\test-connection.yaml',
    'charts\.gitkeep'
)

foreach ($file in $files) {
    $path = Join-Path $chartPath $file
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType File | Out-Null
    }
}

Write-Output "Created chart structure at $chartPath"
