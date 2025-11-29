# CakePHP Project Rules

## File Structure
- Controllers: `src/Controller/`
- Models (Tables): `src/Model/Table/`
- Models (Entities): `src/Model/Entity/`
- Views: `templates/`
- Config: `config/`
- Tests: `tests/`

## Commands
```bash
# Run cake commands
bin/cake [command]

# Migrations
bin/cake migrations migrate
bin/cake migrations rollback
bin/cake migrations status

# Bake (code generation)
bin/cake bake controller [Name]
bin/cake bake model [Name]
bin/cake bake template [Name]

# Cache
bin/cake cache clear_all
```

## Conventions
- Table classes: `ArticlesTable` for `articles` table
- Entity classes: `Article` (singular)
- Controllers: `ArticlesController`
- Primary key: `id`
- Foreign keys: `article_id` (singular_table + _id)
- Timestamps: `created`, `modified`

## Common Patterns
```php
// Find with conditions
$this->Articles->find()
    ->where(['status' => 'active'])
    ->contain(['Authors', 'Tags'])
    ->order(['created' => 'DESC']);

// Save with associations
$article = $this->Articles->patchEntity($article, $data, [
    'associated' => ['Tags']
]);
$this->Articles->save($article);
```

## Testing
```bash
./vendor/bin/phpunit                    # All tests
./vendor/bin/phpunit tests/TestCase/Controller/  # Controller tests
```
