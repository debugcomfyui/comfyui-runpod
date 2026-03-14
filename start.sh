#!/bin/bash
set -e

echo "================================================"
echo " ComfyUI RunPod Startup - $(date)"
echo "================================================"

WORKSPACE=${WORKSPACE:-/workspace}
COMFYUI_PATH=${COMFYUI_PATH:-/workspace/ComfyUI}
VENV=/opt/venv
COMFYUI_PORT=${COMFYUI_PORT:-8188}
JUPYTER_PORT=${JUPYTER_PORT:-8888}
AUTO_UPDATE=${AUTO_UPDATE:-false}
ENABLE_JUPYTER=${ENABLE_JUPYTER:-true}
COMFYUI_EXTRA_ARGS=${COMFYUI_EXTRA_ARGS:-"--listen 0.0.0.0"}


# ── Network volume symlinks ───────────────────────────────────
if [ -d "/runpod-volume" ]; then
    echo ">>> Network volume detected, symlinking model dirs..."
    mkdir -p \
        /runpod-volume/ComfyUI/models/checkpoints \
        /runpod-volume/ComfyUI/models/vae \
        /runpod-volume/ComfyUI/models/loras \
        /runpod-volume/ComfyUI/models/controlnet \
        /runpod-volume/ComfyUI/models/embeddings \
        /runpod-volume/ComfyUI/models/upscale_models \
        /runpod-volume/ComfyUI/models/clip \
        /runpod-volume/ComfyUI/models/clip_vision \
        /runpod-volume/ComfyUI/models/unet \
        /runpod-volume/ComfyUI/models/diffusion_models \
        /runpod-volume/ComfyUI/models/text_encoders \
        /runpod-volume/ComfyUI/models/ipadapter \
        /runpod-volume/ComfyUI/input \
        /runpod-volume/ComfyUI/output

    rm -rf $COMFYUI_PATH/output $COMFYUI_PATH/input
    ln -sfn /runpod-volume/ComfyUI/output $COMFYUI_PATH/output
    ln -sfn /runpod-volume/ComfyUI/input $COMFYUI_PATH/input

    for model_dir in checkpoints vae loras controlnet embeddings upscale_models clip clip_vision unet diffusion_models text_encoders ipadapter; do
        rm -rf $COMFYUI_PATH/models/$model_dir
        ln -sfn /runpod-volume/ComfyUI/models/$model_dir $COMFYUI_PATH/models/$model_dir
    done
    echo ">>> Symlinks done"
else
    echo ">>> No network volume — models will not persist between restarts!"
fi

# ── Download models on first boot ────────────────────────────
echo ">>> Checking models..."

DIFFUSION_DIR=$COMFYUI_PATH/models/diffusion_models
TEXT_ENC_DIR=$COMFYUI_PATH/models/text_encoders
UPSCALE_DIR=$COMFYUI_PATH/models/upscale_models
LORA_DIR=$COMFYUI_PATH/models/loras

if [ ! -f "$DIFFUSION_DIR/z_image_turbo_bf16.safetensors" ]; then
    echo ">>> Downloading z_image_turbo_bf16.safetensors (~12GB)..."
    wget -q --show-progress \
        "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors" \
        -O "$DIFFUSION_DIR/z_image_turbo_bf16.safetensors"
else
    echo ">>> z_image_turbo_bf16.safetensors already exists, skipping"
fi

if [ ! -f "$TEXT_ENC_DIR/qwen_3_4b.safetensors" ]; then
    echo ">>> Downloading qwen_3_4b.safetensors (~8GB)..."
    wget -q --show-progress \
        "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors" \
        -O "$TEXT_ENC_DIR/qwen_3_4b.safetensors"
else
    echo ">>> qwen_3_4b.safetensors already exists, skipping"
fi

if [ ! -f "$UPSCALE_DIR/4xLSDIR.pth" ]; then
    echo ">>> Downloading 4xLSDIR.pth (~67MB)..."
    wget -q --show-progress \
        "https://huggingface.co/Chaewon1/upscale_models/resolve/main/4xLSDIR.pth" \
        -O "$UPSCALE_DIR/4xLSDIR.pth"
else
    echo ">>> 4xLSDIR.pth already exists, skipping"
fi

if [ ! -f "$LORA_DIR/Cookie2.safetensors" ]; then
    if [ -z "$HF_TOKEN" ]; then
        echo ">>> WARNING: HF_TOKEN not set, skipping Cookie2.safetensors"
    else
        echo ">>> Downloading Cookie2.safetensors..."
        wget --header="Authorization: Bearer ${HF_TOKEN}" \
            "https://huggingface.co/bombading/ggcook/resolve/main/Cookie2.safetensors" \
            -O "$LORA_DIR/Cookie2.safetensors" || echo ">>> WARNING: Cookie2 download failed"
    fi
else
    echo ">>> Cookie2.safetensors already exists, skipping"
fi

if [ ! -f "$LORA_DIR/GG.safetensors" ]; then
    if [ -z "$HF_TOKEN" ]; then
        echo ">>> WARNING: HF_TOKEN not set, skipping GG.safetensors"
    else
        echo ">>> Downloading GG.safetensors..."
        wget --header="Authorization: Bearer ${HF_TOKEN}" \
            "https://huggingface.co/bombading/ggcook/resolve/main/GG.safetensors" \
            -O "$LORA_DIR/GG.safetensors" || echo ">>> WARNING: GG download failed"
    fi
else
    echo ">>> GG.safetensors already exists, skipping"
fi

# ── Auto update ───────────────────────────────────────────────
if [ "$AUTO_UPDATE" = "true" ]; then
    echo ">>> Updating ComfyUI..."
    cd $COMFYUI_PATH && git pull origin master
    uv pip install -r requirements.txt --quiet
fi

# ── SSH ───────────────────────────────────────────────────────
service ssh start 2>/dev/null || /usr/sbin/sshd
[ ! -z "$SSH_PASSWORD" ] && echo "root:$SSH_PASSWORD" | chpasswd

# ── JupyterLab — no auth ──────────────────────────────────────
if [ "$ENABLE_JUPYTER" = "true" ]; then
    echo ">>> Starting JupyterLab on port $JUPYTER_PORT (no auth)..."
    jupyter lab \
        --ip=0.0.0.0 \
        --port=$JUPYTER_PORT \
        --no-browser \
        --allow-root \
        --NotebookApp.token='' \
        --NotebookApp.password='' \
        --ServerApp.token='' \
        --ServerApp.password='' \
        --notebook-dir=$WORKSPACE \
        > /var/log/jupyter.log 2>&1 &
fi

# ── ComfyUI ───────────────────────────────────────────────────
echo ">>> Starting ComfyUI on port $COMFYUI_PORT..."
cd $COMFYUI_PATH
exec python main.py --port $COMFYUI_PORT $COMFYUI_EXTRA_ARGS
