from typing import Any, List, Optional

import google.auth
from google.auth.transport.requests import Request
from mcp import ClientSession
from mcp.client.sse import sse_client
from mcp.types import CallToolResult


class BQMCPClientAdapter:
    """
    Adapter for interacting with the official Google Cloud BigQuery MCP Server.
    Uses the managed endpoint via SSE.
    """

    def __init__(self, project_id: str, location: str):
        self.project_id = project_id
        self.location = location
        self._endpoint = "https://bigquery.googleapis.com/mcp"
        self._session: Optional[ClientSession] = None
        self._exit_stack = None

    async def _get_auth_header(self) -> str:
        credentials, _ = google.auth.default(
            scopes=["https://www.googleapis.com/auth/cloud-platform"]
        )
        request = Request()
        credentials.refresh(request)
        return f"Bearer {credentials.token}"

    async def connect(self):
        """Establish connection to the managed BigQuery MCP server."""
        from contextlib import AsyncExitStack

        self._exit_stack = AsyncExitStack()

        headers = {
            "Authorization": await self._get_auth_header(),
            "X-Goog-User-Project": self.project_id,
        }

        # Connect via SSE
        sse_ctx = sse_client(url=self._endpoint, headers=headers)
        self._streams = await self._exit_stack.enter_async_context(sse_ctx)

        # Initialize session
        self._session = await self._exit_stack.enter_async_context(
            ClientSession(self._streams[0], self._streams[1])
        )

        await self._session.initialize()
        return True

    async def get_tools(self) -> List[Any]:
        """Get available tools from the BigQuery MCP Server."""
        if not self._session:
            await self.connect()
        assert self._session is not None
        response = await self._session.list_tools()
        return response.tools

    async def call_tool(self, tool_name: str, arguments: dict) -> CallToolResult:
        """Call a specific tool on the BigQuery MCP Server."""
        if not self._session:
            await self.connect()
        assert self._session is not None
        return await self._session.call_tool(tool_name, arguments)

    async def disconnect(self):
        """Close the MCP connection."""
        if self._exit_stack:
            await self._exit_stack.aclose()
            self._session = None
            self._streams = None
