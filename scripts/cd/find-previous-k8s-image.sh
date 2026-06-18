#!/usr/bin/env bash
set -euo pipefail

K8S_DEPLOYMENT="${K8S_DEPLOYMENT:?K8S_DEPLOYMENT is required}"
K8S_NAMESPACE="${K8S_NAMESPACE:-default}"
CURRENT_IMAGE="${CURRENT_IMAGE:-${EXPECTED_IMAGE:-${IMAGE_TAG:-}}}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required to infer previous Kubernetes image" >&2
  exit 127
fi

replicasets_file="$(mktemp)"
trap 'rm -f "$replicasets_file"' EXIT
kubectl -n "$K8S_NAMESPACE" get replicasets -o json >"$replicasets_file"

python3 - "$K8S_DEPLOYMENT" "$CURRENT_IMAGE" "$replicasets_file" <<'PY'
import json
import sys
from pathlib import Path

deployment_name, current_image, replicasets_file = sys.argv[1:]
payload = json.loads(Path(replicasets_file).read_text(encoding="utf-8"))
replicasets = []

for item in payload.get("items", []):
    owners = item.get("metadata", {}).get("ownerReferences", [])
    if not any(owner.get("kind") == "Deployment" and owner.get("name") == deployment_name for owner in owners):
        continue
    annotations = item.get("metadata", {}).get("annotations", {})
    revision = annotations.get("deployment.kubernetes.io/revision", "0")
    try:
        revision_number = int(revision)
    except ValueError:
        revision_number = 0
    images = [
        container.get("image", "")
        for container in item.get("spec", {}).get("template", {}).get("spec", {}).get("containers", [])
        if container.get("image")
    ]
    replicasets.append({"revision": revision_number, "images": images})

for replica_set in sorted(replicasets, key=lambda item: item["revision"], reverse=True):
    for image in replica_set["images"]:
        if image and image != current_image:
            print(image)
            raise SystemExit(0)

raise SystemExit(1)
PY
