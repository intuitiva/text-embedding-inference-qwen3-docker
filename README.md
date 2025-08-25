# Text Embeddings Inference - Qwen3 Docker Container

This repository contains a Docker container for running Qwen3 text embeddings inference optimized for AWS Lightsail with under 1GB RAM usage.

## Quick Start

### Building
```bash
# Run the image first so you can create the data folder
docker run --platform linux/amd64 -p 8080:80 -v $PWD/data:/data -e OMP_NUM_THREADS=1 -e KMP_AFFINITY=granularity=fine,compact,1,0 -e ORT_THREAD_POOL_SIZE=1 ghcr.io/huggingface/text-embeddings-inference:cpu-1.8 --model-id janni-t/qwen3-embedding-0.6b-int8-tei-onnx --pooling mean --max-batch-tokens 1024 --tokenization-workers 1

# exit the server with control + c

# Build the image
docker build -t text-embeddings-qwen3 .
```

### Running Locally
```bash
docker run --platform linux/amd64 -p 8080:80 text-embeddings-qwen3
```

## AWS Lightsail Deployment

### Prerequisites
- AWS CLI installed and configured
- Docker installed
- Lightsail container service created

### Step 1: Build and Tag Image
```bash
# Build the image
docker build -t text-embeddings-qwen3:latest .

# Tag for Lightsail registry
docker tag text-embeddings-qwen3:latest your-registry-uri/text-embeddings-qwen3:latest
```

### Step 2: Push to Lightsail Container Registry
```bash
# Register container image with Lightsail
aws lightsail register-container-image \
  --service-name text-embeddings-qwen3 \
  --label text-embeddings-qwen3 \
  --image text-embeddings-qwen3:latest
```

### Step 3: Deploy to Lightsail
Create deployment configuration files:

**deployment.json**
```json
{
  "text-embeddings": {
    "image": "your-registry-uri/text-embeddings-qwen3:latest",
    "ports": {
      "80": "HTTP"
    },
    "environment": {
      "OMP_NUM_THREADS": "1",
      "KMP_AFFINITY": "granularity=fine,compact,1,0",
      "ORT_THREAD_POOL_SIZE": "1"
    }
  }
}
```

**public-endpoint.json**
```json
{
  "containerName": "text-embeddings",
  "containerPort": 80,
  "healthCheck": {
    "healthyThreshold": 2,
    "unhealthyThreshold": 2,
    "timeoutSeconds": 5,
    "intervalSeconds": 30,
    "path": "/health",
    "successCodes": "200"
  }
}
```

Deploy:
```bash
aws lightsail create-container-service-deployment \
  --service-name your-service-name \
  --containers file://deployment.json \
  --public-endpoint file://public-endpoint.json
```

### Step 4: Verify Deployment
```bash
# Get public endpoint
aws lightsail get-container-services --service-name your-service-name

# Test the endpoint
curl http://YOUR_PUBLIC_ENDPOINT/health

# Test embeddings
curl -X POST http://YOUR_PUBLIC_ENDPOINT/embed \
  -H "Content-Type: application/json" \
  -d '{"inputs": ["Hello world"]}'
```

## Memory Optimization
This container is optimized for under 1GB RAM usage with:
- Limited thread counts
- Reduced batch processing size
- Optimized ONNX runtime settings

## API Usage
- Health check: GET /health
- Generate embeddings: POST /embed
