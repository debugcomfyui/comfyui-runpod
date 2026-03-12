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

source $VENV/bin/activate

# ── Network volume symlinks ──────────────────────────────────
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

# ── Auto update ──────────────────────────────────────────────
if [ "$AUTO_UPDATE" = "true" ]; then
    echo ">>> Updating ComfyUI..."
    cd $COMFYUI_PATH && git pull origin master
    uv pip install -r requirements.txt --quiet
    cd $COMFYUI_PATH/custom_nodes/ComfyUI-Manager && git pull
    uv pip install -r requirements.txt --quiet 2>/dev/null || true
fi

# ── Custom nodes from env var ────────────────────────────────
# Set CUSTOM_NODES="https://github.com/xxx/node1,https://github.com/yyy/node2"
if [ ! -z "$CUSTOM_NODES" ]; then
    echo ">>> Installing custom nodes..."
    IFS=',' read -ra NODES <<< "$CUSTOM_NODES"
    for node_url in "${NODES[@]}"; do
        node_name=$(basename $node_url)
        node_path="$COMFYUI_PATH/custom_nodes/$node_name"
        if [ ! -d "$node_path" ]; then
            git clone "$node_url" "$node_path"
            [ -f "$node_path/requirements.txt" ] && uv pip install -r "$node_path/requirements.txt" --quiet
        fi
    done
fi

# ── Model downloads from env var ─────────────────────────────
# Set HF_MODELS="org/repo:filename:folder,org/repo2:filename2:vae"
if [ ! -z "$HF_MODELS" ]; then
    echo ">>> Downloading HuggingFace models..."
    IFS=',' read -ra MODELS <<< "$HF_MODELS"
    for model_entry in "${MODELS[@]}"; do
        IFS=':' read -ra PARTS <<< "$model_entry"
        repo="${PARTS[0]}"
        filename="${PARTS[1]}"
        dest_folder="${PARTS[2]:-checkpoints}"
        dest_path="$COMFYUI_PATH/models/$dest_folder/$filename"
        if [ ! -f "$dest_path" ]; then
            huggingface-cli download "$repo" "$filename" --local-dir "$COMFYUI_PATH/models/$dest_folder/"
        fi
    done
fi

# ── SSH ──────────────────────────────────────────────────────
service ssh start 2>/dev/null || /usr/sbin/sshd
[ ! -z "$SSH_PASSWORD" ] && echo "root:$SSH_PASSWORD" | chpasswd

# ── JupyterLab ───────────────────────────────────────────────
if [ "$ENABLE_JUPYTER" = "true" ]; then
    echo ">>> Starting JupyterLab on port $JUPYTER_PORT..."
    JUPYTER_TOKEN=${JUPYTER_TOKEN:-"comfyui"}
    jupyter lab \
        --ip=0.0.0.0 \
        --port=$JUPYTER_PORT \
        --no-browser \
        --allow-root \
        --NotebookApp.token="$JUPYTER_TOKEN" \
        --notebook-dir=$WORKSPACE \
        > /var/log/jupyter.log 2>&1 &
fi

# ── ComfyUI ──────────────────────────────────────────────────
echo ">>> Starting ComfyUI on port $COMFYUI_PORT..."
cd $COMFYUI_PATH
exec python main.py --port $COMFYUI_PORT $COMFYUI_EXTRA_ARGS
