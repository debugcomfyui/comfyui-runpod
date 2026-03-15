#!/bin/bash
set -e

echo "================================================"
echo " ComfyUI RunPod Startup - $(date)"
echo "================================================"

WORKSPACE=${WORKSPACE:-/workspace}
COMFYUI_PATH=${COMFYUI_PATH:-/workspace/ComfyUI}
COMFYUI_PORT=${COMFYUI_PORT:-8188}
JUPYTER_PORT=${JUPYTER_PORT:-8888}
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
VAE_DIR=$COMFYUI_PATH/models/vae

mkdir -p $VAE_DIR

# z_image_turbo
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

# ae.safetensors (flux1 VAE)
if [ ! -f "$VAE_DIR/ae.safetensors" ]; then
    echo ">>> Downloading ae.safetensors (~335MB)..."
    wget -q --show-progress \
        "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors" \
        -O "$VAE_DIR/ae.safetensors"
else
    echo ">>> ae.safetensors already exists, skipping"
fi

# flux2-vae.safetensors
if [ ! -f "$VAE_DIR/flux2-vae.safetensors" ]; then
    echo ">>> Downloading flux2-vae.safetensors (~336MB)..."
    wget -q --show-progress \
        "https://huggingface.co/Comfy-Org/flux2-klein-9B/resolve/main/split_files/vae/flux2-vae.safetensors" \
        -O "$VAE_DIR/flux2-vae.safetensors"
else
    echo ">>> flux2-vae.safetensors already exists, skipping"
fi

# flux2 klein 9B (gated — needs HF_TOKEN + accepted license on HF)
if [ ! -f "$DIFFUSION_DIR/flux-2-klein-base-9b-fp8.safetensors" ]; then
    if [ -z "$HF_TOKEN" ]; then
        echo ">>> WARNING: HF_TOKEN not set, skipping flux-2-klein-base-9b-fp8"
    else
        echo ">>> Downloading flux-2-klein-base-9b-fp8.safetensors (~9GB)..."
        wget --header="Authorization: Bearer ${HF_TOKEN}" \
            "https://huggingface.co/black-forest-labs/FLUX.2-klein-base-9b-fp8/resolve/main/flux-2-klein-base-9b-fp8.safetensors" \
            -O "$DIFFUSION_DIR/flux-2-klein-base-9b-fp8.safetensors" || echo ">>> WARNING: flux2 klein download failed (accept license on huggingface.co first)"
    fi
else
    echo ">>> flux-2-klein-base-9b-fp8.safetensors already exists, skipping"
fi

# qwen 3 8b fp8 text encoder (for flux2 klein 9B)
if [ ! -f "$TEXT_ENC_DIR/qwen_3_8b_fp8mixed.safetensors" ]; then
    echo ">>> Downloading qwen_3_8b_fp8mixed.safetensors (~8.6GB)..."
    wget -q --show-progress \
        "https://huggingface.co/Comfy-Org/flux2-klein-9B/resolve/main/split_files/text_encoders/qwen_3_8b_fp8mixed.safetensors" \
        -O "$TEXT_ENC_DIR/qwen_3_8b_fp8mixed.safetensors"
else
    echo ">>> qwen_3_8b_fp8mixed.safetensors already exists, skipping"
fi

# Qwen Image Edit 2511 fp8
if [ ! -f "$DIFFUSION_DIR/qwen_image_edit_2511_fp8mixed.safetensors" ]; then
    echo ">>> Downloading qwen_image_edit_2511_fp8mixed.safetensors..."
    wget -q --show-progress \
        "https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors" \
        -O "$DIFFUSION_DIR/qwen_image_edit_2511_fp8mixed.safetensors"
else
    echo ">>> qwen_image_edit_2511_fp8mixed.safetensors already exists, skipping"
fi

if [ ! -f "$TEXT_ENC_DIR/qwen_2.5_vl_7b_fp8_scaled.safetensors" ]; then
    echo ">>> Downloading qwen_2.5_vl_7b_fp8_scaled.safetensors..."
    wget -q --show-progress \
        "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors" \
        -O "$TEXT_ENC_DIR/qwen_2.5_vl_7b_fp8_scaled.safetensors"
else
    echo ">>> qwen_2.5_vl_7b_fp8_scaled.safetensors already exists, skipping"
fi

if [ ! -f "$VAE_DIR/qwen_image_vae.safetensors" ]; then
    echo ">>> Downloading qwen_image_vae.safetensors..."
    wget -q --show-progress \
        "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors" \
        -O "$VAE_DIR/qwen_image_vae.safetensors"
else
    echo ">>> qwen_image_vae.safetensors already exists, skipping"
fi

# Private loras
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


# ── Qwen Image Edit 2511 Lightning 4-step LoRA ────────────────
if [ ! -f "$LORA_DIR/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors" ]; then
    echo ">>> Downloading Qwen-Image-Edit-2511 Lightning 4-step LoRA (~850MB)..."
    wget -q --show-progress \
        "https://huggingface.co/lightx2v/Qwen-Image-Edit-2511-Lightning/resolve/main/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors" \
        -O "$LORA_DIR/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors"
else
    echo ">>> Qwen-Image-Edit-2511 Lightning LoRA already exists, skipping"
fi

# ── Workflows ─────────────────────────────────────────────────
WORKFLOW_DIR=$COMFYUI_PATH/user/default/workflows
mkdir -p $WORKFLOW_DIR

if [ -z "$HF_TOKEN" ]; then
    echo ">>> WARNING: HF_TOKEN not set, skipping private workflows"
else
    if [ ! -f "$WORKFLOW_DIR/Freckles.json" ]; then
        echo ">>> Downloading Freckles.json workflow..."
        wget --header="Authorization: Bearer ${HF_TOKEN}" \
            "https://huggingface.co/bombading/ggcook/resolve/main/Freckles.json" \
            -O "$WORKFLOW_DIR/Freckles.json" || echo ">>> WARNING: Freckles.json download failed"
    fi
    if [ ! -f "$WORKFLOW_DIR/NewGG.json" ]; then
        echo ">>> Downloading NewGG.json workflow..."
        wget --header="Authorization: Bearer ${HF_TOKEN}" \
            "https://huggingface.co/bombading/ggcook/resolve/main/NewGG.json" \
            -O "$WORKFLOW_DIR/NewGG.json" || echo ">>> WARNING: NewGG.json download failed"
    fi
    if [ ! -f "$WORKFLOW_DIR/workflow_Flux2_Klein_9b.json" ]; then
        echo ">>> Downloading workflow_Flux2_Klein_9b.json workflow..."
        wget --header="Authorization: Bearer ${HF_TOKEN}" \
            "https://huggingface.co/bombading/ggcook/resolve/main/workflow_Flux2_Klein_9b%20(1).json" \
            -O "$WORKFLOW_DIR/workflow_Flux2_Klein_9b.json" || echo ">>> WARNING: Flux2 Klein workflow download failed"
    fi
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
