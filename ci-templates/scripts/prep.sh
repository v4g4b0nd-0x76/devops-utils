#!/usr/bin/env bash
set -euo pipefail
REGISTRY="$1"
PROJECT="$2"

echo "[prep] Starting prep"
echo "[prep] registry=$REGISTRY project=$PROJECT"

# Fetch tags from registry, filter for semantic versioning, and get latest
echo "[prep] Fetching tags from registry"
REGISTRY_RESPONSE=$(curl -s -u "$NEXUS_USERNAME:$NEXUS_PASSWORD" "http://${REGISTRY}/v2/${PROJECT}/tags/list")
TAG_LIST=$(echo "$REGISTRY_RESPONSE" | jq -r '.tags? // [] | .[]' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || echo "")

if [[ -z "$TAG_LIST" ]]; then
  echo "[prep] No semantic tags found, starting at 1.0.0"
  VERSION="1.0.0"
else
  LATEST_TAG=$(echo "$TAG_LIST" | sort -V | tail -n1)
  echo "[prep] Latest semantic tag: $LATEST_TAG"
  MAJOR=$(cut -d. -f1 <<<"$LATEST_TAG")
  MINOR=$(cut -d. -f2 <<<"$LATEST_TAG")
  PATCH=$(cut -d. -f3 <<<"$LATEST_TAG")
  if [[ "$CI_COMMIT_BRANCH" == "master" || "$CI_COMMIT_BRANCH" == "main" ]]; then
    echo "[prep] Branch is $CI_COMMIT_BRANCH, bumping minor"
    VERSION="${MAJOR}.$((MINOR + 1)).0"
  else
    echo "[prep] Branch is $CI_COMMIT_BRANCH, bumping patch"
    VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"
  fi
fi
IMAGE_TAG="${REGISTRY}/${PROJECT}:${VERSION}"
echo "[prep] Image tag: $IMAGE_TAG"
echo "[prep] Building image"
docker build -t "$IMAGE_TAG" .
echo "[prep] Pushing image"
docker push "$IMAGE_TAG"
echo "[prep] Writing build.env"
echo "IMAGE_TAG=$IMAGE_TAG" > build.env
echo "VERSION=$VERSION" >> build.env
echo "[prep] Done"