# ============================================================
# ComfyUI RunPod Docker Image
# CUDA 12.8 + cuDNN + Ubuntu 22.04 + Python 3.12
# ============================================================

FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu22.04

LABEL description="ComfyUI on RunPod - CUDA 12.8, Python 3.12, PyTorch 2.x, uv"

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:/root/.cargo/bin:$PATH" \
    CUDA_HOME=/usr/local/cuda \
    TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0;10.0" \
    PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512 \
    CUDA_MALLOC_ASYNC=1 \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    COMFYUI_PATH=/workspace/ComfyUI \
    WORKSPACE=/workspace

# ── Step 1: base tools + deadsnakes PPA for Python 3.12 ─────
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    ca-certificates \
    curl \
    && add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update

# ── Step 2: install everything including Python 3.12 ────────
RUN apt-get install -y --no-install-recommends \
    git wget \
    python3.12 python3.12-venv python3.12-dev \
    build-essential cmake ninja-build \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender-dev \
    ffmpeg libavcodec-dev libavformat-dev libswscale-dev \
    libssl-dev rsync unzip aria2 \
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

# ── Step 3: make Python 3.12 the default ────────────────────
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

# ── Step 4: install uv ───────────────────────────────────────
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && uv --version

# ── Step 5: create virtual environment ──────────────────────
RUN python -m venv $VIRTUAL_ENV

# ── Step 6: install PyTorch + CUDA 12.8 ─────────────────────
RUN uv pip install \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu128 \
    && uv pip install \
    nvidia-nccl-cu12 \
    nvidia-cuda-nvrtc-cu12 \
    nvidia-cusparse-cu12 \
    nvidia-cublas-cu12 \
    nvidia-cufile-cu12 \
    nvidia-nvjitlink-cu12 \
    nvidia-cufft-cu12 \
    nvidia-cusparselt-cu12 \
    nvidia-cudnn-cu12 \
    nvidia-cuda-cupti-cu12 \
    nvidia-cusolver-cu12 \
    nvidia-curand-cu12 \
    triton

# ── Step 7: install ComfyUI Python dependencies ─────────────
RUN uv pip install \
    aiohttp einops transformers>=4.28.1 safetensors>=0.4.2 \
    accelerate pyyaml Pillow scipy tqdm psutil kornia spandrel \
    soundfile hf_transfer huggingface_hub jupyterlab ipywidgets \
    runpod requests GitPython packaging omegaconf

# ── Step 8: clone ComfyUI ────────────────────────────────────
RUN git clone https://github.com/comfyanonymous/ComfyUI.git $COMFYUI_PATH \
    && cd $COMFYUI_PATH && uv pip install -r requirements.txt

# ── Step 9: install ComfyUI Manager ─────────────────────────
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git \
    $COMFYUI_PATH/custom_nodes/ComfyUI-Manager \
    && cd $COMFYUI_PATH/custom_nodes/ComfyUI-Manager \
    && uv pip install -r requirements.txt 2>/dev/null || true

# ── Step 10: create directories ──────────────────────────────
RUN mkdir -p \
    $COMFYUI_PATH/models/checkpoints \
    $COMFYUI_PATH/models/vae \
    $COMFYUI_PATH/models/loras \
    $COMFYUI_PATH/models/controlnet \
    $COMFYUI_PATH/models/embeddings \
    $COMFYUI_PATH/models/upscale_models \
    $COMFYUI_PATH/models/clip \
    $COMFYUI_PATH/models/clip_vision \
    $COMFYUI_PATH/models/unet \
    $COMFYUI_PATH/models/diffusion_models \
    $COMFYUI_PATH/models/text_encoders \
    $COMFYUI_PATH/models/ipadapter \
    $COMFYUI_PATH/input \
    $COMFYUI_PATH/output \
    /root/.ssh

# ── Step 11: SSH setup ───────────────────────────────────────
RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \
    && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

# ── Step 12: copy startup files ──────────────────────────────
COPY start.sh /start.sh
COPY config/extra_model_paths.yaml $COMFYUI_PATH/extra_model_paths.yaml
RUN chmod +x /start.sh

EXPOSE 8188 8888 22
WORKDIR $WORKSPACE
CMD ["/start.sh"]
