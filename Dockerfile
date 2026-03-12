# ============================================================
# ComfyUI RunPod Docker Image
# CUDA 12.4 + cuDNN 9 + Ubuntu 22.04
# Compatible with: RTX 3090/4090, A100, L40, H100, RTX 5090
# ============================================================

FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu22.04

# ── Labels ──────────────────────────────────────────────────
LABEL maintainer="your-name"
LABEL description="ComfyUI on RunPod - CUDA 12.8, PyTorch 2.x, uv"

# ── Environment ─────────────────────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    # Python venv (matches the log: /opt/venv)
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:/root/.cargo/bin:$PATH" \
    # CUDA / PyTorch tuning
    CUDA_HOME=/usr/local/cuda \
    TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0;10.0" \
    PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512 \
    CUDA_MALLOC_ASYNC=1 \
    # HuggingFace fast transfer (100-200 MB/s)
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    # ComfyUI paths
    COMFYUI_PATH=/workspace/ComfyUI \
    WORKSPACE=/workspace

# ── System dependencies ──────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update && apt-get install -y --no-install-recommends \
    # Core tools
    git wget curl ca-certificates \
    # Python
    python3.12 python3.12-venv python3.12-dev python3-pip \
    # Build tools (needed for some custom nodes)
    build-essential cmake ninja-build \
    # Image / video processing
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender-dev \
    ffmpeg libavcodec-dev libavformat-dev libswscale-dev \
    # Network / misc
    libssl-dev rsync unzip aria2 \
    # Jupyter / SSH (for pod interactive access)
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

# ── Make python3.12 the default python ──────────────────────
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

# ── Install uv (fast pip replacement, 10-100x faster) ───────
# Matches the log: "uv already installed, skipping..."
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && uv --version

# ── Create Python virtual environment ───────────────────────
# Matches the log: "Using Python 3.12.3 environment at: /opt/venv"
RUN python -m venv $VIRTUAL_ENV

# ── Install PyTorch + CUDA dependencies via uv ──────────────
# Matches the log: "Installing PyTorch dependencies..."
# Includes: torch, torchvision, torchaudio + all nvidia-* CUDA libs
RUN uv pip install \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu128 \
    && uv pip install \
    # NVIDIA extras (match the downloaded packages in your log)
    nvidia-nccl-cu12 \
    nvidia-cuda-nvrtc-cu12 \
    nvidia-cusparse-cu12 \
    nvidia-cublas-cu12 \
    nvidia-cufile-cu12 \
    nvidia-nvjitlink-cu12 \
    nvidia-cufft-cu12 \
    nvidia-cusparselt-cu12 \
    nvidia-cudnn-cu12 \
    nvidia-nvshmem-cu12 \
    nvidia-cuda-cupti-cu12 \
    nvidia-cusolver-cu12 \
    nvidia-curand-cu12 \
    triton

# ── Install ComfyUI core Python requirements ─────────────────
RUN uv pip install \
    # ComfyUI core deps
    aiohttp \
    einops \
    transformers>=4.28.1 \
    safetensors>=0.4.2 \
    accelerate \
    pyyaml \
    Pillow \
    scipy \
    tqdm \
    psutil \
    kornia \
    spandrel \
    soundfile \
    # HuggingFace fast download
    hf_transfer \
    huggingface_hub \
    # Jupyter (for RunPod interactive pod access)
    jupyterlab \
    ipywidgets \
    # RunPod SDK
    runpod \
    # Utilities
    requests \
    GitPython \
    packaging \
    omegaconf

# ── Clone ComfyUI ────────────────────────────────────────────
# Matches the log: "Cloning ComfyUI..."
# Done at build time so it's always present; start.sh can git pull to update
RUN git clone https://github.com/comfyanonymous/ComfyUI.git $COMFYUI_PATH \
    && cd $COMFYUI_PATH && pip install -r requirements.txt

# ── Install ComfyUI Manager (essential custom node manager) ──
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git \
    $COMFYUI_PATH/custom_nodes/ComfyUI-Manager \
    && cd $COMFYUI_PATH/custom_nodes/ComfyUI-Manager \
    && uv pip install -r requirements.txt

# ── Create workspace directories ─────────────────────────────
RUN mkdir -p \
    $WORKSPACE \
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

# ── SSH setup (for RunPod pod SSH access) ───────────────────
RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \
    && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

# ── Copy startup scripts ─────────────────────────────────────
COPY start.sh /start.sh
COPY config/extra_model_paths.yaml $COMFYUI_PATH/extra_model_paths.yaml

RUN chmod +x /start.sh

# ── Expose ports ─────────────────────────────────────────────
# 8188 = ComfyUI web UI
# 8888 = JupyterLab
# 22   = SSH
EXPOSE 8188 8888 22

WORKDIR $WORKSPACE

CMD ["/start.sh"]
