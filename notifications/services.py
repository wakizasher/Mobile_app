from __future__ import annotations

from typing import Any, Optional, Dict, List

from django.conf import settings
from django.core.cache import cache
import json
import logging
logger = logging.getLogger(__name__)

try:
    from pyfcm import FCMNotification  # type: ignore
except Exception:  # pragma: no cover - optional dependency at runtime
    FCMNotification = None  # type: ignore

try:
    import google.generativeai as genai  # type: ignore
except Exception:  # pragma: no cover
    genai = None  # type: ignore


def push_notify(
    device_token: str,
    title: str,
    body: str,
    data: Optional[dict[str, Any]] = None,
) -> bool:
    """Send a push notification via FCM.

    Returns True if attempt made, False otherwise.
    """
    server_key = getattr(settings, "FCM_SERVER_KEY", "")
    if not server_key or not FCMNotification:
        return False
    push_service = FCMNotification(api_key=server_key)
    resp = push_service.notify_single_device(
        registration_id=device_token,
        message_title=title,
        message_body=body,
        data_message=data or {},
    )
    return bool(resp)


def gemini_analyze_sentiment(text: str) -> str:
    """Use Gemini LLM to analyze sentiment for given text.

    Returns 'positive', 'neutral', or 'negative'. Falls back to 'neutral'
    when not configured.
    """
    api_key = getattr(settings, "GEMINI_API_KEY", "")
    if not api_key or not genai or not text:
        return "neutral"
    try:
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel("gemini-1.5-flash")
        prompt = (
            "Classify the sentiment of the following review as strictly one of: "
            "positive, neutral, negative.\n"
            "Respond with only the single word.\n\n" + text
        )
        res = model.generate_content(prompt)
        out = (res.text or "").strip().lower()
        if "positive" in out:
            return "positive"
        if "negative" in out:
            return "negative"
        return "neutral"
    except Exception:
        return "neutral"


def _gemini_configured() -> bool:
    api_key = getattr(settings, "GEMINI_API_KEY", "")
    ok = bool(api_key and genai)
    logger.debug(
        "_gemini_configured ok=%s api_key_present=%s genai_loaded=%s",
        ok,
        bool(api_key),
        bool(genai),
    )
    return ok


def _safe_json_from_text(text: str) -> Any:
    """Best-effort parse for JSON that may be wrapped in fences or include prose."""
    if not text:
        return None
    s = text.strip()
    # remove markdown fences
    if s.startswith("```") and s.endswith("```"):
        s = s.strip("`\n ")
        # drop potential language tag
        if "\n" in s:
            s = s.split("\n", 1)[1]
    # try to locate first JSON object/array
    start_idx = min([i for i in [s.find("{"), s.find("[")] if i != -1] or [0])
    candidate = s[start_idx:]
    try:
        return json.loads(candidate)
    except Exception:
        try:
            # last resort: find first balanced braces
            first = s.find("{")
            last = s.rfind("}")
            if first != -1 and last != -1 and last > first:
                return json.loads(s[first:last+1])
        except Exception:
            pass
    return None


