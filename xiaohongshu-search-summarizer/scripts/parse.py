import json
import os
import sys
import requests
import re
from urllib.parse import urlparse


ALLOWED_IMAGE_DOMAINS = (".xhscdn.com", ".xiaohongshu.com")


def is_safe_image_url(url):
    """Validate that an image URL is from a known Xiaohongshu domain and uses HTTPS."""
    try:
        parsed = urlparse(url)
        if parsed.scheme != "https":
            return False
        hostname = parsed.hostname or ""
        return any(hostname.endswith(domain) for domain in ALLOWED_IMAGE_DOMAINS)
    except Exception:
        return False

if len(sys.argv) < 4:
    print("Usage: parse.py <keyword> <json_file_path> <output_dir>")
    sys.exit(1)

keyword = sys.argv[1]
json_path = sys.argv[2]
output_dir = sys.argv[3]

try:
    with open(json_path, 'r', encoding='utf-8') as f:
        text = f.read()
except FileNotFoundError:
    print(f"File {json_path} not found.")
    sys.exit(1)

if "### Ran Playwright code" in text:
    text = text.split("### Ran Playwright code")[0]
if "### Result" in text:
    text = text.split("### Result")[1].strip()

# remove leading/trailing quotes if stringified
text = text.strip()
if text.startswith('"') and text.endswith('"'):
    # unescape the string first
    import ast
    try:
        text = ast.literal_eval(text)
    except:
        pass

try:
    data = json.loads(text)
except json.JSONDecodeError as e:
    print(f"JSON decode failed: {e}")
    sys.exit(1)

os.makedirs(output_dir, exist_ok=True)

md_filename = f"{keyword.replace(' ', '_')}_raw_data.md"
md_path = os.path.join(output_dir, md_filename)

output_md = f"# 小红书「{keyword}」搜索原始数据提取\n\n"

headers = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)"
}

count = 0
for i, post in enumerate(data):
    if not isinstance(post, dict):
        continue
    
    count += 1
    title = post.get("title", f"帖子 {i+1}")
    desc = post.get("desc", "")
    images = post.get("images", [])
    
    output_md += f"## {count}. {title}\n\n"
    
    desc_lines = desc.split('\\n') if '\\n' in desc else desc.split('\n')
    for line in desc_lines:
        line = line.strip()
        if not line: continue
        if line.startswith('#'): continue
        output_md += f"> {line}\n"
    output_md += "\n"
    
    comments = post.get("comments", [])
    if comments:
        output_md += "**💬 Top 评论：**\n"
        for c in comments:
            user = c.get("user", "User")
            content = c.get("content", "").replace('\n', ' ')
            output_md += f"- **{user}**: {content}\n"
        output_md += "\n"
    
    for j, img_url in enumerate(images):
        if not is_safe_image_url(img_url):
            print(f"Skipping untrusted image URL: {img_url}")
            continue
        try:
            res = requests.get(img_url, headers=headers, timeout=10, allow_redirects=False)
            if res.status_code == 200:
                img_ext = "jpg"
                if "webp" in img_url: img_ext = "webp"
                
                img_filename = f"post_{count}_img_{j+1}.{img_ext}"
                img_path = os.path.join(output_dir, img_filename)
                
                with open(img_path, 'wb') as img_f:
                    img_f.write(res.content)
                
                output_md += f"![图 {j+1}]({img_path})\n"
        except Exception as e:
            print(f"Error fetching {img_url}: {e}")
            
    output_md += "\n---\n\n"

with open(md_path, 'w', encoding='utf-8') as f:
    f.write(output_md)
    
print(f"Report generated successfully at: {md_path}")
