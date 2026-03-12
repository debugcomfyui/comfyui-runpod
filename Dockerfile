FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu22.04

LABEL description="ComfyUI on RunPod - CUDA 12.8, Python 3.12, PyTorch 2.x, uv"

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH="/root/.local/bin:/opt/venv/bin:$PATH" \
    CUDA_HOME=/usr/local/cuda \
    TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0;10.0" \
    PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512 \
    CUDA_MALLOC_ASYNC=1 \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    COMFYUI_PATH=/workspace/ComfyUI \
    WORKSPACE=/workspace

RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common ca-certificates curl \
    && add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    git wget \
    python3.12 python3.12-venv python3.12-dev \
    build-essential cmake ninja-build \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender-dev \
    ffmpeg libavcodec-dev libavformat-dev libswscale-dev \
    libssl-dev rsync unzip aria2 \
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && ln -s /root/.local/bin/uv /usr/local/bin/uv \
    && ln -s /root/.local/bin/uvx /usr/local/bin/uvx \
    && uv --version

RUN python -m venv $VIRTUAL_ENV

RUN uv pip install \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu128 \
    && uv pip install \
    nvidia-nccl-cu12 nvidia-cuda-nvrtc-cu12 nvidia-cusparse-cu12 \
    nvidia-cublas-cu12 nvidia-cufile-cu12 nvidia-nvjitlink-cu12 \
    nvidia-cufft-cu12 nvidia-cusparselt-cu12 nvidia-cudnn-cu12 \
    nvidia-cuda-cupti-cu12 nvidia-cusolver-cu12 nvidia-curand-cu12 triton

RUN uv pip install \
    aiohttp einops transformers>=4.28.1 safetensors>=0.4.2 \
    accelerate pyyaml Pillow scipy tqdm psutil kornia spandrel \
    soundfile hf_transfer huggingface_hub jupyterlab ipywidgets \
    runpod requests GitPython packaging omegaconf \
    opencv-python-headless matplotlib

RUN git clone https://github.com/comfyanonymous/ComfyUI.git $COMFYUI_PATH \
    && cd $COMFYUI_PATH && uv pip install -r requirements.txt

# ── ComfyUI Manager ──────────────────────────────────────────
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git \
    $COMFYUI_PATH/custom_nodes/ComfyUI-Manager \
    && cd $COMFYUI_PATH/custom_nodes/ComfyUI-Manager \
    && uv pip install -r requirements.txt 2>/dev/null || true

# ── Impact Pack ──────────────────────────────────────────────
RUN git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git \
    $COMFYUI_PATH/custom_nodes/ComfyUI-Impact-Pack \
    && cd $COMFYUI_PATH/custom_nodes/ComfyUI-Impact-Pack \
    && uv pip install -r requirements.txt 2>/dev/null || true

# ── KJNodes ──────────────────────────────────────────────────
RUN git clone https://github.com/kijai/ComfyUI-KJNodes.git \
    $COMFYUI_PATH/custom_nodes/ComfyUI-KJNodes \
    && cd $COMFYUI_PATH/custom_nodes/ComfyUI-KJNodes \
    && uv pip install -r requirements.txt 2>/dev/null || true

# ── UltimateSDUpscale ────────────────────────────────────────
RUN git clone https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git \
    $COMFYUI_PATH/custom_nodes/ComfyUI_UltimateSDUpscale

# ── Comfyroll Studio ─────────────────────────────────────────
RUN git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git \
    $COMFYUI_PATH/custom_nodes/ComfyUI_Comfyroll_CustomNodes

# ── ComfyUI Essentials ───────────────────────────────────────
RUN git clone https://github.com/cubiq/ComfyUI_essentials.git \
    $COMFYUI_PATH/custom_nodes/ComfyUI_essentials \
    && cd $COMFYUI_PATH/custom_nodes/ComfyUI_essentials \
    && uv pip install -r requirements.txt 2>/dev/null || true

# ── ComfyLiterals ────────────────────────────────────────────
RUN git clone https://github.com/M1kep/ComfyLiterals.git \
    $COMFYUI_PATH/custom_nodes/ComfyLiterals

# ── JPS Custom Nodes ─────────────────────────────────────────
RUN git clone https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git \
    $COMFYUI_PATH/custom_nodes/ComfyUI_JPS-Nodes

RUN mkdir -p \
    $COMFYUI_PATH/models/checkpoints $COMFYUI_PATH/models/vae \
    $COMFYUI_PATH/models/loras $COMFYUI_PATH/models/controlnet \
    $COMFYUI_PATH/models/embeddings $COMFYUI_PATH/models/upscale_models \
    $COMFYUI_PATH/models/clip $COMFYUI_PATH/models/clip_vision \
    $COMFYUI_PATH/models/unet $COMFYUI_PATH/models/diffusion_models \
    $COMFYUI_PATH/models/text_encoders $COMFYUI_PATH/models/ipadapter \
    $COMFYUI_PATH/input $COMFYUI_PATH/output /root/.ssh

RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \
    && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

COPY start.sh /start.sh
COPY config/extra_model_paths.yaml $COMFYUI_PATH/extra_model_paths.yaml
RUN chmod +x /start.sh

EXPOSE 8188 8888 22
WORKDIR $WORKSPACE
CMD ["/start.sh"]
