---
description: Database operations (migrations, seeds, status)
allowed-tools: Bash
---

Run database operations. Usage: /db [status|migrate|rollback|seed|fresh]

```bash
ACTION="${1:-status}"

echo "=== Database: $ACTION ==="

# Detect framework
if [[ -f "bin/cake" ]] || [[ -f "bin/cake.php" ]]; then
    FRAMEWORK="cakephp"
    CAKE="bin/cake"
    [[ -f "bin/cake.php" ]] && CAKE="bin/cake.php"
elif [[ -f "artisan" ]]; then
    FRAMEWORK="laravel"
elif [[ -f "manage.py" ]]; then
    FRAMEWORK="django"
elif [[ -f "prisma/schema.prisma" ]]; then
    FRAMEWORK="prisma"
elif [[ -f "drizzle.config.ts" ]] || [[ -f "drizzle.config.js" ]]; then
    FRAMEWORK="drizzle"
elif [[ -f "knexfile.js" ]]; then
    FRAMEWORK="knex"
else
    echo "No supported database framework detected."
    echo "Supported: CakePHP, Laravel, Django, Prisma, Drizzle, Knex"
    exit 1
fi

echo "Framework: $FRAMEWORK"
echo ""

case "$FRAMEWORK" in
    cakephp)
        case "$ACTION" in
            status)   $CAKE migrations status ;;
            migrate)  $CAKE migrations migrate ;;
            rollback) $CAKE migrations rollback ;;
            seed)     $CAKE migrations seed ;;
            fresh)    echo "CakePHP: Drop and recreate manually or use migrations rollback + migrate" ;;
        esac
        ;;
    laravel)
        case "$ACTION" in
            status)   php artisan migrate:status ;;
            migrate)  php artisan migrate ;;
            rollback) php artisan migrate:rollback ;;
            seed)     php artisan db:seed ;;
            fresh)    php artisan migrate:fresh --seed ;;
        esac
        ;;
    django)
        case "$ACTION" in
            status)   python manage.py showmigrations ;;
            migrate)  python manage.py migrate ;;
            rollback) echo "Django: Specify app and migration to rollback" ;;
            seed)     python manage.py loaddata ;;
            fresh)    python manage.py flush && python manage.py migrate ;;
        esac
        ;;
    prisma)
        case "$ACTION" in
            status)   npx prisma migrate status ;;
            migrate)  npx prisma migrate dev ;;
            rollback) echo "Prisma: Use prisma migrate reset or manual rollback" ;;
            seed)     npx prisma db seed ;;
            fresh)    npx prisma migrate reset ;;
        esac
        ;;
    drizzle)
        case "$ACTION" in
            status)   npx drizzle-kit status ;;
            migrate)  npx drizzle-kit migrate ;;
            *)        echo "Drizzle: Use drizzle-kit commands" ;;
        esac
        ;;
    knex)
        case "$ACTION" in
            status)   npx knex migrate:status ;;
            migrate)  npx knex migrate:latest ;;
            rollback) npx knex migrate:rollback ;;
            seed)     npx knex seed:run ;;
            fresh)    npx knex migrate:rollback --all && npx knex migrate:latest ;;
        esac
        ;;
esac
```
