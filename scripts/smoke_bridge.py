#!/usr/bin/env python3
from __future__ import annotations

import asyncio
import json
from pathlib import Path

from lightroom_mcp_custom.bridge import AsyncLightroomBridge


async def main() -> None:
    bridge = AsyncLightroomBridge()
    try:
        await bridge.connect()
        ping = await bridge.send_command("system.ping")
        status = await bridge.send_command("system.status")
        commands = await bridge.send_command("system.list_commands")
        print(json.dumps({
            "ping": ping,
            "status": status,
            "commands": commands,
        }, indent=2))
    finally:
        await bridge.close()


if __name__ == "__main__":
    asyncio.run(main())
