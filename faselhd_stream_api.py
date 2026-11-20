# faselhd_stream_api.py
# python faselhd_stream_api.py <episode_url>   → prints JSON, used by the server

import asyncio
import json
import re
import sys
import threading
from urllib.parse import urlparse

import requests

UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)

IFRAME_SRC = re.compile(r'name="player_iframe"[^>]*?data-src="([^"]+)"')
ANY_DATA_SRC = re.compile(r'data-src="([^"]*video_player[^"]*)"')
ONCLICK_SRC = re.compile(r"player_iframe\.location\.href\s*=\s*'([^']+)'")

SELECTORS = [
    ".play-btn",
    ".play-button",
    ".player-overlay",
    ".postImageStyle",
    "a[href*='/video_player']",
    "img.thumb",
    "video",
    ".plyr__play-button",
]


def origin_of(url: str) -> str:
    p = urlparse(url)
    return f"{p.scheme}://{p.netloc}"


class Resolver:
    """One Chromium per server process, reused across requests."""

    def __init__(self):
        self._loop = asyncio.new_event_loop()
        self._thread = threading.Thread(target=self._loop.run_forever, daemon=True)
        self._thread.start()
        self._lock = threading.Lock()
        self._pw = None
        self._browser = None

    def resolve(self, episode_url: str, timeout: float = 90) -> dict:
        with self._lock:
            future = asyncio.run_coroutine_threadsafe(self._resolve(episode_url), self._loop)
            return future.result(timeout)

    def warmup(self):
        future = asyncio.run_coroutine_threadsafe(self._ensure_browser(), self._loop)
        future.add_done_callback(lambda f: f.exception())

    def close(self):
        async def shutdown():
            if self._browser is not None:
                await self._browser.close()
            if self._pw is not None:
                await self._pw.stop()

        try:
            asyncio.run_coroutine_threadsafe(shutdown(), self._loop).result(10)
        except Exception:
            pass
        self._loop.call_soon_threadsafe(self._loop.stop)

    # ── browser ────────────────────────────────────────────

    async def _ensure_browser(self):
        from playwright.async_api import async_playwright

        if self._pw is None:
            self._pw = await async_playwright().start()
        if self._browser is None or not self._browser.is_connected():
            self._browser = await self._pw.chromium.launch(
                headless=False,
                args=[
                    "--disable-blink-features=AutomationControlled",
                    "--no-sandbox",
                    "--mute-audio",
                    "--window-size=1280,720",
                    "--window-position=-2400,-2400",
                ],
            )
        return self._browser

    # ── page → player url ──────────────────────────────────

    def player_urls(self, episode_url: str) -> list:
        """GET the page and pull the /video_player targets out of it."""
        s = requests.Session()
        s.headers.update({"User-Agent": UA})
        try:
            r = s.get(episode_url, timeout=20, allow_redirects=True)
        except Exception:
            return []
        html = r.text
        base = r.url

        found, seen = [], set()
        for pattern in (IFRAME_SRC, ANY_DATA_SRC, ONCLICK_SRC):
            for m in pattern.finditer(html):
                u = m.group(1)
                if u.startswith("/"):
                    u = origin_of(base) + u
                if not u.startswith("http") or u in seen:
                    continue
                seen.add(u)
                found.append(u)
        return found

    # ── browser → m3u8 ─────────────────────────────────────

    async def _collect_from(self, url: str, referer: str, wait_s: int = 12) -> list:
        browser = await self._ensure_browser()
        o = origin_of(referer)
        context = await browser.new_context(
            user_agent=UA,
            extra_http_headers={"Referer": o + "/", "Origin": o},
            viewport={"width": 1280, "height": 720},
        )
        collected = []

        def on_request(request):
            u = request.url
            path = urlparse(u).path.lower()
            if (path.endswith(".m3u8") or path.endswith(".mp4")) and u not in collected:
                collected.append(u)

        context.on("request", on_request)
        try:
            await context.add_init_script(
                "Object.defineProperty(navigator,'webdriver',{get:()=>undefined});"
            )
            page = await context.new_page()
            try:
                await page.goto(url, wait_until="domcontentloaded", timeout=25000)
            except Exception:
                pass

            for _ in range(wait_s):
                if collected:
                    break
                await asyncio.sleep(1)

            # nothing yet: the page may need a click to start the player
            if not collected:
                for sel in SELECTORS:
                    try:
                        el = await page.query_selector(sel)
                        if el is not None:
                            await el.click(timeout=2000, force=True)
                            break
                    except Exception:
                        continue
                for _ in range(wait_s):
                    if collected:
                        break
                    await asyncio.sleep(1)
        finally:
            try:
                await context.close()
            except Exception:
                pass
        return collected

    async def _resolve(self, episode_url: str) -> dict:
        result = {"master": None, "streams": {}, "thumbnail": None, "all": [], "players": []}

        candidates = self.player_urls(episode_url)
        result["players"] = candidates

        collected = []
        if candidates:
            for cand in candidates[:3]:
                collected = await self._collect_from(cand, episode_url)
                if collected:
                    break
        else:
            # no /video_player in the markup — drive the page itself
            collected = await self._collect_from(episode_url, episode_url)

        result["all"] = collected
        for url in collected:
            if "master.m3u8" in url:
                result["master"] = url
            m = re.search(r"/yes/([a-f0-9]{32})/", url)
            if m and not result["thumbnail"]:
                result["thumbnail"] = f"https://img.scdns.io/thumb/{m.group(1)}/large.jpg"

        if not result["master"]:
            for url in collected:
                if ".m3u8" in url:
                    result["master"] = url
                    break

        for url in collected:
            if "1080" in url:
                result["streams"].setdefault("1080p", url)
            elif "720" in url:
                result["streams"].setdefault("720p", url)
            elif "360" in url:
                result["streams"].setdefault("360p", url)

        if not result["master"]:
            for quality in ("1080p", "720p", "360p"):
                if quality in result["streams"]:
                    result["master"] = result["streams"][quality]
                    break
            if not result["master"] and collected:
                result["master"] = collected[0]

        return result


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "usage: python faselhd_stream_api.py <url>"}))
        sys.exit(1)

    resolver = Resolver()
    try:
        print(json.dumps(resolver.resolve(sys.argv[1]), ensure_ascii=False))
    finally:
        resolver.close()
