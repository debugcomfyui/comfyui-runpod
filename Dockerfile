FROM senseiai/comfyui-base:latest

LABEL description="ComfyUI RunPod - CUDA 12.8, Python 3.12, custom nodes"

# ── Clone ComfyUI ────────────────────────────────────────────
RUN git clone https://github.com/comfyanonymous/ComfyUI.git $COMFYUI_PATH \
    && cd $COMFYUI_PATH && uv pip install -r requirements.txt

# ── Custom nodes ─────────────────────────────────────────────
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git \
    $COMFYUI_PATH/custom_nodes/ComfyUI-Manager \
    && cd $COMFYUI_PATH/custom_nodes/ComfyUI-Manager \
    && uv pip install -r requirements.txt 2>/dev/null || true

RUN git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git \
    $COMFYUI_PATH/custom_nodes/ComfyUI-Impact-Pack \
    && cd $COMFYUI_PATH/custom_nodes/ComfyUI-Impact-Pack \
    && uv pip install -r requirements.txt 2>/dev/null || true

RUN git clone https://github.com/kijai/ComfyUI-KJNodes.git \
    $COMFYUI_PATH/custom_nodes/ComfyUI-KJNodes \
    && cd $COMFYUI_PATH/custom_nodes/ComfyUI-KJNodes \
    && uv pip install -r requirements.txt 2>/dev/null || true

RUN git clone https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git \
    $COMFYUI_PATH/custom_nodes/ComfyUI_UltimateSDUpscale

RUN git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git \
    $COMFYUI_PATH/custom_nodes/ComfyUI_Comfyroll_CustomNodes

RUN git clone https://github.com/cubiq/ComfyUI_essentials.git \
    $COMFYUI_PATH/custom_nodes/ComfyUI_essentials \
    && cd $COMFYUI_PATH/custom_nodes/ComfyUI_essentials \
    && uv pip install -r requirements.txt 2>/dev/null || true

RUN git clone https://github.com/M1kep/ComfyLiterals.git \
    $COMFYUI_PATH/custom_nodes/ComfyLiterals

RUN git clone https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git \
    $COMFYUI_PATH/custom_nodes/ComfyUI_JPS-Nodes

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
