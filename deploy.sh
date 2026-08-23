cat << 'EOF' > deploy.sh
#!/bin/bash

for file in *.ipynb; do
  if [ -f "$file" ]; then
    jupyter nbconvert --to html "$file"
  fi
done

python3 -c '
import glob, os

html_files = sorted(glob.glob("*.html"))
links = [f for f in html_files if f != "index.html"]

items = []
for f in links:
    clean_title = f.replace(".html", "").replace("_", " ").title()
    items.append(f"      <li><a href=\"{f}\">{clean_title}</a></li>")

link_items = "\n".join(items)

index_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>GrADS Notebook Dashboard</title>
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f172a; color: #f8fafc; padding: 40px; }}
    .container {{ max-width: 800px; margin: 0 auto; }}
    h1 {{ color: #38bdf8; margin-bottom: 8px; font-size: 28px; }}
    p {{ color: #94a3b8; margin-bottom: 24px; font-size: 14px; }}
    ul {{ list-style: none; }}
    li {{ margin-bottom: 12px; }}
    a {{ display: block; background: #1e293b; color: #38bdf8; padding: 16px 20px; border-radius: 8px; border: 1px solid #334155; text-decoration: none; font-weight: 600; transition: all 0.2s; }}
    a:hover {{ background: #334155; border-color: #38bdf8; color: #fff; transform: translateY(-2px); }}
  </style>
</head>
<body>
  <div class="container">
    <h1>GrADS Notebook Gallery</h1>
    <p>Select a notebook below to view full code and output plots.</p>
    <ul>
{link_items}
    </ul>
  </div>
</body>
</html>"""

with open("index.html", "w") as f:
    f.write(index_html)
'

git add *.html
git commit -m "Auto-deploy updated notebooks and gallery"
git push origin main
EOF

chmod +x deploy.sh