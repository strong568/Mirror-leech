#!/usr/bin/env bash
set -e

SOURCE_URL="$1"
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"

mkdir -p downloads/
cd downloads/

echo "============================================="
echo "[1/3] Bắt đầu nhận diện và tải nguồn URL..."
echo "============================================="

# ==================== 1. XỬ LÝ LINK GOOGLE DRIVE ====================
if [[ "$SOURCE_URL" == *"drive.google.com"* || "$SOURCE_URL" == *"drive.usercontent.google.com"* ]]; then
    echo "Phát hiện link Google Drive, sử dụng gdown để clone..."
    python3 -m pip install -q gdown

    # Kiểm tra xem là link Folder hay link File đơn
    if [[ "$SOURCE_URL" == *"/folders/"* || "$SOURCE_URL" == *"id="* && "$SOURCE_URL" == *"folder"* ]]; then
        echo "Link Folder Drive: Bắt đầu tải trọn bộ folder..."
        gdown --folder "$SOURCE_URL" --remaining-ok
    else
        echo "Link File Drive: Bắt đầu tải file..."
        gdown "$SOURCE_URL" --fuzzy
    fi

# ==================== 2. XỬ LÝ LINK SOURCEFORGE ====================
elif [[ "$SOURCE_URL" == *"sourceforge.net"* ]]; then
    echo "Phát hiện link SourceForge, đang truy vấn danh sách Mirror..."
    SF_INFO=$(python3 ../scripts/resolve_sf.py "$SOURCE_URL")
    
    FILENAME=$(echo "$SF_INFO" | cut -d'|' -f1)
    MIRROR_LIST=$(echo "$SF_INFO" | cut -d'|' -f2)

    echo "Target File : $FILENAME"
    echo "Đang tải file từ danh sách Mirror khả dụng..."

    # Truyền toàn bộ danh sách Mirror vào aria2c.
    # Thêm cờ --max-file-not-found=5 để aria2c tự động bỏ qua mirror lỗi/redirect và nhảy sang mirror tiếp theo
    aria2c \
        --header="User-Agent: $USER_AGENT" \
        --check-certificate=false \
        --allow-overwrite=true \
        --auto-file-renaming=false \
        --max-file-not-found=5 \
        --max-connection-per-server=8 \
        --split=16 \
        --min-split-size=1M \
        -o "$FILENAME" \
        $MIRROR_LIST


# ==================== 3. CÁC LINK DIRECT KHÁC ====================
else
    DOWNLOAD_URL="$SOURCE_URL"
    FILENAME=$(basename "${SOURCE_URL%%\?*}")

    echo "Direct URL : $DOWNLOAD_URL"
    echo "Target File: $FILENAME"
    echo "Đang tải file về Runner bằng aria2c..."

    aria2c \
        --header="User-Agent: $USER_AGENT" \
        --check-certificate=false \
        --allow-overwrite=true \
        --auto-file-renaming=false \
        --max-connection-per-server=16 \
        --split=16 \
        --min-split-size=1M \
        -o "$FILENAME" \
        "$DOWNLOAD_URL"
fi

echo "============================================="
echo "[2/3] Kiểm tra tệp tin đã tải về..."
echo "============================================="

# Lấy danh sách file đã tải về
TARGET_FILES=$(ls -A .)
if [ -z "$TARGET_FILES" ]; then
    echo "Lỗi: Thư mục downloads trống, không có file nào được tải về!"
    exit 1
fi

ls -lh .

echo "============================================="
echo "[3/3] Leech dữ liệu lên Cloud..."
echo "============================================="

# 1. Đẩy lên Hugging Face (nếu có HF_TOKEN)
if [ -n "${HF_TOKEN:-}" ] && [ -n "${HF_REPO:-}" ]; then
    echo ">> Đang upload lên Hugging Face: $HF_REPO..."
    python3 - <<PY
import os
from huggingface_hub import HfApi

api = HfApi(token=os.environ.get("HF_TOKEN"))
repo_id = os.environ.get("HF_REPO")
repo_type = os.environ.get("HF_REPO_TYPE", "model")

for root, dirs, files in os.walk("."):
    for file in files:
        rel_path = os.path.relpath(os.path.join(root, file), ".")
        print(f"Uploading: {rel_path}")
        api.upload_file(
            path_or_fileobj=rel_path,
            path_in_repo=f"mirrors/{rel_path}",
            repo_id=repo_id,
            repo_type=repo_type
        )
print(" Upload Hugging Face thành công!")
PY
fi

# 2. Đẩy lên Google Drive qua Rclone (nếu có RCLONE_CONFIG_DATA)
if [ -n "${RCLONE_CONFIG_DATA:-}" ]; then
    echo ">> Đang đồng bộ lên Google Drive qua rclone..."
    mkdir -p ~/.config/rclone
    echo "$RCLONE_CONFIG_DATA" > ~/.config/rclone/rclone.conf
    
    rclone copy . "gdrive:${GDRIVE_DIR:-Mirror-Leech}" \
        --progress \
        --drive-chunk-size 64M \
        --transfers 4
    echo " Upload Google Drive thành công!"
fi

echo "Toàn bộ tiến trình hoàn tất!"
