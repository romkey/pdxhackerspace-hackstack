#!/bin/sh
set -eu
if [ -z "${VLLM_MODEL:-}" ]; then
  echo "VLLM_MODEL is required in .env (Hugging Face model id, or path inside the container)" >&2
  exit 1
fi

VLLM_USE_FLASHINFER_MOE_FP4=0
VLLM_MOE_BACKEND=marlin
VLLM_FP4_BACKEND=VLLM_CUTLASS
VLLM_MLA_DISABLE=1

pip install --upgrade mistral_common

# shellcheck disable=SC2086
exec vllm serve "$VLLM_MODEL" ${VLLM_ARGS:-}