def gemini_generate_recommendations(user_id: int, context: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Generate personalized movie recommendations.

    Caches per user for 1 hour.
    Returns a list of dicts with keys: imdb_id, title, genres, reason,
    confidence (0..1).
    """
    cache_key = f"reco:{user_id}"
    cached = cache.get(cache_key)
    if cached is not None:
        logger.debug("reco cache hit user_id=%s items=%s", user_id, len(cached))
        return cached
    if not _gemini_configured():
        logger.debug("reco not configured, returning empty list")
        return []
    try:
        genai.configure(api_key=settings.GEMINI_API_KEY)
        model = genai.GenerativeModel("gemini-1.5-flash")
        prompt = (
            "You are a movie recommender. Given user's favorites, liked genres, "
            "and review sentiments, propose 5 diverse movie recommendations.\n"
            "Return strict JSON array where each item has: "
            "imdb_id (if unknown, empty string), title, genres (array), "
            "reason (short explanation tailored to user), confidence (0..1).\n\n"
            f"User context (JSON):\n{json.dumps(context)}"
        )
        logger.debug(
            "reco calling Gemini user_id=%s ctx_sizes f=%s l=%s r=%s",
            user_id,
            len(context.get("favorites", [])),
            len(context.get("likes", [])),
            len(context.get("reviews", [])),
        )
        res = model.generate_content(prompt)
        text = getattr(res, "text", "") or ""
        logger.debug("reco response_text_len=%s", len(text))
        data = _safe_json_from_text(text)
        if isinstance(data, list):
            cache.set(cache_key, data, timeout=60 * 60)
            return data
    except Exception as e:  # pragma: no cover
        logging.exception("gemini_generate_recommendations failed: %s", e)
    return []


def gemini_advanced_sentiment(text: str) -> Dict[str, Any]:
    """Advanced sentiment with emotions and confidence.

    Returns dict: {
      overall: positive|neutral|negative,
      confidence: float 0..1,
      emotions: { excited, disappointed, nostalgic, joyful, sad, angry,
        fearful, surprised } scores 0..1,
      breakdown: { pros: [..], cons: [..], themes: [..] }
    }
    """
    if not _gemini_configured() or not text:
        logger.debug(
            "adv_sentiment skipped configured=%s has_text=%s",
            _gemini_configured(),
            bool(text),
        )
        return {
            "overall": "neutral",
            "confidence": 0.5,
            "emotions": {},
            "breakdown": {"pros": [], "cons": [], "themes": []},
        }
    try:
        genai.configure(api_key=settings.GEMINI_API_KEY)
        model = genai.GenerativeModel("gemini-1.5-pro")
        prompt = (
            "Analyze the movie review below. Return strict JSON with keys: "
            "overall, confidence, emotions, breakdown.\n"
            "overall must be one of: positive, neutral, negative.\n"
            "confidence is 0..1.\n"
            "emotions is an object with scores 0..1 for keys: excited, "
            "disappointed, nostalgic, joyful, sad, angry, fearful, surprised.\n"
            "breakdown contains arrays pros, cons, themes (short phrases).\n\n"
            f"Review text:\n{text}"
        )
        logger.debug("adv_sentiment calling Gemini text_len=%s", len(text or ""))
        res = model.generate_content(prompt)
        text_out = getattr(res, "text", "") or ""
        logger.debug("adv_sentiment response_text_len=%s", len(text_out))
        data = _safe_json_from_text(text_out)
        if isinstance(data, dict):
            logger.debug(
                "adv_sentiment parsed keys=%s",
                sorted(list(data.keys())),
            )
            return data
    except Exception as e:  # pragma: no cover
        logging.exception("gemini_advanced_sentiment failed: %s", e)
    return {
        "overall": "neutral",
        "confidence": 0.5,
        "emotions": {},
        "breakdown": {"pros": [], "cons": [], "themes": []},
    }


def gemini_generate_social_posts(
    movie: Dict[str, Any],
    user: Dict[str, Any],
    preferences: Dict[str, Any],
) -> Dict[str, str]:
    """Generate platform-specific social posts. Keys: twitter, instagram, facebook."""
    if not _gemini_configured():
        logger.debug("social_posts not configured")
        return {"twitter": "", "instagram": "", "facebook": ""}
    try:
        genai.configure(api_key=settings.GEMINI_API_KEY)
        model = genai.GenerativeModel("gemini-1.5-flash")
        prompt = (
            "Create engaging social posts about the movie for Twitter, "
            "Instagram, and Facebook.\n"
            "Include relevant hashtags, keep tone friendly, and reflect "
            "user's preferences if provided.\n"
            "Return strict JSON with keys 'twitter', 'instagram', 'facebook'.\n\n"
            f"Movie (JSON): {json.dumps(movie)}\n"
            f"User (JSON): {json.dumps(user)}\n"
            f"Preferences (JSON): {json.dumps(preferences or {})}"
        )
        logger.debug(
            "social_posts calling Gemini movie=%s user=%s",
            movie.get("imdb_id"),
            user.get("id"),
        )
        res = model.generate_content(prompt)
        text = getattr(res, "text", "") or ""
        logger.debug("social_posts response_text_len=%s", len(text))
        data = _safe_json_from_text(text)
        if isinstance(data, dict):
            return {
                "twitter": data.get("twitter", ""),
                "instagram": data.get("instagram", ""),
                "facebook": data.get("facebook", ""),
            }
    except Exception as e:  # pragma: no cover
        logging.exception("gemini_generate_social_posts failed: %s", e)
    return {"twitter": "", "instagram": "", "facebook": ""}


def gemini_generate_notification_message(user: Dict[str, Any], context: Dict[str, Any]) -> Dict[str, str]:
    """Generate personalized notification title and body."""
    if not _gemini_configured():
        logger.debug("notif_message not configured")
        return {"title": "", "body": ""}
    try:
        genai.configure(api_key=settings.GEMINI_API_KEY)
        model = genai.GenerativeModel("gemini-1.5-flash")
        prompt = (
            "Write a concise, personalized push notification for a movie app "
            "user given the context (trending movies, friend activities, etc).\n"
            "Return strict JSON with keys: title, body. 110 characters max for "
            "body.\n\n"
            f"User (JSON): {json.dumps(user)}\n"
            f"Context (JSON): {json.dumps(context)}"
        )
        logger.debug(
            "notif_message calling Gemini user=%s ctx_keys=%s",
            user.get("id"),
            list((context or {}).keys()),
        )
        res = model.generate_content(prompt)
        text = getattr(res, "text", "") or ""
        logger.debug("notif_message response_text_len=%s", len(text))
        data = _safe_json_from_text(text)
        if isinstance(data, dict):
            return {"title": data.get("title", ""), "body": data.get("body", "")}
    except Exception as e:  # pragma: no cover
        logging.exception("gemini_generate_notification_message failed: %s", e)
    return {"title": "", "body": ""}


def gemini_summarize_reviews(
    movie: Dict[str, Any],
    reviews: List[Dict[str, Any]],
) -> Dict[str, Any]:
    """Summarize multiple user reviews for a movie.

    Returns dict with summary, overall_sentiment, key_themes.
    """
    # Cache by movie and count of reviews
    cache_key = f"summary:{movie.get('imdb_id')}:{len(reviews)}"
    cached = cache.get(cache_key)
    if cached is not None:
        return cached
    if not _gemini_configured() or not reviews:
        logger.debug(
            "summary skip configured=%s reviews_count=%s",
            _gemini_configured(),
            len(reviews),
        )
        return {"summary": "", "overall_sentiment": "neutral", "key_themes": []}
    try:
        genai.configure(api_key=settings.GEMINI_API_KEY)
        model = genai.GenerativeModel("gemini-1.5-pro")
        short_reviews = [r.get("content", "") for r in reviews[:50]]
        prompt = (
            "Summarize the following user reviews for the movie.\n"
            "Return strict JSON with keys: summary (<=120 words), "
            "overall_sentiment (positive|neutral|negative), key_themes (array "
            "of short phrases).\n\n"
            f"Movie (JSON): {json.dumps(movie)}\n"
            f"Reviews (JSON array): {json.dumps(short_reviews)}"
        )
        logger.debug(
            "summary calling Gemini imdb_id=%s reviews_count=%s",
            movie.get("imdb_id"),
            len(short_reviews),
        )
        res = model.generate_content(prompt)
        text = getattr(res, "text", "") or ""
        logger.debug("summary response_text_len=%s", len(text))
        data = _safe_json_from_text(text)
        if isinstance(data, dict):
            cache.set(cache_key, data, timeout=60 * 60)
            return data
    except Exception as e:  # pragma: no cover
        logging.exception("gemini_summarize_reviews failed: %s", e)
    return {"summary": "", "overall_sentiment": "neutral", "key_themes": []}


def gemini_healthcheck() -> Dict[str, Any]:
    """Lightweight connectivity check for Gemini.

    Returns a dict with keys: configured, success, model, text_len,
    error.
    """
    info: Dict[str, Any] = {
        "configured": _gemini_configured(),
        "success": False,
        "model": "gemini-1.5-flash",
        "text_len": 0,
        "error": None,
    }
    if not info["configured"]:
        logger.debug("healthcheck: not configured")
        return info
    try:
        genai.configure(api_key=settings.GEMINI_API_KEY)
        model = genai.GenerativeModel(info["model"])
        res = model.generate_content("ping")
        text = getattr(res, "text", "") or ""
        info["text_len"] = len(text)
        info["success"] = bool(text)
        logger.debug(
            "healthcheck: success=%s text_len=%s",
            info["success"],
            info["text_len"],
        )
    except Exception as e:  # pragma: no cover
        info["error"] = str(e)
        logging.exception("gemini_healthcheck failed: %s", e)
    return info
