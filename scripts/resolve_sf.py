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
    
    direct_trigger = f"https://downloads.sourceforge.net/project/{project}/{file_subpath}?use_mirror=autoselect"
    headers = {
        "User-Agent": ua,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Referer": raw_url
    }

    try:
        session = requests.Session()
        resp = session.get(direct_trigger, headers=headers, allow_redirects=True, stream=True, timeout=25)
        final_url = resp.url
        if "dl.sourceforge.net" in final_url:
            print(f"{final_url}|{filename}")
            return
    except Exception:
        pass

    fallback_mirror = f"https://zenlayer.dl.sourceforge.net/project/{project}/{file_subpath}"
    print(f"{fallback_mirror}|{filename}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(1)
    resolve_sourceforge(sys.argv[1])
