# ==========================================
# Stage 1: Get the TEI binary + dependencies
# ==========================================
ARG BUILDPLATFORM=linux/amd64
FROM --platform=${BUILDPLATFORM:-linux/amd64} ghcr.io/huggingface/text-embeddings-inference:cpu-1.8 AS builder

# Just in case: install curl for healthcheck in final image
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# ==========================================
# Stage 2: Minimal runtime
# ==========================================
FROM --platform=linux/amd64 debian:bookworm-slim

# Install minimal runtime deps (curl for healthcheck, Intel OpenMP for ONNX)
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl \
      ca-certificates \
      wget \
      gnupg \
    && wget -qO - https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor --output /usr/share/keyrings/intel-gpg-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/intel-gpg-keyring.gpg] https://apt.repos.intel.com/oneapi all main" > /etc/apt/sources.list.d/intel-oneapi.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends intel-oneapi-runtime-openmp \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy TEI runtime from builder
COPY --from=builder /usr/local/bin/text-embeddings-router /usr/local/bin/text-embeddings-router

# ===== Environment optimizations =====
ENV OMP_NUM_THREADS=1
ENV KMP_AFFINITY=granularity=fine,compact,1,0
ENV KMP_BLOCKTIME=0
ENV ORT_THREAD_POOL_SIZE=1
ENV MODEL_ID=janni-t/qwen3-embedding-0.6b-int8-tei-onnx
ENV RUST_LOG=info
# Use local model files instead of downloading
ENV HF_HOME=/data
ENV HUGGINGFACE_HUB_CACHE=/data

# Copy pre-downloaded model into image
COPY data /data

# Expose port
EXPOSE 80

# ===== Healthcheck =====
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f -v http://localhost:80/health || (echo "Health check failed at $(date)" && exit 1)

# ===== Final entrypoint =====
ENTRYPOINT ["/usr/local/bin/text-embeddings-router"]
CMD ["--model-id", "janni-t/qwen3-embedding-0.6b-int8-tei-onnx", \
     "--pooling", "mean", \
     "--max-batch-tokens", "128", \
     "--tokenization-workers", "1", \
     "--max-concurrent-requests", "2", \
     "--max-batch-requests", "1", \
     "--log-level", "debug", \
     "--port", "80"]