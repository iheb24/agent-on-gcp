"""Authenticated client for the managed BigQuery MCP server."""

import google.auth
import google.auth.transport.requests
import httpx
from google.adk.tools.mcp_tool import McpToolset, StreamableHTTPConnectionParams

BIGQUERY_MCP_URL = "https://bigquery.googleapis.com/mcp"
BIGQUERY_SCOPE = "https://www.googleapis.com/auth/bigquery"


class _GoogleBearerAuth(httpx.Auth):
    """Attaches a fresh OAuth2 bearer token to every request.

    A static Authorization header goes stale once the access token expires
    (~1 hour); refreshing on demand keeps long-lived runtimes (Agent Engine,
    Cloud Run) working indefinitely.
    """

    def __init__(self, credentials):
        self._credentials = credentials
        self._refresh_request = google.auth.transport.requests.Request()

    def auth_flow(self, request: httpx.Request):
        if not self._credentials.valid:
            self._credentials.refresh(self._refresh_request)
        request.headers["Authorization"] = f"Bearer {self._credentials.token}"
        yield request


def initialize_bq_mcp() -> McpToolset:
    """Build the McpToolset for the managed BigQuery MCP server.

    Credentials are resolved lazily inside the client factory so that
    importing the agent module never requires Application Default
    Credentials (packaging, tests), only actual MCP calls do.
    """

    def client_factory(headers=None, timeout=None, auth=None) -> httpx.AsyncClient:
        credentials, project_id = google.auth.default(scopes=[BIGQUERY_SCOPE])
        merged_headers = dict(headers or {})
        if project_id:
            # Billing/quota attribution for the managed MCP server
            merged_headers.setdefault("x-goog-user-project", project_id)
        return httpx.AsyncClient(
            headers=merged_headers,
            timeout=timeout if timeout is not None else httpx.Timeout(60.0, read=300.0),
            auth=auth or _GoogleBearerAuth(credentials),
            follow_redirects=True,
        )

    return McpToolset(
        connection_params=StreamableHTTPConnectionParams(
            url=BIGQUERY_MCP_URL,
            httpx_client_factory=client_factory,
        )
    )
