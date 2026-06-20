#!/usr/bin/env bash
# Build the frontend/backend images and push them to ECR.
# Run from the laptop with fresh Learner Lab credentials.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="${here}/.."
tf_dir="${root}/terraform"

out="$(terraform -chdir="${tf_dir}" output -json)"
get() { echo "${out}" | python3 -c "import sys,json;print(json.load(sys.stdin)${1})"; }

ecr_front="$(get "['ecr_repository_urls']['value']['frontend']")"
ecr_back="$(get "['ecr_repository_urls']['value']['backend']")"
registry="${ecr_front%%/*}"
region="$(echo "${registry}" | cut -d. -f4)"
tag="${1:-latest}"

echo ">> Logging in to ECR (${registry})"
aws ecr get-login-password --region "${region}" \
  | docker login --username AWS --password-stdin "${registry}"

echo ">> Building and pushing frontend"
docker build -t "${ecr_front}:${tag}" "${root}/frontend"
docker push "${ecr_front}:${tag}"

echo ">> Building and pushing backend"
docker build -t "${ecr_back}:${tag}" "${root}/backend"
docker push "${ecr_back}:${tag}"

echo ">> Done. Pushed ${ecr_front}:${tag} and ${ecr_back}:${tag}"
