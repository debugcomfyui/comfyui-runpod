FROM senseiai/comfyui-base:latest

LABEL description="ComfyUI RunPod - CUDA 12.8, Python 3.12, custom nodes"

ENV COMFYUI_PATH=/workspace/ComfyUI \
    WORKSPACE=/workspace \
    VIRTUAL_ENV=/opt/venv \
    PATH="/root/.local/bin:/opt/venv/bin:$PATH"

# ── Clone ComfyUI ────────────────────────────────────────────
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI \
    && cd /workspace/ComfyUI && uv pip install -r requirements.txt 2>/dev/null || true

# ── Custom nodes ─────────────────────────────────────────────
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git \
    /workspace/ComfyUI/custom_nodes/ComfyUI-Manager \
    && cd /workspace/ComfyUI/custom_nodes/ComfyUI-Manager \
    && uv pip install -r requirements.txt 2>/dev/null || true

RUN git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git \
    /workspace/ComfyUI/custom_nodes/ComfyUI-Impact-Pack \
    && cd /workspace/ComfyUI/custom_nodes/ComfyUI-Impact-Pack \
    && uv pip install -r requirements.txt 2>/dev/null || true

RUN git clone https://github.com/kijai/ComfyUI-KJNodes.git \
    /workspace/ComfyUI/custom_nodes/ComfyUI-KJNodes \
    && cd /workspace/ComfyUI/custom_nodes/ComfyUI-KJNodes \
    && uv pip install -r requirements.txt 2>/dev/null || true

RUN git clone https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git \
    /workspace/ComfyUI/custom_nodes/ComfyUI_UltimateSDUpscale

RUN git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git \
    /workspace/ComfyUI/custom_nodes/ComfyUI_Comfyroll_CustomNodes

RUN git clone https://github.com/cubiq/ComfyUI_essentials.git \
    /workspace/ComfyUI/custom_nodes/ComfyUI_essentials \
    && cd /workspace/ComfyUI/custom_nodes/ComfyUI_essentials \
    && uv pip install -r requirements.txt 2>/dev/null || true

RUN git clone https://github.com/M1kep/ComfyLiterals.git \
    /workspace/ComfyUI/custom_nodes/ComfyLiterals

RUN git clone https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git \
    /workspace/ComfyUI/custom_nodes/ComfyUI_JPS-Nodes

# ── Directories ──────────────────────────────────────────────
RUN mkdir -p \
    /workspace/ComfyUI/models/checkpoints \
    /workspace/ComfyUI/models/vae \
    /workspace/ComfyUI/models/loras \
    /workspace/ComfyUI/models/controlnet \
    /workspace/ComfyUI/models/embeddings \
    /workspace/ComfyUI/models/upscale_models \
    /workspace/ComfyUI/models/clip \
    /workspace/ComfyUI/models/clip_vision \
    /workspace/ComfyUI/models/unet \
    /workspace/ComfyUI/models/diffusion_models \
    /workspace/ComfyUI/models/text_encoders \
    /workspace/ComfyUI/models/ipadapter \
    /workspace/ComfyUI/input \
    /workspace/ComfyUI/output \
    /root/.ssh

# ── SSH ──────────────────────────────────────────────────────
RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \
    && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

# ── Startup ──────────────────────────────────────────────────
COPY start.sh /start.sh
COPY config/extra_model_paths.yaml /workspace/ComfyUI/extra_model_paths.yaml
RUN chmod +x /start.sh

EXPOSE 8188 8888 22
WORKDIR /workspace
CMD ["/start.sh"]
