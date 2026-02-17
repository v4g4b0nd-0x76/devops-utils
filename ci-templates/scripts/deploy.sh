#!/usr/bin/env bash
set -euo pipefail

PROJECT="$1"        # e.g., iri-detector
MANAGER_HOST="$2"   # e.g., 192.168.73.21
STACK_NAME="$3"     # e.g., iri
REMOTE_STACK_PATH="$4" # e.g., /opt/iri

if [ -z "${IMAGE_TAG:-}" ]; then
  echo "[deploy] IMAGE_TAG is not set"
  exit 1
fi

echo "[deploy] Starting deploy"
echo "[deploy] project=$PROJECT manager_host=$MANAGER_HOST stack_name=$STACK_NAME remote_stack_path=$REMOTE_STACK_PATH"
echo "[deploy] image_tag=$IMAGE_TAG"

ssh -o StrictHostKeyChecking=no "runner@$MANAGER_HOST" bash -s <<EOF
  set -euo pipefail

  echo "[deploy][remote] Connected to \\$(hostname)"
  echo "[deploy][remote] Using path: $REMOTE_STACK_PATH"
  
  # Ensure the directory exists
  if [ ! -d "$REMOTE_STACK_PATH" ]; then
    echo "Directory $REMOTE_STACK_PATH not found"
    exit 1
  fi
  
  cd "$REMOTE_STACK_PATH"
  echo "[deploy][remote] Entered $REMOTE_STACK_PATH"
  
  if [ -f "stack.yaml" ]; then
    echo "[deploy][remote] stack.yaml found"
    # Pull the new image first
    echo "[deploy][remote] Pulling image: $IMAGE_TAG"
    docker pull "$IMAGE_TAG"
    
    # Use sed to find the service block and replace its image
    # It looks for the service name and replaces the next 'image:' it finds
    echo "[deploy][remote] Updating service image for: $PROJECT"
    sed -i "/$PROJECT:/,/image:/ s|image: .*|image: $IMAGE_TAG|" stack.yaml
    
    # Deploy the stack (Docker Swarm updates only the changed service)
    echo "[deploy][remote] Deploying stack: $STACK_NAME"
    docker stack deploy -c stack.yaml "$STACK_NAME"
    echo "[deploy][remote] Deploy complete"
  else
    echo "stack.yaml not found in $REMOTE_STACK_PATH"
    exit 1
  fi
EOF