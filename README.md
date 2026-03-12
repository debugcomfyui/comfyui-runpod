# ComfyUI RunPod Docker

CUDA 12.8 + PyTorch + ComfyUI + JupyterLab, ready for RunPod GPUs.

## Deploy
Push to `main` → GitHub Actions builds and pushes to DockerHub automatically.

## RunPod Template
- Image: `senseiai/comfyui-runpod:latest`
- Container Disk: 20GB
- Volume Mount: `/runpod-volume`
- Ports: `8188` (ComfyUI), `8888` (Jupyter), `22` (SSH)

## Env Vars
| Var | Default | Description |
|-----|---------|-------------|
| `AUTO_UPDATE` | `false` | Pull latest ComfyUI on boot |
| `ENABLE_JUPYTER` | `true` | Start JupyterLab |
| `JUPYTER_TOKEN` | `comfyui` | Jupyter access token |
| `SSH_PASSWORD` | - | Root SSH password |
| `CUSTOM_NODES` | - | Comma-separated GitHub URLs |
| `HF_MODELS` | - | `repo:file:folder` to auto-download |
