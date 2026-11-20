# faselhd_stream_api.py
# python faselhd_stream_api.py <episode_url>   → prints JSON, used by the server

import asyncio
import json
import re
import sys
import threading

HEADERS = {
    "Referer": "https://web111918x.faselhdx.one/",
    "Origin":  "https://web111918x.faselhdx.one",
}
UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)
SELECTORS = [
    ".postImageStyle",
    "img.thumb",
    ".play-btn",
    ".play-button",
    ".player-overlay",
    ".wp-video-shortcode",
    "video",
    ".fvplayer",
    ".plyr__play-button",
    ".jwplayer",
    "#player",
    ".poster",
    "img[class*='poster']",
    "img[class*='thumb']",
    "div[class*='play']",
    "div[class*='player']",
]


class Resolver:
    """One Chromium per server process, reused across requests."""

    def __init__(self):
        self._loop = asyncio.new_event_loop()
        self._thread = threading.Thread(target=self._loop.run_forever, daemon=True)
        self._thread.start()
        self._lock = threading.Lock()
        self._pw = None
        self._browser = None

    def resolve(self, episode_url: str, timeout: float = 75) -> dict:
        with self._lock:
            future = asyncio.run_coroutine_threadsafe(self._resolve(episode_url), self._loop)
            return future.result(timeout)

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

    async def _ensure_browser(self):
        from playwright.async_api import async_playwright

        if self._pw is None:
            self._pw = await async_playwright().start()
        if self._browser is None or not self._browser.is_connected():
            # headless is detected by the site; the window is parked offscreen instead
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

    async def _resolve(self, episode_url: str) -> dict:
        result = {"master": None, "streams": {}, "thumbnail": None, "all": []}
        browser = await self._ensure_browser()
        context = await browser.new_context(
            user_agent=UA,
            extra_http_headers=HEADERS,
            viewport={"width": 1280, "height": 720},
        )
        try:
            await context.add_init_script(
                "Object.defineProperty(navigator,'webdriver',{get:()=>undefined});"
            )
            page = await context.new_page()
            collected = []

            def on_request(request):
                url = request.url
                if ".m3u8" in url and url not in collected:
                    collected.append(url)

            page.on("request", on_request)

            try:
                await page.goto(episode_url, wait_until="domcontentloaded", timeout=25000)
            except Exception:
                pass

            await asyncio.sleep(1)

            clicked = False
            for selector in SELECTORS:
                try:
                    element = await page.query_selector(selector)
                    if element is not None:
                        await element.scroll_into_view_if_needed()
                        await element.click(timeout=2500, force=True)
                        clicked = True
                        break
                except Exception:
                    continue

            if not clicked:
                try:
                    await page.mouse.click(640, 360)
                except Exception:
                    pass

            for _ in range(15):
                if collected:
                    break
                await asyncio.sleep(1)

            if not collected:
                try:
                    await page.mouse.click(640, 360)
                    for _ in range(8):
                        if collected:
                            break
                        await asyncio.sleep(1)
                except Exception:
                    pass
        finally:
            try:
                await context.close()
            except Exception:
                pass

        result["all"] = collected
        for url in collected:
            if "master.m3u8" in url:
                result["master"] = url
                match = re.search(r"/yes/([a-f0-9]{32})/", url)
                if match:
                    result["thumbnail"] = f"https://img.scdns.io/thumb/{match.group(1)}/large.jpg"
            elif "1080" in url:
                result["streams"]["1080p"] = url
            elif "720" in url:
                result["streams"]["720p"] = url
            elif "360" in url:
                result["streams"]["360p"] = url

        if not result["master"]:
            for quality in ["1080p", "720p", "360p"]:
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
