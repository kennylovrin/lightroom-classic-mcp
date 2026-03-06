#!/usr/bin/env python3
"""Diagnostic tool for Lightroom bridge connectivity issues."""
import asyncio
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from lightroom_mcp_custom.bridge import AsyncLightroomBridge, BridgeConnectionError


async def check_port_file():
    """Check if port file exists and is valid."""
    port_file = Path("/tmp/lightroom_mcp_custom_ports.json")

    if not port_file.exists():
        print("❌ Port file does not exist")
        return None

    try:
        data = json.loads(port_file.read_text())
        age = time.time() - data.get("started_at", 0)
        print(f"✓ Port file exists: {port_file}")
        print(f"  Send port: {data.get('send_port')}")
        print(f"  Receive port: {data.get('receive_port')}")
        print(f"  Session: {data.get('session_id')}")
        print(f"  Age: {age:.1f}s")
        return data
    except Exception as e:
        print(f"❌ Port file is invalid: {e}")
        return None


async def test_socket_listening(host, port):
    """Test if a port is actually listening."""
    try:
        reader, writer = await asyncio.wait_for(
            asyncio.open_connection(host, port), timeout=2.0
        )
        writer.close()
        await writer.wait_closed()
        return True
    except Exception:
        return False


async def test_connection():
    """Test full bridge connection."""
    bridge = AsyncLightroomBridge()
    try:
        print("\n🔌 Testing bridge connection...")
        await bridge.connect()
        print("✓ Bridge connected successfully")

        print("\n📡 Testing system.ping...")
        result = await bridge.send_command("system.ping")
        print(f"✓ Ping successful: {result}")

        print("\n📋 Testing system.status...")
        result = await bridge.send_command("system.status")
        print(f"✓ Status: {result}")

        print("\n📚 Testing system.list_commands...")
        result = await bridge.send_command("system.list_commands")
        commands = result.get("commands", [])
        print(f"✓ Found {len(commands)} commands")

        return True
    except BridgeConnectionError as exc:
        print(f"❌ Connection failed: {exc}")
        return False
    except Exception as exc:
        print(f"❌ Unexpected error: {exc}")
        return False
    finally:
        await bridge.close()


async def test_reconnection():
    """Test if bridge can reconnect after disconnect."""
    bridge = AsyncLightroomBridge()
    try:
        print("\n🔄 Testing reconnection...")

        # First connection
        print("  Attempt 1...")
        await bridge.connect()
        result1 = await bridge.send_command("system.ping")
        print(f"  ✓ First ping: {result1}")

        # Close
        print("  Closing bridge...")
        await bridge.close()
        await asyncio.sleep(2)

        # Second connection
        print("  Attempt 2...")
        await bridge.connect()
        result2 = await bridge.send_command("system.ping")
        print(f"  ✓ Second ping: {result2}")

        print("✓ Reconnection test passed")
        return True
    except Exception as exc:
        print(f"❌ Reconnection test failed: {exc}")
        return False
    finally:
        await bridge.close()


async def main():
    """Run all diagnostics."""
    print("=" * 60)
    print("Lightroom MCP Bridge Diagnostics")
    print("=" * 60)

    # Check port file
    print("\n1️⃣ Checking port file...")
    port_data = await check_port_file()

    if port_data:
        # Check if ports are listening
        print("\n2️⃣ Checking if ports are listening...")
        send_port = port_data.get("send_port")
        receive_port = port_data.get("receive_port")

        send_ok = await test_socket_listening("127.0.0.1", send_port)
        receive_ok = await test_socket_listening("127.0.0.1", receive_port)

        if send_ok:
            print(f"✓ Send port {send_port} is listening")
        else:
            print(f"❌ Send port {send_port} is NOT listening")

        if receive_ok:
            print(f"✓ Receive port {receive_port} is listening")
        else:
            print(f"❌ Receive port {receive_port} is NOT listening")

    # Test connection
    print("\n3️⃣ Testing bridge connection...")
    conn_ok = await test_connection()

    # Test reconnection
    if conn_ok:
        print("\n4️⃣ Testing reconnection...")
        await test_reconnection()

    print("\n" + "=" * 60)
    if conn_ok:
        print("✅ All tests passed!")
    else:
        print("❌ Some tests failed - bridge needs work")
    print("=" * 60)


if __name__ == "__main__":
    asyncio.run(main())
