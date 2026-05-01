#!/bin/sh
# AirBuddy Theme Installer - runs on pod startup
set -e

THEME_DIR="/www/public/buddy"
REPO_BASE="https://raw.githubusercontent.com/ycong3531-boop/Xboard/master/public/buddy"

if [ -f "$THEME_DIR/index.html" ]; then
    exit 0
fi

echo "[buddy] Installing AirBuddy theme..."
mkdir -p "$THEME_DIR/assets"

for f in index.html config.js favicon.ico; do
    wget -q -O "$THEME_DIR/$f" "$REPO_BASE/$f"
done

wget -q -O- "https://api.github.com/repos/ycong3531-boop/Xboard/contents/public/buddy/assets" 2>/dev/null | \
    grep '"download_url"' | cut -d'"' -f4 | \
    while read url; do
        fname=$(basename "$url")
        wget -q -O "$THEME_DIR/assets/$fname" "$url"
    done

chown -R www:www "$THEME_DIR"
echo "[buddy] Theme installed: $(ls "$THEME_DIR/assets/" | wc -l) assets"

# Update routes if needed
if ! grep -q "buddy" /www/routes/web.php 2>/dev/null; then
    echo "[buddy] Updating routes..."
    cat > /www/routes/web.php << 'WEBPHP'
<?php
use App\Services\UpdateService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\File;
Route::get("/", function () {
    $buddyFile = public_path("buddy/index.html");
    if (File::exists($buddyFile)) return response()->file($buddyFile);
    return abort(404);
});
Route::get("/" . admin_setting("secure_path", admin_setting("frontend_admin_path", hash("crc32b", config("app.key")))), function () {
    return view("admin", ["title" => admin_setting("app_name", "XBoard"), "theme_sidebar" => admin_setting("frontend_theme_sidebar", "light"), "theme_header" => admin_setting("frontend_theme_header", "dark"), "theme_color" => admin_setting("frontend_theme_color", "default"), "background_url" => admin_setting("frontend_background_url"), "version" => app(UpdateService::class)->getCurrentVersion(), "logo" => admin_setting("logo"), "secure_path" => admin_setting("secure_path", admin_setting("frontend_admin_path", hash("crc32b", config("app.key"))))]);
});
Route::get("/" . (admin_setting("subscribe_path", "s")) . "/{token}", [\App\Http\Controllers\V1\Client\ClientController::class, "subscribe"])->middleware("client")->name("client.subscribe");
WEBPHP
    php /www/artisan route:clear 2>/dev/null || true
    echo "[buddy] Routes updated."
fi
