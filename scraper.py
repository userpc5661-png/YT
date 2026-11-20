# faselhd_catalog.py — Python 3.8+
# pip install requests beautifulsoup4

import requests
from bs4 import BeautifulSoup
import json
import time

BASE = "https://www.fasel-hd.co"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36",
    "Referer": "https://www.fasel-hd.co/",
}

SECTIONS = {
    "movies":  "/all-movies/page/{}",
    "series":  "/series/page/{}",
    "asian":   "/asian-series/page/{}",
    "anime":   "/anime/page/{}",
}

def scrape_page(url: str) -> list:
    """يسحب كل العناصر من صفحة listing واحدة"""
    try:
        r = requests.get(url, headers=HEADERS, timeout=10)
        if r.status_code != 200:
            return None  # انتهت الصفحات
        soup = BeautifulSoup(r.text, "html.parser")
        items = []
        # كل بطاقة فيلم/مسلسل
        for card in soup.select("div.postDiv, div.SmallMovieItem, article"):
            a = card.select_one("a[href]")
            img = card.select_one("img")
            title_el = card.select_one(".Title, h3, .postTitle, [class*='title']")
            rating_el = card.select_one(".imdb, .rating, [class*='rating']")
            year_el = card.select_one(".year, .Year, [class*='year']")

            if not a:
                continue

            href = a.get("href", "")
            if not href.startswith("http"):
                href = BASE + href

            item = {
                "title": title_el.get_text(strip=True) if title_el else a.get_text(strip=True),
                "url": href,
                "thumbnail": img.get("data-src") or img.get("src") if img else None,
                "rating": rating_el.get_text(strip=True) if rating_el else None,
                "year": year_el.get_text(strip=True) if year_el else None,
            }
            if item["url"]:
                items.append(item)
        return items
    except Exception as e:
        print(f"[ERR] {url} → {e}")
        return []


def scrape_section(name: str, path_template: str, max_pages: int = 999) -> list:
    all_items = []
    seen = set()
    for page in range(1, max_pages + 1):
        url = BASE + path_template.format(page)
        print(f"[{name}] صفحة {page}: {url}")
        items = scrape_page(url)
        if items is None or len(items) == 0:
            print(f"[{name}] انتهت عند صفحة {page}")
            break
        fresh = [i for i in items if i["url"] not in seen]
        if not fresh:
            print(f"[{name}] انتهت عند صفحة {page} — نفس المحتوى")
            break
        for i in fresh:
            seen.add(i["url"])
        all_items.extend(fresh)
        print(f"  → {len(fresh)} جديد | المجموع: {len(all_items)}")
        time.sleep(0.5)  # لا تضغط السيرفر
    return all_items


def main():
    catalog = {}
    total = 0

    for section_name, path in SECTIONS.items():
        print(f"\n{'='*50}")
        print(f"[*] قسم: {section_name}")
        items = scrape_section(section_name, path)
        catalog[section_name] = items
        total += len(items)
        print(f"[+] {section_name}: {len(items)} عنصر")

        # حفظ تدريجي كل قسم
        with open(f"catalog_{section_name}.json", "w", encoding="utf-8") as f:
            json.dump(items, f, ensure_ascii=False, indent=2)

    # حفظ كامل
    with open("catalog_full.json", "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)

    print(f"\n[+] اكتمل — {total} عنصر في catalog_full.json")


if __name__ == "__main__":
    main()