"""Custom function tools exposed to the agent."""

from datetime import UTC, datetime


def get_current_utc_date() -> str:
    """Returns the current UTC date and time in ISO 8601 format. Useful for generating time-relative SQL queries."""
    return datetime.now(UTC).isoformat()
