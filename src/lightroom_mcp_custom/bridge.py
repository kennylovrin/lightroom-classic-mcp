from __future__ import annotations

import asyncio
import contextlib
import json
import logging
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any

LOGGER = logging.getLogger(__name__)


class BridgeError(RuntimeError):
    """Base bridge failure."""


class BridgeConnectionError(BridgeError):
    """Raised when bridge cannot connect to Lightroom plugin sockets."""


class BridgeCommandError(BridgeError):
    """Raised when a command fails or times out."""


@dataclass
class BridgeConfig:
    host: str = "127.0.0.1"
    port_file: Path = Path("/tmp/lightroom_mcp_custom_ports.json")
    connect_timeout_s: float = 20.0
    command_timeout_s: float = 30.0
    reconnect_attempts: int = 1
    reconnect_backoff_s: float = 0.5
    max_port_file_age_s: float = 3600.0


class AsyncLightroomBridge:
    def __init__(self, config: BridgeConfig | None = None) -> None:
        self.config = config or BridgeConfig()
        self._lock = asyncio.Lock()
        self._pending: dict[str, asyncio.Future[dict[str, Any]]] = {}

        self._rx_reader: asyncio.StreamReader | None = None
        self._rx_writer: asyncio.StreamWriter | None = None
        self._tx_reader: asyncio.StreamReader | None = None
        self._tx_writer: asyncio.StreamWriter | None = None
        self._reader_tasks: list[asyncio.Task[None]] = []

    async def connect(self) -> None:
        async with self._lock:
            if self.is_connected:
                return

            deadline = time.monotonic() + self.config.connect_timeout_s
            last_error: Exception | None = None

            while time.monotonic() < deadline:
                send_port, receive_port = await self._wait_for_ports(deadline=deadline)

                rx_reader: asyncio.StreamReader | None = None
                rx_writer: asyncio.StreamWriter | None = None
                tx_reader: asyncio.StreamReader | None = None
                tx_writer: asyncio.StreamWriter | None = None
                try:
                    # Plugin's "send" socket -> we read responses/events from it.
                    rx_reader, rx_writer = await asyncio.open_connection(self.config.host, send_port)
                    # Plugin's "receive" socket -> we write requests to it (and may also
                    # receive protocol acks or replies depending on socket state).
                    tx_reader, tx_writer = await asyncio.open_connection(self.config.host, receive_port)
                except OSError as exc:
                    if rx_writer is not None:
                        rx_writer.close()
                        with contextlib.suppress(Exception):
                            await rx_writer.wait_closed()
                    if tx_writer is not None:
                        tx_writer.close()
                        with contextlib.suppress(Exception):
                            await tx_writer.wait_closed()
                    last_error = exc
                    LOGGER.warning(
                        "Failed to connect to plugin sockets (send=%s, receive=%s): %s. Retrying.",
                        send_port,
                        receive_port,
                        exc,
                    )
                    await asyncio.sleep(0.25)
                    continue

                self._rx_reader = rx_reader
                self._rx_writer = rx_writer
                self._tx_reader = tx_reader
                self._tx_writer = tx_writer
                self._reader_tasks = [
                    asyncio.create_task(
                        self._read_loop(self._rx_reader, "send-port"),
                        name="lightroom-bridge-reader-send",
                    ),
                    asyncio.create_task(
                        self._read_loop(self._tx_reader, "receive-port"),
                        name="lightroom-bridge-reader-receive",
                    ),
                ]

                LOGGER.info(
                    "Connected to Lightroom bridge on ports send=%s receive=%s",
                    send_port,
                    receive_port,
                )
                return

            raise BridgeConnectionError(
                "Timed out connecting to Lightroom plugin sockets."
                + (f" Last error: {last_error}" if last_error else "")
            )

    async def close(self) -> None:
        async with self._lock:
            if self._reader_tasks:
                for task in self._reader_tasks:
                    task.cancel()
                for task in self._reader_tasks:
                    with contextlib.suppress(asyncio.CancelledError):
                        await task
                self._reader_tasks = []

            await self._invalidate_connection("Bridge was closed")

    @property
    def is_connected(self) -> bool:
        return (
            self._tx_writer is not None
            and self._rx_reader is not None
            and self._tx_reader is not None
            and bool(self._reader_tasks)
            and all(not task.done() for task in self._reader_tasks)
        )

    async def send_command(
        self,
        command: str,
        params: dict[str, Any] | None = None,
        timeout_s: float | None = None,
    ) -> dict[str, Any]:
        if not command:
            raise ValueError("command must be non-empty")

        attempts = max(1, int(self.config.reconnect_attempts) + 1)
        last_error: BridgeError | None = None
        for attempt in range(attempts):
            try:
                return await self._send_command_once(
                    command=command,
                    params=params,
                    timeout_s=timeout_s,
                )
            except BridgeConnectionError as exc:
                last_error = exc
                await self._invalidate_connection(str(exc))
                if attempt + 1 >= attempts:
                    break
                await asyncio.sleep(self.config.reconnect_backoff_s * (attempt + 1))
            except BridgeCommandError as exc:
                # A timeout on the first command after reconnect often means the
                # plugin has a stale sender socket; force reconnect and retry.
                if "command timed out:" not in str(exc):
                    raise
                last_error = exc
                await self._invalidate_connection(str(exc))
                if attempt + 1 >= attempts:
                    break
                await asyncio.sleep(self.config.reconnect_backoff_s * (attempt + 1))

        raise BridgeConnectionError(
            f"command failed after reconnect attempts: {command}"
            + (f" ({last_error})" if last_error else "")
        )

    async def _send_command_once(
        self,
        command: str,
        params: dict[str, Any] | None = None,
        timeout_s: float | None = None,
    ) -> dict[str, Any]:
        if not self.is_connected:
            await self.connect()

        request_id = str(uuid.uuid4())
        loop = asyncio.get_running_loop()
        future: asyncio.Future[dict[str, Any]] = loop.create_future()
        self._pending[request_id] = future

        payload = {
            "id": request_id,
            "command": command,
            "params": params or {},
        }
        message = json.dumps(payload, separators=(",", ":")) + "\n"

        writer = self._tx_writer
        if writer is None:
            self._pending.pop(request_id, None)
            raise BridgeConnectionError("bridge writer is unavailable")

        try:
            writer.write(message.encode("utf-8"))
            await writer.drain()
        except OSError as exc:
            self._pending.pop(request_id, None)
            raise BridgeConnectionError(f"failed writing command '{command}': {exc}") from exc

        timeout = timeout_s if timeout_s is not None else self.config.command_timeout_s
        try:
            response = await asyncio.wait_for(future, timeout=timeout)
        except asyncio.TimeoutError as exc:
            self._pending.pop(request_id, None)
            raise BridgeCommandError(f"command timed out: {command}") from exc

        if not response.get("success", False):
            err = response.get("error") or {}
            code = err.get("code", "UNKNOWN")
            message = err.get("message", "unknown Lightroom error")
            raise BridgeCommandError(f"{command} failed ({code}): {message}")

        return response.get("result", {})

    async def _wait_for_ports(self, deadline: float | None = None) -> tuple[int, int]:
        if deadline is None:
            deadline = time.monotonic() + self.config.connect_timeout_s
        while True:
            if self.config.port_file.exists():
                try:
                    payload = json.loads(self.config.port_file.read_text(encoding="utf-8"))
                    send_port = int(payload["send_port"])
                    receive_port = int(payload["receive_port"])

                    # Stale metadata should not be fatal; log and continue waiting.
                    started_at = payload.get("started_at")
                    if started_at is not None:
                        try:
                            age_s = time.time() - float(started_at)
                            if age_s > self.config.max_port_file_age_s:
                                LOGGER.warning(
                                    "Ignoring stale Lightroom port file (age %.1fs): %s",
                                    age_s,
                                    self.config.port_file,
                                )
                                await asyncio.sleep(0.25)
                                continue
                        except (TypeError, ValueError):
                            LOGGER.debug("Port file has non-numeric started_at: %r", started_at)

                    return send_port, receive_port
                except (ValueError, KeyError, json.JSONDecodeError) as exc:
                    raise BridgeConnectionError(
                        f"Invalid port file format at {self.config.port_file}: {exc}"
                    ) from exc

            if time.monotonic() >= deadline:
                raise BridgeConnectionError(
                    "Timed out waiting for Lightroom plugin port file. "
                    "Ensure plugin 'Lightroom MCP Custom' is installed and enabled."
                )

            await asyncio.sleep(0.25)

    async def _invalidate_connection(self, reason: str) -> None:
        tx_writer, rx_writer = self._tx_writer, self._rx_writer

        self._tx_writer = None
        self._tx_reader = None
        self._rx_writer = None
        self._rx_reader = None
        self._reader_tasks = []

        seen: set[int] = set()
        for writer in (tx_writer, rx_writer):
            if writer is not None:
                marker = id(writer)
                if marker in seen:
                    continue
                seen.add(marker)
                # Abort transport first to ensure Lightroom sees a hard close
                # and drops stale sender sockets between short-lived clients.
                try:
                    writer.transport.abort()
                except Exception:
                    pass
                writer.close()
                with contextlib.suppress(Exception):
                    await writer.wait_closed()

        for request_id, future in list(self._pending.items()):
            self._pending.pop(request_id, None)
            if not future.done():
                future.set_exception(BridgeConnectionError(reason))

    async def _read_loop(self, reader: asyncio.StreamReader | None, label: str) -> None:
        if reader is None:
            return

        try:
            while True:
                line = await reader.readline()
                if not line:
                    raise BridgeConnectionError(f"Lightroom bridge {label} socket closed")

                raw = line.decode("utf-8", errors="replace").strip()
                if not raw:
                    continue
                if raw.lower() == "ok":
                    # LrSocket control acknowledgement, not a JSON payload.
                    continue

                try:
                    message = json.loads(raw)
                except json.JSONDecodeError:
                    LOGGER.debug("Dropping non-JSON message from Lightroom (%s): %r", label, raw)
                    continue

                request_id = message.get("id")
                if request_id and request_id in self._pending:
                    future = self._pending.pop(request_id)
                    if not future.done():
                        future.set_result(message)
                else:
                    LOGGER.debug("Bridge event: %s", message)
        except asyncio.CancelledError:
            raise
        except Exception as exc:  # pragma: no cover
            LOGGER.error("Bridge reader loop stopped (%s): %s", label, exc)
            await self._invalidate_connection(str(exc))
