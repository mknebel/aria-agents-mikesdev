# Laravel Project Rules

## File Structure
- Controllers: `app/Http/Controllers/`
- Models: `app/Models/`
- Views: `resources/views/`
- Routes: `routes/web.php`, `routes/api.php`
- Migrations: `database/migrations/`
- Config: `config/`
- Tests: `tests/`

## Commands
```bash
# Artisan commands
php artisan [command]

# Migrations
php artisan migrate
php artisan migrate:rollback
php artisan migrate:fresh --seed

# Make (code generation)
php artisan make:controller ArticleController
php artisan make:model Article -m  # with migration
php artisan make:request ArticleRequest

# Cache
php artisan cache:clear
php artisan config:clear
php artisan view:clear
```

## Conventions
- Models: `Article` (singular, PascalCase)
- Tables: `articles` (plural, snake_case)
- Controllers: `ArticleController`
- Primary key: `id`
- Foreign keys: `article_id`
- Timestamps: `created_at`, `updated_at`

## Common Patterns
```php
// Eloquent queries
Article::where('status', 'active')
    ->with(['author', 'tags'])
    ->orderBy('created_at', 'desc')
    ->paginate(15);

// Validation in controller
$validated = $request->validate([
    'title' => 'required|max:255',
    'body' => 'required',
]);
```

## Testing
```bash
php artisan test                    # All tests
php artisan test --filter=ArticleTest  # Specific test
```
