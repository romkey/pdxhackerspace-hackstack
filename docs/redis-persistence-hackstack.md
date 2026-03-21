# Redis persistence in this hackstack

Stacks under `apps/` that run a dedicated Redis container are tuned to **reduce SSD write wear** while staying as safe as practical.

## Policy

| Stack | Redis role | AOF | RDB | Notes |
|-------|------------|-----|-----|--------|
| **authentik** | Cache / coordination for server + worker | **off** | **off** (`save ""`) | Accept **re-login** and cold cache after unclean restart. **Removes** the previous `--save 60 1` (very write-heavy). |
| **glitchtip** | Celery broker + cache | **off** | **`save 900 1`** only | No AOF (big SSD win). At most one snapshot per **15 minutes** if keys changed. Hard crash can still lose in-flight Celery work not yet in Postgres. |
| **member-manager** | Sidekiq queue | **off** | **`save 900 1`** only | Same tradeoff as GlitchTip for **queued jobs**. |
| **event-manager** | Sidekiq queue | **off** | **`save 900 1`** only | Same as member-manager. |
| **sentry** | Queues / internal cache | **off** | **`save 900 1`** only | Same pattern; **requirepass** unchanged. |

## Why not disable RDB everywhere?

For **Celery / Sidekiq / Sentry**, Redis often holds **work not yet reflected in PostgreSQL**. Disabling **all** disk persistence (`save ""`) maximizes wear savings but increases the chance of **lost queued tasks** after a clean shutdown if the last save was stale. A **single** infrequent `save 900 1` keeps **much lower** write volume than Redis defaults (or Authentik’s old `save 60 1`) while still allowing periodic checkpoints.

## Operational notes

- After changing these settings, **restart** the Redis service (or full stack) so the new `command` applies.
- Existing `dump.rdb` files under each app’s `lib/.../redis` volume are still used on startup until removed; that’s normal.
- If you need **stronger** queue durability for one app, tighten that stack only (e.g. add `save 300 10` or enable AOF with `appendfsync everysec`) at the cost of more SSD writes.
