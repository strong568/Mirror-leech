import sys
import os
import requests
from urllib.parse import urlparse

def resolve_sourceforge(raw_url: str):
    ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
    clean_url = raw_url.split("?")[0].removesuffix("/download")
    p = urlparse(clean_url)
    parts = [x for x in p.path.split("/") if x]

    if "projects" in parts and "files" in parts:
        proj_idx = parts.index("projects") + 1
        file_idx = parts.index("files") + 1
        project = parts[proj_idx]
        file_subpath = "/".join(parts[file_idx:])
    else:
        project = parts[1]
        file_subpath = "/".join(parts[3:])

    filename = os.path.basename(file_subpath)
    
    # 1. Gọi JSON API chính thức của SourceForge để lấy danh sách Mirror thật
    api_url = f"https://sourceforge.net/projects/{project}/files/{file_subpath}/json"
    headers = {"User-Agent": ua, "Accept": "application/json"}
    
    mirror_urls = []
    try:
        resp = requests.get(api_url, headers=headers, timeout=15)
        if resp.status_code == 200:
            data = resp.json()
            # Ưu tiên mirror tốt nhất do SourceForge đề xuất
            default_mirror = data.get("default_merge")
            if default_mirror:
                mirror_urls.append(f"https://{default_mirror}.dl.sourceforge.net/project/{project}/{file_subpath}")
            
            # Lấy danh sách các mirror khác đang active
            for item in data.get("repos", []):
                m_short = item.get("short_name")
                if m_short and m_short != default_mirror:
                    mirror_urls.append(f"https://{m_short}.dl.sourceforge.net/project/{project}/{file_subpath}")
    except Exception:
        pass

    # 2. Danh sách các mirror cố định dự phòng (bỏ qua zenlayer vì hay redirect ngược lại)
    fallback_mirrors = [
        f"https://cfhcable.dl.sourceforge.net/project/{project}/{file_subpath}",
        f"https://jaist.dl.sourceforge.net/project/{project}/{file_subpath}",
        f"https://netix.dl.sourceforge.net/project/{project}/{file_subpath}",
        f"https://nchc.dl.sourceforge.net/project/{project}/{file_subpath}",
        f"https://versaweb.dl.sourceforge.net/project/{project}/{file_subpath}"
    ]

    for fb in fallback_mirrors:
        if fb not in mirror_urls:
            mirror_urls.append(fb)

    # In ra: filename|url1 url2 url3...
    print(f"{filename}|{' '.join(mirror_urls)}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(1)
    resolve_sourceforge(sys.argv[1])
