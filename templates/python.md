# Python Project Rules

## File Structure
- Source: `src/` or package name directory
- Tests: `tests/`
- Config: `pyproject.toml` or `setup.py`
- Requirements: `requirements.txt` or `pyproject.toml`

## Virtual Environment
```bash
python -m venv venv
source venv/bin/activate  # Linux/Mac
venv\Scripts\activate     # Windows
pip install -r requirements.txt
```

## Conventions
- Modules: snake_case (`user_service.py`)
- Classes: PascalCase (`UserService`)
- Functions/variables: snake_case (`get_user`, `user_name`)
- Constants: UPPER_SNAKE_CASE (`MAX_RETRIES`)
- Private: prefix with `_` (`_internal_method`)

## Common Patterns
```python
# Type hints
def get_user(user_id: int) -> User | None:
    pass

# Dataclass
from dataclasses import dataclass

@dataclass
class User:
    id: int
    name: str
    email: str

# Context manager
with open('file.txt', 'r') as f:
    content = f.read()

# List comprehension
active_users = [u for u in users if u.is_active]
```

## Testing
```bash
pytest                      # Run all tests
pytest tests/test_user.py   # Specific file
pytest -v                   # Verbose
pytest --cov=src            # With coverage
```

## Code Quality
```bash
black .                     # Format
ruff check .                # Lint
mypy src/                   # Type check
```
