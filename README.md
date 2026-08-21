# COP5725 Project — [Your Name]

## Program
[e.g., MS in Computer Science, University of Florida]

## Dataset
**Claimed dataset:** [fill in the dataset slice you claimed from student-roster.md]

**Why it interests me:** [1-3 sentences on why you picked it]

## Local Environment Setup

Installed and verified locally on macOS (Apple Silicon):

```bash
# uv (Python package/env manager)
curl -LsSf https://astral.sh/uv/install.sh | sh

# PostgreSQL 17 via Homebrew
brew install postgresql@17
brew services start postgresql@17

# Project + dependencies
uv init cop5725fa26-project
cd cop5725fa26-project
uv add psycopg duckdb pandas
```

## Semester Plan
[One-line summary of what you plan to do with this dataset across the semester]
