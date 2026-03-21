# qdrant (experiment)

[Qdrant](https://qdrant.tech/) vector database for embeddings / semantic search.

## Configuration

Optional: add a `.env` next to `docker-compose.yml` to set **`IMAGE_VERSION`** for the image tag (see `.env.example`). If you omit `.env`, the compose default tag is used. No extra config directory is required for a default single-node setup.

## Networks

- **`qdrant-net`** — attach other services that should talk to **`qdrant`** on ports **6333** (REST) / **6334** (gRPC) inside the network.

## Usage

```bash
docker compose up -d
docker compose down
docker compose logs -f
```

Persistent storage: **`../../lib/qdrant`**.
