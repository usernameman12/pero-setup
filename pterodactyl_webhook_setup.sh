#!/bin/bash

set -e

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo "Checking dependencies..."
if ! command_exists php; then
    echo "PHP is not installed. Please install PHP and try again."
    exit 1
fi

if ! command_exists git; then
    echo "Git is not installed. Please install Git and try again."
    exit 1
fi

BASE_DIR=$(pwd)

echo "Uploading PANEL folder..."
cp -r PANEL "$BASE_DIR"

echo "Running migrations..."
php artisan migrate

echo "Modifying files..."

declare -A FILE_CHANGES=(
    ["app/Http/Controllers/Admin/ServersController.php"]="'owner_id', 'external_id', 'name', 'description',"
    ["app/Http/Controllers/Api/Client/Servers/SettingsController.php"]="\$description = \$request->input('description') ?? \$server->description;"
    ["app/Http/Requests/Api/Client/Servers/Settings/RenameServerRequest.php"]="'description' => 'string|nullable',"
    ["app/Models/Server.php"]="* @property int|null \$variables_count"
    ["app/Providers/RouteServiceProvider.php"]="Route::middleware(['client-api', 'throttle:api.client'])"
    ["app/Services/Servers/DetailsModificationService.php"]="'description' => Arr::get(\$data, 'description') ?? '',"
    ["app/Services/Servers/ServerCreationService.php"]="'backup_limit' => Arr::get(\$data, 'backup_limit') ?? 0,"
    ["app/Transformers/Api/Client/ServerTransformer.php"]="'is_transferring' => !is_null(\$server->transfer),"
    ["resources/scripts/api/server/getServer.ts"]="allocations: Allocation[];"
    ["resources/scripts/api/server/renameServer.ts"]="export default (uuid: string, name: string, description?: string): Promise<void> => {"
    ["resources/scripts/components/server/console/PowerButtons.tsx"]="const instance = ServerContext.useStoreState((state) => state.socket.instance);"
    ["resources/scripts/components/server/settings/RenameServerBox.tsx"]="description: string;"
    ["resources/views/admin/servers/new.blade.php"]="<label for=\"pDescription\" class=\"control-label\">Server Description</label>"
    ["resources/views/admin/servers/view/details.blade.php"]="<label for=\"description\" class=\"control-label\">Server Description</label>"
    ["routes/admin.php"]="use Pterodactyl\\Http\\Controllers\\Admin\\MyPlugins\\DiscordController;"
    ["resources/views/layouts/admin.blade.php"]="<a href=\"{{ route('admin.nests') }}\">"
    ["routes/api-client.php"]="Route::post('/power', [Client\\Servers\\PowerController::class, 'index']);"
)

for file in "${!FILE_CHANGES[@]}"; do
    if [[ -f "$BASE_DIR/$file" ]]; then
        echo "Modifying $file..."
        sed -i "/${FILE_CHANGES[$file]}/a \\
        'webhook_url' => 'string|nullable';" "$BASE_DIR/$file"
    else
        echo "Skipping $file (not found)"
    fi
done

echo "Building panel..."
npm install && npm run build

echo "Setup complete!"
