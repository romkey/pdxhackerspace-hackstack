# universal-silabs-flasher (experiment)

One-shot container to flash a Nabu Casa ZBT-2 (or other Silicon Labs coordinator) with [universal-silabs-flasher](https://github.com/NabuCasa/universal-silabs-flasher). Put the `.gbl` firmware file in `firmware/`, configure `.env`, then run compose once.

This is not a long-running service: `restart: "no"`.

## Configuration

```bash
cp .env.example .env
```

| Variable | Notes |
|----------|-------|
| `ZBT2_PORT` | Host serial device path (bind-mounted as `/dev/zbt2`) |
| `ZBT2_FIRMWARE` | Filename under `firmware/` |
| `USF_USE_PROFILE` | `true` uses the built-in ZBT-2 profile; `false` uses baud rates below |
| `ZBT2_BAUDRATE` / `ZBT2_BOOTLOADER_BAUDRATE` | Used when `USF_USE_PROFILE=false` |

## Usage

```bash
docker compose run --rm universal-silabs-flasher
```

Or:

```bash
docker compose up
```

The container exits after probe and flash complete.
