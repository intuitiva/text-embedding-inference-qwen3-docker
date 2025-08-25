#!/bin/bash

# Text Embeddings Qwen3 - Build and Push Script
# Usage: ./build-and-push.sh [lightsail-service-name] [region]

SERVICE_NAME=${1:-text-embeddings-service}
REGION=${2:-us-east-1}
IMAGE_NAME=text-embeddings-qwen3

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building Docker image...${NC}"
docker build -t ${IMAGE_NAME}:latest .

if [ $? -ne 0 ]; then
    echo -e "${RED}Docker build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Registering container image with Lightsail...${NC}"
aws lightsail register-container-image \
  --service-name ${SERVICE_NAME} \
  --label ${IMAGE_NAME} \
  --image ${IMAGE_NAME}:latest \
  --region ${REGION}

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to register image!${NC}"
    exit 1
fi

echo -e "${GREEN}Getting registered image...${NC}"
IMAGE_URI=$(aws lightsail get-container-images \
  --service-name ${SERVICE_NAME} \
  --region ${REGION} \
  --query "containerImages[?label=='${IMAGE_NAME}'].image" \
  --output text)

echo -e "${YELLOW}Image URI: ${IMAGE_URI}${NC}"

# Update deployment.json with actual image URI
sed "s|your-registry-uri/text-embeddings-qwen3:latest|${IMAGE_URI}|g" deployment.json > deployment-updated.json

echo -e "${GREEN}Creating deployment...${NC}"
aws lightsail create-container-service-deployment \
  --service-name ${SERVICE_NAME} \
  --containers file://deployment-updated.json \
  --public-endpoint file://public-endpoint.json \
  --region ${REGION}

echo -e "${GREEN}Deployment initiated! Check Lightsail console for status.${NC}"
