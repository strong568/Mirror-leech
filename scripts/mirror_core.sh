#!/usr/bin/env bash
set -e

SOURCE_URL="$1"
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"

mkdir -p downloads/
cd downloads/

echo "============================================="
echo "[1/3] Bắt đầu nhận diện và phân giải URL..."
echo "============================================="

if [[ "$SOURCE_URL" == *"sourceforge.net"* ]]; then
    echo "Phát hiện link SourceForge, đang giải mã Mirror direct..."
    SF_INFO=$(python3 ../scripts/resolve_sf.py "$SOURCE_URL")
    
    DOWNLOAD_URL=$(echo "$SF_INFO" | cut -d'|' -f1)
    FILENAME=$(echo "$SF_INFO" | cut -d'|' -f2)
else
    DOWNLOAD_URL="$SOURCE_URL"
    FILENAME=$(basename "${SOURCE_URL%%\?*}")
fi

echo "Direct URL : $DOWNLOAD_URL"
echo "Target File: $FILENAME"

echo "============================================="
echo "[2/3] Đang tải file về Runner bằng aria2c..."
echo "============================================="

aria2c \
    --header="User-Agent: $USER_AGENT" \
    --header="Referer: https://sourceforge.net/" \
    --check-certificate=false \
    --allow-overwrite=true \
    --auto-file-renaming=false \
    --max-connection-per-server=16 \
    --split=16 \
    --min-split-size=1M \
    -o "$FILENAME" \
    "$DOWNLOAD_URL"

if [ ! -f "$FILENAME" ]; then
    echo "Lỗi: Không tìm thấy file đã tải về!"
    exit 1
fi

FILE_SIZE=$(ls -lh "$FILENAME" | awk '{print $5}')
echo "Tải hoàn tất! Dung lượng: $FILE_SIZE"

echo "============================================="
echo "[3/3] Leech dữ liệu lên Cloud..."
echo "============================================="

if [ -n "${HF_TOKEN:-}" ] && [ -n "${HF_REPO:-}" ]; then
    echo ">> Đang upload lên Hugging Face: $HF_REPO..."
    python3 - <<PY
import os
from huggingface_hub import HfApi

api = HfApi(token=os.environ.get("HF_TOKEN"))
repo_id = os.environ.get("HF_REPO")
file_name = "$FILENAME"

api.upload_file(
    path_or_fileobj=file_name,
    path_in_repo=f"mirrors/{file_name}",
    repo_id=repo_id,
    repo_type=os.environ.get("HF_REPO_TYPE", "model")
)
print(" Upload Hugging Face thành công!")
PY
fi

if [ -n "${RCLONE_CONFIG_DATA:-}" ]; then
    echo ">> Đang upload lên Google Drive..."
    mkdir -p ~/.config/rclone
    echo "$RCLONE_CONFIG_DATA" > ~/.config/rclone/rclone.conf
    
    rclone copy "$FILENAME" "gdrive:${GDRIVE_DIR:-Mirror-Leech}" --progress --drive-chunk-size 64M --transfers 4
    echo " Upload Google Drive thành công!"
fi

echo "Toàn bộ tiến trình hoàn tất!"
