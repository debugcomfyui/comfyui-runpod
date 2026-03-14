FROM runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04

LABEL description="ComfyUI on RunPod - CUDA 12.8.1, Python 3.11, PyTorch 2.8"

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/root/.local/bin:$PATH" \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    COMFYUI_PATH=/workspace/ComfyUI \
    WORKSPACE=/workspace

# ── uv ───────────────────────────────────────────────────────
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && ln -s /root/.local/bin/uv /usr/local/bin/uv \
    && ln -s /root/.local/bin/uvx /usr/local/bin/uvx

# ── Extra packages ────────────────────────────────────────────
RUN uv pip install --system \
    aiohttp einops transformers>=4.28.1 safetensors>=0.4.2 \
    accelerate pyyaml Pillow scipy tqdm psutil kornia spandrel \
    soundfile hf_transfer huggingface_hub \
    GitPython packaging omegaconf \
    opencv-python-headless matplotlib

# ── ComfyUI ───────────────────────────────────────────────────
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git $COMFYUI_PATH \
    && cd $COMFYUI_PATH && uv pip install --system -r requirements.txt

# ── Custom nodes (single layer) ───────────────────────────────
RUN git clone --depth=1 https://github.com/ltdrdata/ComfyUI-Manager.git \
        $COMFYUI_PATH/custom_nodes/ComfyUI-Manager \
    && git clone --depth=1 https://github.com/ltdrdata/ComfyUI-Impact-Pack.git \
        $COMFYUI_PATH/custom_nodes/ComfyUI-Impact-Pack \
    && git clone --depth=1 https://github.com/kijai/ComfyUI-KJNodes.git \
        $COMFYUI_PATH/custom_nodes/ComfyUI-KJNodes \
    && git clone --depth=1 https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git \
        $COMFYUI_PATH/custom_nodes/ComfyUI_UltimateSDUpscale \
    && git clone --depth=1 https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git \
        $COMFYUI_PATH/custom_nodes/ComfyUI_Comfyroll_CustomNodes \
    && git clone --depth=1 https://github.com/cubiq/ComfyUI_essentials.git \
        $COMFYUI_PATH/custom_nodes/ComfyUI_essentials \
    && git clone --depth=1 https://github.com/M1kep/ComfyLiterals.git \
        $COMFYUI_PATH/custom_nodes/ComfyLiterals \
    && git clone --depth=1 https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git \
        $COMFYUI_PATH/custom_nodes/ComfyUI_JPS-Nodes \
    && git clone --depth=1 https://github.com/BigStationW/ComfyUi-Scale-Image-to-Total-Pixels-Advanced.git \
        $COMFYUI_PATH/custom_nodes/ComfyUi-Scale-Image-to-Total-Pixels-Advanced \
    && git clone --depth=1 https://github.com/BigStationW/Comfyui-AD-Image-Concatenation-Advanced.git \
        $COMFYUI_PATH/custom_nodes/Comfyui-AD-Image-Concatenation-Advanced \
    && git clone --depth=1 https://github.com/BigStationW/ComfyUi-TextEncodeEditAdvanced.git \
        $COMFYUI_PATH/custom_nodes/ComfyUi-TextEncodeEditAdvanced \
    && for node in ComfyUI-Manager ComfyUI-Impact-Pack ComfyUI-KJNodes ComfyUI_essentials; do \
        [ -f $COMFYUI_PATH/custom_nodes/$node/requirements.txt ] \
        && uv pip install --system -r $COMFYUI_PATH/custom_nodes/$node/requirements.txt 2>/dev/null || true; \
    done

# ── Directories ──────────────────────────────────────────────
RUN mkdir -p \
    $COMFYUI_PATH/models/checkpoints $COMFYUI_PATH/models/vae \
    $COMFYUI_PATH/models/loras $COMFYUI_PATH/models/controlnet \
    $COMFYUI_PATH/models/embeddings $COMFYUI_PATH/models/upscale_models \
    $COMFYUI_PATH/models/clip $COMFYUI_PATH/models/clip_vision \
    $COMFYUI_PATH/models/unet $COMFYUI_PATH/models/diffusion_models \
    $COMFYUI_PATH/models/text_encoders $COMFYUI_PATH/models/ipadapter \
    $COMFYUI_PATH/input $COMFYUI_PATH/output /root/.ssh

# ── SSH ──────────────────────────────────────────────────────
RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \
    && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

# ── Startup ──────────────────────────────────────────────────
COPY start.sh /start.sh
COPY config/extra_model_paths.yaml $COMFYUI_PATH/extra_model_paths.yaml
RUN chmod +x /start.sh

EXPOSE 8188 8888 22
WORKDIR $WORKSPACE
CMD ["/start.sh"]
