import sys
import os
import re
from urllib.parse import urlparse, unquote
import requests

def get_sf_direct_link(url: str):
    clean_url = url.split("?")[0].rstrip("/")
    if clean_url.endswith("/download"):
        clean_url = clean_url[:-9]

    # Regex trích xuất project và đường dẫn file
    match = re.search(r"sourceforge\.net/projects/([^/]+)/files/(.+)", clean_url)
    if not match:
        # Trường hợp link dạng downloads.sourceforge.net
        match = re.search(r"downloads\.sourceforge\.net/project/([^/]+)/(.+)", clean_url)

    if not match:
        print(f"ERROR|URL không đúng định dạng SourceForge: {url}")
        sys.exit(1)

    project = match.group(1)
    file_path = match.group(2)
    filename = unquote(os.path.basename(file_path))

    # Endpoint tự động phân giải Mirror của SourceForge
    direct_trigger = f"https://downloads.sourceforge.net/project/{project}/{file_path}?use_mirror=autoselect"

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "Referer": url,
        "Connection": "keep-alive"
    }

    session = requests.Session()
    session.headers.update(headers)

    try:
        # Bắt chuỗi redirect để lấy URL mirror đích thực
        response = session.get(direct_trigger, allow_redirects=True, stream=True, timeout=20)
        final_url = response.url

        # Kiểm tra xem link cuối có phải direct link từ mirror không
        if "dl.sourceforge.net" in final_url and not final_url.endswith("/download"):
            print(f"{filename}|{final_url}")
            return
    except Exception:
        pass

    # Phương án dự phòng: Gọi API json danh sách mirror đang sống
    try:
        json_url = f"https://sourceforge.net/projects/{project}/files/{file_path}/json"
        res = session.get(json_url, timeout=10)
        if res.status_code == 200:
            data = res.json()
            default_mirror = data.get("default_merge")
            if default_mirror:
                fallback_url = f"https://{default_mirror}.dl.sourceforge.net/project/{project}/{file_path}"
                print(f"{filename}|{fallback_url}")
                return
    except Exception:
        pass

    # Phương án cuối cùng: fallback sang mirror cố định
    fallback_url = f"https://netix.dl.sourceforge.net/project/{project}/{file_path}"
    print(f"{filename}|{fallback_url}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(1)
    get_sf_direct_link(sys.argv[1])
