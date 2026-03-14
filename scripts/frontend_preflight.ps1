param(
    [switch]$SkipBuild,
    [string]$ApiBaseUrl = "http://127.0.0.1:8080/api/v1"
)

$ErrorActionPreference = "Stop"

flutter doctor -v
flutter test
flutter analyze

if (-not $SkipBuild) {
    flutter build windows --release --dart-define="COSTANORTE_API_BASE_URL=$ApiBaseUrl"
}
