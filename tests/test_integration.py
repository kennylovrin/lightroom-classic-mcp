"""Integration tests for Lightroom MCP server."""
import asyncio
import os

import pytest
from lightroom_mcp_custom.bridge import AsyncLightroomBridge, BridgeConnectionError
from lightroom_mcp_custom.server import get_active_photo_file, get_selected_photo_files

pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.integration,
    pytest.mark.skipif(
        os.getenv("LIGHTROOM_RUN_INTEGRATION") != "1",
        reason="set LIGHTROOM_RUN_INTEGRATION=1 to run live Lightroom integration tests",
    ),
]

async def test_bridge_connection():
    """Test basic bridge connectivity."""
    bridge = AsyncLightroomBridge()
    try:
        await bridge.connect()
        result = await bridge.send_command("system.ping")
        assert result is not None
        assert "pong" in result or "now" in result
    except BridgeConnectionError as exc:
        pytest.skip(f"Lightroom not available: {exc}")
    finally:
        await bridge.close()


async def test_bridge_reconnection():
    """Test bridge can reconnect after disconnect."""
    bridge = AsyncLightroomBridge()
    try:
        # First connection
        await bridge.connect()
        result1 = await bridge.send_command("system.ping")
        assert result1 is not None

        # Close and reconnect
        await bridge.close()
        await asyncio.sleep(1)

        # Second connection should work
        await bridge.connect()
        result2 = await bridge.send_command("system.ping")
        assert result2 is not None
    except BridgeConnectionError as exc:
        pytest.skip(f"Lightroom not available: {exc}")
    finally:
        await bridge.close()


async def test_get_selected_photos():
    """Test catalog.get_selected_photos command."""
    bridge = AsyncLightroomBridge()
    try:
        await bridge.connect()
        result = await bridge.send_command("catalog.get_selected_photos", {"limit": 10})
        assert result is not None
        assert "photos" in result or "count" in result
    except BridgeConnectionError as exc:
        pytest.skip(f"Lightroom not available: {exc}")
    finally:
        await bridge.close()


async def test_get_active_photo_file():
    """Test active photo inspection payload."""
    try:
        result = await get_active_photo_file()
        assert result is not None
        photo = result.get("photo")
        assert isinstance(photo, dict)
        assert "inspection" in photo
        assert "path" in photo["inspection"]
    except RuntimeError as exc:
        pytest.skip(f"Lightroom not available: {exc}")


async def test_get_selected_photo_files():
    """Test selected photo inspection payload."""
    try:
        result = await get_selected_photo_files(limit=10)
        assert result is not None
        assert "photos" in result
        photos = result["photos"]
        assert isinstance(photos, list)
        if photos:
            assert "inspection" in photos[0]
            assert "path" in photos[0]["inspection"]
    except RuntimeError as exc:
        pytest.skip(f"Lightroom not available: {exc}")


async def test_list_commands():
    """Test system.list_commands."""
    bridge = AsyncLightroomBridge()
    try:
        await bridge.connect()
        result = await bridge.send_command("system.list_commands")
        assert result is not None
        assert "commands" in result or isinstance(result, (list, dict))
    except BridgeConnectionError as exc:
        pytest.skip(f"Lightroom not available: {exc}")
    finally:
        await bridge.close()


async def test_concurrent_commands():
    """Test multiple concurrent commands."""
    bridge = AsyncLightroomBridge()
    try:
        await bridge.connect()

        # Send multiple commands concurrently
        tasks = [
            bridge.send_command("system.ping"),
            bridge.send_command("system.status"),
            bridge.send_command("system.list_commands"),
        ]

        results = await asyncio.gather(*tasks, return_exceptions=True)

        # All should succeed
        for result in results:
            if isinstance(result, Exception):
                raise result
            assert result is not None
    except BridgeConnectionError as exc:
        pytest.skip(f"Lightroom not available: {exc}")
    finally:
        await bridge.close()
