#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${ROOT_DIR}/lab2-research"
RESULTS_DIR="${ROOT_DIR}/lab2-results"

PY_REPO_URL="https://github.com/KPI-FICT-MTSD/lab-03-starter-project-python"
GO_REPO_URL="https://github.com/comsys-kpi-ua/deploy.lab-containers-starter-project-golang"

ENABLE_NUMPY="${ENABLE_NUMPY:-0}"

mkdir -p "${WORK_DIR}" "${RESULTS_DIR}"

METRICS_FILE="${RESULTS_DIR}/metrics.csv"
DNS_FILE="${RESULTS_DIR}/dns_test.txt"

printf "tag,context,dockerfile,seconds,image_bytes,image_human\n" > "${METRICS_FILE}"

run_build() {
  local tag="$1"
  local context="$2"
  local dockerfile="$3"

  if [[ ! -f "${dockerfile}" ]]; then
    echo "SKIP: Dockerfile not found: ${dockerfile}" | tee -a "${DNS_FILE}"
    return
  fi

  local time_file
  time_file="$(mktemp)"
  /usr/bin/time -p -o "${time_file}" docker build -t "${tag}" -f "${dockerfile}" "${context}"

  local seconds
  seconds="$(awk '/^real/ {print $2}' "${time_file}")"

  local bytes
  bytes="$(docker image inspect "${tag}" --format '{{.Size}}')"

  local human
  human="$(docker image ls "${tag}" --format '{{.Size}}')"

  printf "%s,%s,%s,%s,%s,%s\n" "${tag}" "${context}" "${dockerfile}" "${seconds}" "${bytes}" "${human}" >> "${METRICS_FILE}"
  rm -f "${time_file}"
}

append_marker_once() {
  local file_path="$1"
  local marker="$2"
  local text="$3"

  if [[ ! -f "${file_path}" ]]; then
    return
  fi

  if ! grep -q "${marker}" "${file_path}"; then
    printf "\n%s\n%s\n" "${marker}" "${text}" >> "${file_path}"
  fi
}

ensure_repo() {
  local url="$1"
  local dir="$2"

  if [[ ! -d "${dir}/.git" ]]; then
    git clone "${url}" "${dir}"
  else
    git -C "${dir}" pull --ff-only || true
  fi
}

# ---- Python project ----
PY_DIR="${WORK_DIR}/lab-03-starter-project-python"
ensure_repo "${PY_REPO_URL}" "${PY_DIR}"

run_build "lab2-python:base" "${PY_DIR}" "${PY_DIR}/Dockerfile"

if [[ -f "${PY_DIR}/build/index.html" ]]; then
  append_marker_once "${PY_DIR}/build/index.html" "<!-- lab2-change -->" "<!-- added for lab2 -->"
elif [[ -f "${PY_DIR}/spaceship/app.py" ]]; then
  append_marker_once "${PY_DIR}/spaceship/app.py" "# lab2-change" "# added for lab2"
fi

run_build "lab2-python:change" "${PY_DIR}" "${PY_DIR}/Dockerfile"

if [[ -f "${PY_DIR}/Dockerfile.optimized" ]]; then
  run_build "lab2-python:optimized" "${PY_DIR}" "${PY_DIR}/Dockerfile.optimized"
else
  echo "SKIP: Dockerfile.optimized not found" | tee -a "${DNS_FILE}"
fi

if [[ -f "${PY_DIR}/Dockerfile.alpine" ]]; then
  run_build "lab2-python:alpine" "${PY_DIR}" "${PY_DIR}/Dockerfile.alpine"
else
  echo "SKIP: Dockerfile.alpine not found" | tee -a "${DNS_FILE}"
fi

if [[ "${ENABLE_NUMPY}" == "1" ]]; then
  if [[ -f "${PY_DIR}/requirements.txt" ]]; then
    if ! grep -q "^numpy" "${PY_DIR}/requirements.txt"; then
      printf "\nnumpy\n" >> "${PY_DIR}/requirements.txt"
    fi
  fi

  if [[ -f "${PY_DIR}/spaceship/routers/api.py" ]]; then
    append_marker_once "${PY_DIR}/spaceship/routers/api.py" "# lab2-numpy" "\nimport numpy as np\n\n@router.get(\"/matrix\")\ndef matrix():\n    a = np.random.rand(10, 10)\n    b = np.random.rand(10, 10)\n    product = a @ b\n    return {\n        \"matrix_a\": a.tolist(),\n        \"matrix_b\": b.tolist(),\n        \"product\": product.tolist(),\n    }\n"
  fi

  if [[ -f "${PY_DIR}/Dockerfile" ]]; then
    run_build "lab2-python:numpy" "${PY_DIR}" "${PY_DIR}/Dockerfile"
  fi

  if [[ -f "${PY_DIR}/Dockerfile.alpine" ]]; then
    run_build "lab2-python:numpy-alpine" "${PY_DIR}" "${PY_DIR}/Dockerfile.alpine"
  fi
fi

# ---- DNS test (musl vs glibc) ----
{
  echo "DNS test started: $(date -Iseconds)"
  if ! docker network inspect dns-lab >/dev/null 2>&1; then
    docker network create dns-lab >/dev/null
  fi

  docker run -d --rm --name dns-server --network dns-lab \
    alpine sh -c "apk add --no-cache dnsmasq >/dev/null && \
    echo 'address=/myservice.internal.corp/10.0.0.50' > /etc/dnsmasq.conf && \
    dnsmasq -k --log-queries --log-facility=-" >/dev/null

  DNS_IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server)"

  echo "Ubuntu result:"
  docker run --rm --network dns-lab \
    --dns="${DNS_IP}" --dns-search="corp" \
    ubuntu:latest getent hosts myservice.internal || true

  echo "Alpine result:"
  docker run --rm --network dns-lab \
    --dns="${DNS_IP}" --dns-search="corp" \
    alpine:latest getent hosts myservice.internal || true

  echo "DNS logs:"
  docker logs dns-server || true

  docker stop dns-server >/dev/null
  echo "DNS test completed: $(date -Iseconds)"
} > "${DNS_FILE}" 2>&1

# ---- Golang project ----
GO_DIR="${WORK_DIR}/deploy.lab-containers-starter-project-golang"
ensure_repo "${GO_REPO_URL}" "${GO_DIR}"

run_build "lab2-go:base" "${GO_DIR}" "${GO_DIR}/Dockerfile"

if [[ -f "${GO_DIR}/Dockerfile.scratch" ]]; then
  run_build "lab2-go:scratch" "${GO_DIR}" "${GO_DIR}/Dockerfile.scratch"
else
  echo "SKIP: Dockerfile.scratch not found" | tee -a "${DNS_FILE}"
fi

if [[ -f "${GO_DIR}/Dockerfile.distroless" ]]; then
  run_build "lab2-go:distroless" "${GO_DIR}" "${GO_DIR}/Dockerfile.distroless"
else
  echo "SKIP: Dockerfile.distroless not found" | tee -a "${DNS_FILE}"
fi

echo "Done. Metrics: ${METRICS_FILE}"
echo "DNS logs: ${DNS_FILE}"

