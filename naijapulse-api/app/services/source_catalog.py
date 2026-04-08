from typing import List

from app.core.config import Settings, get_settings
from app.schemas.news import NewsSourceInfo


def default_source_catalog(settings: Settings | None = None) -> List[NewsSourceInfo]:
    """Return bootstrap source definitions for local/dev ingestion."""
    resolved_settings = settings or get_settings()
    has_newsapi_key = bool(resolved_settings.newsapi_api_key.strip())
    has_gnews_key = bool(resolved_settings.gnews_api_key.strip())

    sources: list[NewsSourceInfo] = []

    sources.append(
        NewsSourceInfo(
            id="newsapi",
            name="NewsAPI",
            type="aggregator_api",
            country="global",
            enabled=resolved_settings.enable_newsapi_source and has_newsapi_key,
            requires_api_key=True,
            configured=has_newsapi_key,
            api_base_url="https://newsapi.org/v2",
            notes=_api_source_note(
                provider_name="NewsAPI",
                enabled_by_setting=resolved_settings.enable_newsapi_source,
                has_api_key=has_newsapi_key,
            ),
        )
    )

    sources.append(
        NewsSourceInfo(
            id="gnews",
            name="GNews API",
            type="aggregator_api",
            country="global",
            enabled=resolved_settings.enable_gnews_source and has_gnews_key,
            requires_api_key=True,
            configured=has_gnews_key,
            api_base_url="https://gnews.io/api/v4",
            notes=_api_source_note(
                provider_name="GNews API",
                enabled_by_setting=resolved_settings.enable_gnews_source,
                has_api_key=has_gnews_key,
            ),
        )
    )

    if not resolved_settings.enable_rss_sources:
        return sources

    sources.extend([
        NewsSourceInfo(
            id="google_news_rss",
            name="Google News RSS",
            type="rss",
            country="global",
            enabled=True,
            requires_api_key=False,
            configured=True,
            feed_url="https://news.google.com/rss?hl=en-NG&gl=NG&ceid=NG:en",
            poll_interval_sec=900,
            notes="Low-friction fallback source; should be deduplicated and monitored.",
        ),
        NewsSourceInfo(
            id="google_news_business_rss",
            name="Google News Business (NG)",
            type="rss",
            country="NG",
            enabled=True,
            requires_api_key=False,
            configured=True,
            feed_url="https://news.google.com/rss/headlines/section/topic/BUSINESS?hl=en-NG&gl=NG&ceid=NG:en",
            poll_interval_sec=900,
            notes="Business-focused stream to improve category variety in latest feed.",
        ),
        NewsSourceInfo(
            id="google_news_sports_rss",
            name="Google News Sports (NG)",
            type="rss",
            country="NG",
            enabled=True,
            requires_api_key=False,
            configured=True,
            feed_url="https://news.google.com/rss/headlines/section/topic/SPORTS?hl=en-NG&gl=NG&ceid=NG:en",
            poll_interval_sec=900,
            notes="Sports-focused stream to keep sports category populated.",
        ),
        NewsSourceInfo(
            id="google_news_technology_rss",
            name="Google News Technology (NG)",
            type="rss",
            country="NG",
            enabled=True,
            requires_api_key=False,
            configured=True,
            feed_url="https://news.google.com/rss/headlines/section/topic/TECHNOLOGY?hl=en-NG&gl=NG&ceid=NG:en",
            poll_interval_sec=900,
            notes="Technology-focused stream to reduce over-indexing on breaking stories.",
        ),
        NewsSourceInfo(
            id="premium_times_rss",
            name="Premium Times RSS",
            type="publisher_rss",
            country="NG",
            enabled=True,
            requires_api_key=False,
            configured=True,
            feed_url="https://www.premiumtimesng.com/feed",
            poll_interval_sec=900,
            notes="Useful Nigeria-focused publisher feed if terms of use permit ingestion.",
        ),
        NewsSourceInfo(
            id="guardian_ng_rss",
            name="The Guardian Nigeria RSS",
            type="publisher_rss",
            country="NG",
            enabled=True,
            requires_api_key=False,
            configured=True,
            feed_url="https://guardian.ng/feed/",
            poll_interval_sec=900,
            notes="Strong local coverage; verify feed reliability and republishing terms.",
        ),
        NewsSourceInfo(
            id="saharareporters_rss",
            name="Sahara Reporters",
            type="publisher_rss",
            country="NG",
            enabled=True,
            requires_api_key=False,
            configured=True,
            feed_url="http://saharareporters.com/feeds/latest/feed",
            poll_interval_sec=900,
            notes="All Content feed from Sahara Reporters.",
        ),
        NewsSourceInfo(
            id="nigerian_bulletin_rss",
            name="Nigerian Bulletin",
            type="publisher_rss",
            country="NG",
            enabled=True,
            requires_api_key=False,
            configured=True,
            feed_url="https://www.nigerianbulletin.com/forums/-/index.rss",
            poll_interval_sec=900,
            notes="Nigeria news links and daily updates feed.",
        ),
        NewsSourceInfo(
            id="nigerianeye_rss",
            name="NigerianEye",
            type="publisher_rss",
            country="NG",
            enabled=True,
            requires_api_key=False,
            configured=True,
            feed_url="http://feeds.feedburner.com/Nigerianeye",
            poll_interval_sec=900,
            notes="Latest Nigeria news and online newspaper feed.",
        ),
        NewsSourceInfo(
            id="legit_ng_rss",
            name="Legit.ng",
            type="publisher_rss",
            country="NG",
            enabled=True,
            requires_api_key=False,
            configured=True,
            feed_url="https://www.legit.ng/rss/all.rss",
            poll_interval_sec=900,
            notes="General all-content publisher RSS feed.",
        ),
        NewsSourceInfo(
            id="the_nation_rss",
            name="The Nation Nigeria",
            type="publisher_rss",
            country="NG",
            enabled=True,
            requires_api_key=False,
            configured=True,
            feed_url="https://thenationonlineng.net/feed/",
            poll_interval_sec=900,
            notes="Politics and general Nigeria news feed.",
        ),
        NewsSourceInfo(
            id="daily_post_ng_rss",
            name="Daily Post Nigeria",
            type="publisher_rss",
            country="NG",
            enabled=True,
            requires_api_key=False,
            configured=True,
            feed_url="https://dailypost.ng/feed",
            poll_interval_sec=900,
            notes="Daily Post Nigeria RSS feed.",
        ),
        NewsSourceInfo(
            id="information_ng_rss",
            name="Information Nigeria",
            type="publisher_rss",
            country="NG",
            enabled=True,
            requires_api_key=False,
            configured=True,
            feed_url="https://www.informationng.com/feed",
            poll_interval_sec=900,
            notes="Nigeria information portal RSS feed.",
        ),
        NewsSourceInfo(
            id="tribune_online_rss",
            name="Tribune Online",
            type="publisher_rss",
            country="NG",
            enabled=True,
            requires_api_key=False,
            configured=True,
            feed_url="http://tribuneonlineng.com/feed/",
            poll_interval_sec=900,
            notes="Breaking news in Nigeria feed from Tribune Online.",
        ),
    ])

    return sources


def _api_source_note(
    *,
    provider_name: str,
    enabled_by_setting: bool,
    has_api_key: bool,
) -> str:
    if not enabled_by_setting:
        return (
            f"{provider_name} is registered but disabled by configuration. "
            "Set the corresponding ENABLE_* flag to true to activate it."
        )
    if not has_api_key:
        return (
            f"{provider_name} is registered but not configured yet. "
            "Add the API key in environment settings to activate ingestion."
        )
    return (
        f"{provider_name} is registered and ready for aggregator ingestion. "
        "Monitor overlap with RSS and other aggregators to keep duplicate volume under control."
    )
