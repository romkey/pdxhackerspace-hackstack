#!/usr/bin/env bash
# Create the shared Docker macvlan network (lan_macvlan) from live host routing.
# Does not guess the parent NIC when more than one candidate exists.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
    cat <<'EOF'
Usage: create-macvlan.sh [options]

Create the shared macvlan Docker network used by docker-compose.macvlan.yml overlays.

Options:
  -n, --name NAME     Docker network name (default: lan_macvlan, or LAN_NET_NAME from env)
  -y, --yes           Skip final confirmation before docker network create
  -f, --force         Remove an existing network with the same name, then recreate
  -h, --help          Show this help

Environment (optional overrides):
  LAN_NET_NAME, MACVLAN_PARENT, MACVLAN_SUBNET, MACVLAN_GATEWAY, MACVLAN_IP_RANGE

After creation, add the printed MACVLAN_* block to each macvlan app's .env and enable:
  COMPOSE_FILE=docker-compose.yml:docker-compose.macvlan.yml

See docs/macvlan.md
EOF
}

LAN_NET_NAME="${LAN_NET_NAME:-lan_macvlan}"
ASSUME_YES=0
FORCE=0

while [ $# -gt 0 ]; do
    case "$1" in
        -n | --name)
            LAN_NET_NAME="${2:?}"
            shift 2
            ;;
        -y | --yes)
            ASSUME_YES=1
            shift
            ;;
        -f | --force)
            FORCE=1
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if ! command -v docker >/dev/null 2>&1; then
    echo "docker not found in PATH" >&2
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "docker daemon not reachable" >&2
    exit 1
fi

if ! command -v ip >/dev/null 2>&1; then
    echo "ip(8) from iproute2 is required (this script targets Linux hosts)" >&2
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required to derive subnet CIDR" >&2
    exit 1
fi

_is_virtual_iface() {
    local iface="$1"
    case "$iface" in
        lo | docker0 | podman0 | tunl0 | sit0 | cni0)
            return 0
            ;;
    esac
    case "$iface" in
        veth* | br-* | virbr* | docker* | flannel* | cali* | cilium* | tailscale*)
            return 0
            ;;
    esac
    return 1
}

# iface|caddr|gateway|is_default_route
discover_candidates() {
    local default_dev
    default_dev="$(ip -4 route show default 2>/dev/null | awk '{print $5; exit}')"

    ip -4 -o addr show scope global 2>/dev/null | while read -r _num iface _family cidr _rest; do
        if _is_virtual_iface "$iface"; then
            continue
        fi
        # Skip pointopoint / secondary lines without treating as duplicate iface entries
        if [ -z "${cidr:-}" ] || [ "${cidr#*/}" = "$cidr" ]; then
            continue
        fi
        gw="$(ip -4 route show dev "$iface" 2>/dev/null | awk '/^default / {print $3; exit}')"
        if [ -z "$gw" ]; then
            gw="$(ip -4 route show default 2>/dev/null | awk -v d="$iface" '$5 == d {print $3; exit}')"
        fi
        is_def=0
        if [ -n "$default_dev" ] && [ "$iface" = "$default_dev" ]; then
            is_def=1
        fi
        printf '%s|%s|%s|%s\n' "$iface" "$cidr" "${gw:-}" "$is_def"
    done | awk -F'|' '!seen[$1]++'
}

mapfile -t RAW_CANDIDATES < <(discover_candidates)

if [ "${#RAW_CANDIDATES[@]}" -eq 0 ]; then
    echo "No suitable IPv4 interfaces found (need a global address on a non-virtual NIC)." >&2
    exit 1
fi

