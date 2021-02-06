#!/bin/bash -ev
# TravisCI Docker Build and Publish Script

# Ensure all required environment variables are present
if [ -z "$DOCKER_IMAGE_NAME" ] || \
    [ -z "$DOCKER_USERNAME" ] || \
    [ -z "$DOCKER_PASSWORD" ]; then
    >&2 echo 'Required variable unset, automerging failed'
    exit 1
fi

echo : "
Travis-ci docker build and publishscript
Repo: $TRAVIS_REPO_SLUG
Image: $DOCKER_IMAGE_NAME
"

# Create unique tag from git hash for versioning
branch_head_commit=$(git rev-parse --short=10 HEAD)
image_commit_tag="$DOCKER_IMAGE_NAME_BASE:$branch_head_commit"

# Pull latest app image to cache from ( || true to catch errors if not in registery)
echo "Pulling latest $DOCKER_IMAGE_NAME"
docker pull "$DOCKER_IMAGE_NAME" || true

# Build image (add additional tags here)
echo "Building Image: $DOCKER_IMAGE_NAME"
docker build \
    --cache-from "$DOCKER_IMAGE_NAME" \
    -t "$DOCKER_IMAGE_NAME:latest" \
    -t "$image_commit_tag" \
    .

# Login to docker
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin >/dev/null 2>&1

# Publish to dockerhub (pushes all tags)
echo 'Pushing images to docker'
docker push "$DOCKER_IMAGE_NAME" 
