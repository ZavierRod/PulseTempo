# Railway Backend Deployment

This document describes the Railway deployment setup for the PulseTempo backend.

## Production URL

**Backend API**: `https://pulsetempo-production.up.railway.app`

### Endpoints
- **Health Check**: `GET /health` → `{"status": "healthy"}`
- **API Root**: `GET /` → `{"message": "Welcome to PulseTempo API"}`
- **Auth**: `POST /api/auth/login`, `POST /api/auth/register`
- **Tracks**: `POST /api/tracks/register`, `GET /api/tracks/{track_id}`
- **Runs**: `POST /api/runs`, `GET /api/runs`

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Railway Platform                      │
│  ┌─────────────────────┐    ┌─────────────────────────┐ │
│  │    PulseTempo       │    │       Postgres          │ │
│  │    (FastAPI)        │───▶│      (Database)         │ │
│  │    Port 8000        │    │      Port 5432          │ │
│  └─────────────────────┘    └─────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
              │
              │ HTTPS
              ▼
┌─────────────────────────────────────────────────────────┐
│                    iOS App                               │
│         (APIService.swift, AuthService.swift)           │
└─────────────────────────────────────────────────────────┘
```

---

## Environment Variables

The following environment variables are configured on the Railway PulseTempo service:

| Variable | Description |
|----------|-------------|
| `SECRET_KEY` | JWT signing key (256-bit hex) |
| `DATABASE_URL` | PostgreSQL connection string (internal) |
| `POSTGRES_SERVER` | Database host (`${{Postgres.PGHOST}}`) |
| `POSTGRES_USER` | Database user (`${{Postgres.PGUSER}}`) |
| `POSTGRES_PASSWORD` | Database password (`${{Postgres.PGPASSWORD}}`) |
| `POSTGRES_DB` | Database name (`${{Postgres.PGDATABASE}}`) |
| `POSTGRES_PORT` | Database port (`${{Postgres.PGPORT}}`) |

---

## Files Modified for Deployment

### Backend Changes

1. **`backend/app/core/security.py`**
   - Changed `SECRET_KEY` from hardcoded to `os.getenv("SECRET_KEY", ...)`

2. **`backend/app/core/config.py`**
   - Added `SECRET_KEY` to Settings class
   - Added `DATABASE_URL` support (Railway provides this)
   - `SQLALCHEMY_DATABASE_URI` now prefers `DATABASE_URL` if set

3. **`backend/Dockerfile`**
   - Removed `--reload` flag for production

### iOS Changes

4. **`PulseTempo/Services/APIService.swift`**
   - Updated `baseURL` to `https://pulsetempo-production.up.railway.app`

5. **`PulseTempo/Services/AuthService.swift`**
   - Updated `baseURL` to `https://pulsetempo-production.up.railway.app`

---

## Running Migrations

Migrations must be run using the **public** database URL (internal URLs only work within Railway's network):

```bash
cd backend

# Using the public TCP proxy
DATABASE_URL="postgresql://postgres:<PASSWORD>@centerbeam.proxy.rlwy.net:32437/railway" alembic upgrade head
```

To find the public proxy details:
```bash
railway variables --service Postgres
# Look for RAILWAY_TCP_PROXY_DOMAIN and RAILWAY_TCP_PROXY_PORT
```

---

## Local Development

For local development, the backend will fall back to localhost defaults if environment variables aren't set:

```bash
cd backend
docker-compose up --build
```

The iOS app now points to production. To test locally, temporarily change `baseURL` in `APIService.swift` and `AuthService.swift` back to:
```swift
private let baseURL: String = "http://localhost:8000"
```

---

## Railway CLI Commands

```bash
# Install CLI
brew install railway

# Login
railway login

# Link project (run from backend/)
railway link

# View variables
railway variables

# View Postgres variables
railway variables --service Postgres

# Run command with Railway env vars
railway run <command>
```

---

## Deployment Date

**Deployed**: February 4, 2026