pick_iface() {
    if [ -n "${MACVLAN_PARENT:-}" ]; then
        local found=0
        for row in "${RAW_CANDIDATES[@]}"; do
            IFS='|' read -r iface _ _ _ <<<"$row"
            if [ "$iface" = "$MACVLAN_PARENT" ]; then
                found=1
                break
            fi
        done
        if [ "$found" -eq 0 ]; then
            echo "MACVLAN_PARENT=$MACVLAN_PARENT is not among detected IPv4 interfaces:" >&2
            for row in "${RAW_CANDIDATES[@]}"; do
                IFS='|' read -r iface cidr gw is_def <<<"$row"
                echo "  - $iface ($cidr)" >&2
            done
            exit 1
        fi
        echo "$MACVLAN_PARENT"
        return
    fi

    if [ "${#RAW_CANDIDATES[@]}" -eq 1 ]; then
        IFS='|' read -r iface cidr gw is_def <<<"${RAW_CANDIDATES[0]}"
        echo "Detected one IPv4-capable interface:" >&2
        echo "  $iface  $cidr  gateway: ${gw:-unknown}${is_def:+  (default route)}" >&2
        if [[ "$iface" == wl* ]]; then
            echo "  Warning: Wi-Fi parent interfaces often fail with macvlan; prefer wired Ethernet." >&2
        fi
        if [ "$ASSUME_YES" -eq 0 ]; then
            read -r -p "Use $iface as MACVLAN_PARENT? [y/N] " ans
            case "$ans" in
                y | Y | yes | YES) ;;
                *)
                    echo "Aborted."
                    exit 1
                    ;;
            esac
        fi
        echo "$iface"
        return
    fi

    echo "Multiple IPv4 interfaces found; pick the wired LAN NIC (macvlan parent):" >&2
    local i=1
    for row in "${RAW_CANDIDATES[@]}"; do
        IFS='|' read -r iface cidr gw is_def <<<"$row"
        local tag=""
        [ "$is_def" = "1" ] && tag="  [default route]"
        [[ "$iface" == wl* ]] && tag="$tag  [wireless — often unsuitable]"
        echo "  $i) $iface  $cidr  gateway: ${gw:-?}$tag" >&2
        i=$((i + 1))
    done
    while true; do
        read -r -p "Enter number (1-${#RAW_CANDIDATES[@]}): " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#RAW_CANDIDATES[@]}" ]; then
            IFS='|' read -r iface _ _ _ <<<"${RAW_CANDIDATES[$((choice - 1))]}"
            echo "$iface"
            return
        fi
        echo "Invalid choice." >&2
    done
}

PARENT="$(pick_iface)"

ROW=""
for r in "${RAW_CANDIDATES[@]}"; do
    IFS='|' read -r iface _ _ _ <<<"$r"
    if [ "$iface" = "$PARENT" ]; then
        ROW="$r"
        break
    fi
done

IFS='|' read -r _ CIDR DETECTED_GW _ <<<"$ROW"

if [ -z "${MACVLAN_SUBNET:-}" ] || [ -z "${MACVLAN_GATEWAY:-}" ]; then
    eval "$(python3 - "$CIDR" "$DETECTED_GW" <<'PY'
import ipaddress, sys
cidr = sys.argv[1]
gw_hint = sys.argv[2]
iface = ipaddress.ip_interface(cidr)
net = iface.network
gw = gw_hint.strip() if gw_hint else ""
if not gw:
    gw = str(next(ipaddress.ip_network(net).hosts()))
subnet = str(net)
print(f'MACVLAN_SUBNET="{subnet}"')
print(f'MACVLAN_GATEWAY="{gw}"')
PY
)"
fi

MACVLAN_IP_RANGE="${MACVLAN_IP_RANGE:-$MACVLAN_SUBNET}"

if docker network inspect "$LAN_NET_NAME" >/dev/null 2>&1; then
    if [ "$FORCE" -eq 0 ]; then
        echo "Docker network '$LAN_NET_NAME' already exists." >&2
        docker network inspect "$LAN_NET_NAME" --format '  parent={{index .Options "parent"}}  subnet={{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || true
        echo "Use --force to remove and recreate, or pick a different name with -n." >&2
        exit 1
    fi
    echo "Removing existing network $LAN_NET_NAME (--force)..." >&2
    docker network rm "$LAN_NET_NAME"
fi

echo ""
echo "Will create macvlan network:"
echo "  name:     $LAN_NET_NAME"
echo "  parent:   $PARENT"
echo "  subnet:   $MACVLAN_SUBNET"
echo "  gateway:  $MACVLAN_GATEWAY"
echo "  ip-range: $MACVLAN_IP_RANGE"
echo ""

if [ "$ASSUME_YES" -eq 0 ]; then
    read -r -p "Create this network? [y/N] " ans
    case "$ans" in
        y | Y | yes | YES) ;;
        *)
            echo "Aborted."
            exit 1
            ;;
    esac
fi

docker network create -d macvlan \
    -o "parent=${PARENT}" \
    --subnet="${MACVLAN_SUBNET}" \
    --gateway="${MACVLAN_GATEWAY}" \
    --ip-range="${MACVLAN_IP_RANGE}" \
    "$LAN_NET_NAME"

echo ""
echo "Created $LAN_NET_NAME"
echo ""
echo "Add to each macvlan app .env (unique IPV4_ADDRESS / LAN_MAC_ADDRESS per app):"
echo ""
cat <<EOF
LAN_NET_NAME=${LAN_NET_NAME}
MACVLAN_PARENT=${PARENT}
MACVLAN_SUBNET=${MACVLAN_SUBNET}
MACVLAN_GATEWAY=${MACVLAN_GATEWAY}
MACVLAN_IP_RANGE=${MACVLAN_IP_RANGE}
# COMPOSE_FILE=docker-compose.yml:docker-compose.macvlan.yml
# IPV4_ADDRESS=
# LAN_MAC_ADDRESS=
EOF
echo ""
echo "Reference: $REPO_ROOT/docs/macvlan.md"
