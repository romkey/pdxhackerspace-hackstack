#!/bin/sh
set -eu
if [ -z "${VLLM_MODEL:-}" ]; then
  echo "VLLM_MODEL is required in .env (Hugging Face model id, or path inside the container)" >&2
  exit 1
fi

pip install --upgrade mistral_common

# shellcheck disable=SC2086
exec vllm serve "$VLLM_MODEL" ${VLLM_ARGS:-}
