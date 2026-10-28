param(
    [ValidateSet("web", "windows")]
    [string]$Target = "web",
    [switch]$SkipBuild,
    [string]$ApiBaseUrl = "https://quadras-back-production.up.railway.app/api/v1",
    [string]$WebBaseHref = "/costanorte/"
)

$ErrorActionPreference = "Stop"

flutter doctor -v
flutter test
flutter analyze

if (-not $SkipBuild) {
    if ($Target -eq "web") {
        flutter build web --release --base-href=$WebBaseHref --dart-define="COSTANORTE_API_BASE_URL=$ApiBaseUrl"
    }
    else {
        flutter build windows --release --dart-define="COSTANORTE_API_BASE_URL=$ApiBaseUrl"
    }
}
