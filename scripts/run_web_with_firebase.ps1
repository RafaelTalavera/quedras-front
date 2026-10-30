$requiredVariables = @(
    'FIREBASE_API_KEY',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_MESSAGING_SENDER_ID',
    'FIREBASE_WEB_APP_ID',
    'FIREBASE_WEB_VAPID_KEY'
)

$missingVariables = @(
    $requiredVariables | Where-Object {
        [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_))
    }
)

if ($missingVariables.Count -gt 0) {
    throw "Faltan variables Firebase: $($missingVariables -join ', ')"
}

$arguments = @(
    'run',
    '-d',
    'chrome',
    "--dart-define=COSTANORTE_API_BASE_URL=$(if ([string]::IsNullOrWhiteSpace($env:COSTANORTE_API_BASE_URL)) { 'http://127.0.0.1:8080/api/v1' } else { $env:COSTANORTE_API_BASE_URL })",
    '--dart-define=FIREBASE_ENABLED=true',
    "--dart-define=FIREBASE_API_KEY=$env:FIREBASE_API_KEY",
    "--dart-define=FIREBASE_PROJECT_ID=$env:FIREBASE_PROJECT_ID",
    "--dart-define=FIREBASE_MESSAGING_SENDER_ID=$env:FIREBASE_MESSAGING_SENDER_ID",
    "--dart-define=FIREBASE_WEB_APP_ID=$env:FIREBASE_WEB_APP_ID",
    "--dart-define=FIREBASE_WEB_VAPID_KEY=$env:FIREBASE_WEB_VAPID_KEY"
)

if (-not [string]::IsNullOrWhiteSpace($env:FIREBASE_AUTH_DOMAIN)) {
    $arguments += "--dart-define=FIREBASE_AUTH_DOMAIN=$env:FIREBASE_AUTH_DOMAIN"
}
if (-not [string]::IsNullOrWhiteSpace($env:FIREBASE_STORAGE_BUCKET)) {
    $arguments += "--dart-define=FIREBASE_STORAGE_BUCKET=$env:FIREBASE_STORAGE_BUCKET"
}

& flutter @arguments
exit $LASTEXITCODE
