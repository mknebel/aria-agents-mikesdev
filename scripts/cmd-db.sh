#!/bin/bash
# cmd-db.sh - Database operations
ACTION="${1:-status}"

# Detect framework
if [[ -f "bin/cake" || -f "bin/cake.php" ]]; then
    FW="cake"; CMD="bin/cake"
    [[ -f "bin/cake.php" ]] && CMD="bin/cake.php"
elif [[ -f "artisan" ]]; then FW="laravel"
elif [[ -f "manage.py" ]]; then FW="django"
elif [[ -f "prisma/schema.prisma" ]]; then FW="prisma"
elif [[ -f "drizzle.config.ts" || -f "drizzle.config.js" ]]; then FW="drizzle"
elif [[ -f "knexfile.js" ]]; then FW="knex"
else echo "No DB framework detected"; exit 1; fi

echo "=== DB: $ACTION ($FW) ==="

case "$FW:$ACTION" in
    cake:status)   $CMD migrations status ;;
    cake:migrate)  $CMD migrations migrate ;;
    cake:rollback) $CMD migrations rollback ;;
    cake:seed)     $CMD migrations seed ;;
    laravel:status)   php artisan migrate:status ;;
    laravel:migrate)  php artisan migrate ;;
    laravel:rollback) php artisan migrate:rollback ;;
    laravel:seed)     php artisan db:seed ;;
    laravel:fresh)    php artisan migrate:fresh --seed ;;
    django:status)   python manage.py showmigrations ;;
    django:migrate)  python manage.py migrate ;;
    prisma:status)   npx prisma migrate status ;;
    prisma:migrate)  npx prisma migrate dev ;;
    prisma:seed)     npx prisma db seed ;;
    prisma:fresh)    npx prisma migrate reset ;;
    drizzle:*)       npx drizzle-kit "$ACTION" ;;
    knex:status)     npx knex migrate:status ;;
    knex:migrate)    npx knex migrate:latest ;;
    knex:rollback)   npx knex migrate:rollback ;;
    knex:seed)       npx knex seed:run ;;
    *) echo "Unknown: $FW:$ACTION" ;;
esac
