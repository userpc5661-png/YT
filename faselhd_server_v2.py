# faselhd_server_v2.py
# pip install flask
# python faselhd_server_v2.py

import json, re, os, time, threading, subprocess, sys
from collections import Counter
from flask import Flask, jsonify, request, send_from_directory

app = Flask(__name__)

# ── Catalog ────────────────────────────────────────────

def load(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except:
        return []

raw = {
    "movies": load("catalog_movies.json"),
    "series": load("catalog_series.json"),
    "asian":  load("catalog_asian.json"),
    "anime":  load("catalog_anime.json"),
}

JUNK_PREFIX = re.compile(
    r'^(WEB-DL|WEBRip|Bluray|HDRip|DVDRip|CAM|4K|HD|Animation|WEB)\s*'
    r'(الأكشن|الإثارة|الكوميديا|الرعب|الخيال العلمي|الدراما|الجريمة|'
    r'الرومانسية|الوثائقي|المغامرة|الأنيمي|الغموض|الحروب|الرعب|'
    r'التاريخي|الإثارة|العائلي|الموسيقى|الرياضة|السيرة الذاتية|'
    r'مغامرات|اثارة|اكشن|رومانسي|كوميدي|دراما|خيال علمي|جريمة|'
    r'رعب|غموض|وثائقي|تاريخي|انيمي)*'
    r'\s*[\d٬.,]+\s*'
    r'(الأكشن|الإثارة|الكوميديا|الرعب|الخيال العلمي|الدراما|الجريمة|'
    r'الرومانسية|الوثائقي|المغامرة|اثارة|اكشن|رومانسي|كوميدي|دراما|'
    r'خيال علمي|جريمة|رعب|غموض|وثائقي|تاريخي)*\s*'
)

def clean(title: str) -> str:
    m = re.search(r'(فيلم|مسلسل|انمي)\s', title)
    if m:
        title = title[m.start():]
    title = JUNK_PREFIX.sub('', title)
    title = re.sub(r'\s*(مترجم|مدبلج)\s*$', '', title)
    title = re.sub(r'\s*-\w{1,4}\s*$', '', title)
    return title.strip()

KIND = {"movies": "movie", "series": "series", "asian": "asian", "anime": "anime"}

CATALOG = []
seen = set()
for section, items in raw.items():
    for item in items:
        url = item.get("url", "").strip()
        if not url or url in seen:
            continue
        seen.add(url)
        CATALOG.append({
            "id":        len(CATALOG) + 1,
            "title":     clean(item.get("title", "")),
            "type":      KIND[section],
            "url":       url,
            "thumbnail": item.get("thumbnail") or "",
            "year":      item.get("year") or "",
        })

print(f"[+] {len(CATALOG)} عنصر جاهز")

# ── Stream Cache ────────────────────────────────────────
# { url -> { master, expires } }
_cache: dict = {}
_cache_lock = threading.Lock()
CACHE_TTL = 60 * 25   # 25 دقيقة (الروابط تنتهي عادة بعد 30)

def cache_get(url: str):
    with _cache_lock:
        entry = _cache.get(url)
        if entry and entry["expires"] > time.time():
            return entry["master"]
        return None

def cache_set(url: str, master: str):
    with _cache_lock:
        _cache[url] = {"master": master, "expires": time.time() + CACHE_TTL}

# ── Stream Worker ───────────────────────────────────────
# prefetch queue: set of URLs being fetched right now
_fetching: set = set()
_fetching_lock = threading.Lock()

def fetch_stream_sync(url: str) -> str | None:
    """يشغّل faselhd_stream_api.py ويرجع الـ master m3u8 أو None"""
    try:
        result = subprocess.run(
            [sys.executable, "faselhd_stream_api.py", url],
            capture_output=True, text=True, timeout=60
        )
        data = json.loads(result.stdout)
        return data.get("master")
    except Exception as e:
        print(f"[stream error] {e}")
        return None

def prefetch(url: str):
    """يجيب الـ stream في background ويحطه في الـ cache"""
    with _fetching_lock:
        if url in _fetching:
            return
        _fetching.add(url)

    def worker():
        try:
            master = fetch_stream_sync(url)
            if master:
                cache_set(url, master)
                print(f"[cache] stored: {url[:60]}...")
        finally:
            with _fetching_lock:
                _fetching.discard(url)

    threading.Thread(target=worker, daemon=True).start()

# ── Routes ──────────────────────────────────────────────

@app.route("/")
def index():
    return jsonify({"total": len(CATALOG), "endpoints": [
        "GET /catalog?type=movie|series|asian|anime&q=QUERY&page=N&limit=N",
        "GET /catalog/all",
        "GET /catalog/layl   ← iOS app format",
        "GET /stream?url=EPISODE_URL",
        "GET /ui",
    ]})

@app.route("/catalog")
def catalog():
    kind  = request.args.get("type", "")
    q     = request.args.get("q", "").strip().lower()
    page  = max(1, int(request.args.get("page", 1)))
    limit = max(1, min(500, int(request.args.get("limit", 50))))

    items = CATALOG
    if kind:
        items = [i for i in items if i["type"] == kind]
    if q:
        items = [i for i in items if q in i["title"].lower() or q in i["url"].lower()]

    total = len(items)
    paged = items[(page-1)*limit : page*limit]

    return jsonify({
        "total": total, "page": page,
        "pages": (total + limit - 1) // limit,
        "results": paged,
    })

@app.route("/catalog/all")
def catalog_all():
    return jsonify(CATALOG)

@app.route("/catalog/types")
def catalog_types():
    return jsonify(dict(Counter(i["type"] for i in CATALOG)))

@app.route("/catalog/<int:item_id>")
def catalog_item(item_id):
    item = next((i for i in CATALOG if i["id"] == item_id), None)
    return jsonify(item) if item else (jsonify({"error": "not found"}), 404)

# ── iOS Layl Format ─────────────────────────────────────
@app.route("/catalog/layl")
def catalog_layl():
    """
    يرجع الكتالوج بـ format يقرأه تطبيق Layl مباشرة.
    كل عنصر: id, title, type, thumbnail, year, stream_url
    stream_url = /resolve?url=... (يرجع m3u8 أو redirect)
    """
    kind = request.args.get("type", "")
    q    = request.args.get("q", "").strip().lower()
    page = max(1, int(request.args.get("page", 1)))
    limit= max(1, min(200, int(request.args.get("limit", 50))))

    items = CATALOG
    if kind:
        items = [i for i in items if i["type"] == kind]
    if q:
        items = [i for i in items if q in i["title"].lower()]

    total = len(items)
    paged = items[(page-1)*limit : page*limit]

    # بناء الـ base URL من الـ request
    host = request.host  # e.g. 192.168.1.5:8080

    results = []
    for item in paged:
        stream_url = f"http://{host}/stream?url={item['url']}"
        results.append({
            "id":         str(item["id"]),
            "title":      item["title"],
            "type":       item["type"],
            "thumbnail":  item["thumbnail"],
            "year":       item["year"],
            "url":        item["url"],
            "stream_url": stream_url,
        })

    return jsonify({
        "total": total,
        "page": page,
        "pages": (total + limit - 1) // limit,
        "results": results,
    })

# ── Stream Endpoint ─────────────────────────────────────
@app.route("/stream")
def get_stream():
    """
    GET /stream?url=<episode_url>
    يرجع الـ m3u8 مباشرة أو JSON { master, streams, error }
    """
    url = request.args.get("url", "").strip()
    if not url:
        return jsonify({"error": "url required"}), 400

    # check cache
    cached = cache_get(url)
    if cached:
        # redirect مباشر للـ m3u8 عشان AVPlayer يشتغل
        accept = request.headers.get("Accept", "")
        if "application/json" in accept:
            return jsonify({"master": cached, "source": "cache"})
        from flask import redirect
        return redirect(cached, code=302)

    # مو في الـ cache — جيبه الحين (synchronous)
    master = fetch_stream_sync(url)
    if master:
        cache_set(url, master)
        accept = request.headers.get("Accept", "")
        if "application/json" in accept:
            return jsonify({"master": master, "source": "live"})
        from flask import redirect
        return redirect(master, code=302)

    return jsonify({"error": "stream not found", "url": url}), 404

@app.route("/prefetch")
def do_prefetch():
    """
    GET /prefetch?url=<episode_url>
    يبدأ الجلب في background ويرجع فوراً
    """
    url = request.args.get("url", "").strip()
    if not url:
        return jsonify({"error": "url required"}), 400
    cached = cache_get(url)
    if cached:
        return jsonify({"status": "ready", "master": cached})
    prefetch(url)
    return jsonify({"status": "fetching"})

# ── Static / UI ─────────────────────────────────────────
@app.route("/static/<path:filename>")
def static_files(filename):
    return send_from_directory("static", filename)

@app.route("/ui")
def ui():
    return send_from_directory(
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "static"),
        "index.html"
    )

if __name__ == "__main__":
    import socket
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    print(f"[*] http://localhost:8080/ui")
    print(f"[*] iPhone: http://{local_ip}:8080/catalog/layl")
    app.run(host="0.0.0.0", port=8080, debug=False, threaded=True)
