#!/usr/bin/env python3
"""Local-only test fixture for Noray's documented rendezvous/UDP relay protocol."""
import asyncio
import json
from pathlib import Path
import secrets


class Fixture:
    def __init__(self, directory, block_direct=False):
        self.directory = Path(directory)
        self.block_direct = block_direct
        self.hosts = {}
        self.pids = {}
        self.addresses = {}
        self.relays = []
        self.forwarded = 0

    async def start(self):
        loop = asyncio.get_running_loop()
        udp, _ = await loop.create_datagram_endpoint(lambda: Registrar(self), local_addr=("127.0.0.1", 0))
        server = await asyncio.start_server(self.client, "127.0.0.1", 0, limit=8192)
        self.directory.joinpath("service.json").write_text(json.dumps({
            "host": "127.0.0.1", "port": server.sockets[0].getsockname()[1],
            "registrar": udp.get_extra_info("sockname")[1]}))
        try:
            async with server:
                await server.serve_forever()
        finally:
            udp.close()
            for relay in self.relays:
                relay.close()

    async def send(self, host, message):
        host["writer"].write((message + "\n").encode())
        await host["writer"].drain()

    async def client(self, reader, writer):
        own = None
        try:
            while line := await reader.readline():
                parts = line.decode().strip().split(" ", 1)
                if parts[0] == "register-host":
                    oid, pid = secrets.token_urlsafe(16), secrets.token_urlsafe(32)
                    own = {"oid": oid, "pid": pid, "writer": writer, "address": None, "relay": None}
                    self.hosts[oid] = own
                    self.pids[pid] = own
                    await self.send(own, "set-oid " + oid)
                    await self.send(own, "set-pid " + pid)
                elif own and len(parts) == 2 and parts[0] in ("connect", "connect-relay"):
                    target = self.hosts.get(parts[1])
                    if not target or not target["address"] or not own["address"]:
                        await self.send(own, "error unavailable")
                        continue
                    if parts[0] == "connect":
                        if self.block_direct:
                            await self.send(own, "connect 127.0.0.1:1")
                            await self.send(target, "connect 127.0.0.1:1")
                        else:
                            await self.send(own, "connect %s:%d" % target["address"])
                            await self.send(target, "connect %s:%d" % own["address"])
                    else:
                        for host in (own, target):
                            if host["relay"] is None:
                                transport, _ = await asyncio.get_running_loop().create_datagram_endpoint(
                                    lambda host=host: Relay(self, host), local_addr=("127.0.0.1", 0))
                                host["relay"] = transport
                                self.relays.append(transport)
                        await self.send(own, "connect-relay %d" % target["relay"].get_extra_info("sockname")[1])
                        await self.send(target, "connect-relay %d" % own["relay"].get_extra_info("sockname")[1])
        except (ConnectionError, ValueError, asyncio.LimitOverrunError):
            pass
        finally:
            if own:
                self.hosts.pop(own["oid"], None)
                self.pids.pop(own["pid"], None)
            writer.close()


class Registrar(asyncio.DatagramProtocol):
    def __init__(self, fixture):
        self.fixture = fixture

    def connection_made(self, transport):
        self.transport = transport

    def datagram_received(self, data, address):
        host = self.fixture.pids.get(data.decode(errors="ignore"))
        if host:
            host["address"] = address
            self.fixture.addresses[address] = host
            self.transport.sendto(b"OK", address)


class Relay(asyncio.DatagramProtocol):
    def __init__(self, fixture, target):
        self.fixture, self.target = fixture, target

    def datagram_received(self, data, address):
        sender = self.fixture.addresses.get(address)
        if sender and sender["relay"]:
            sender["relay"].sendto(data, self.target["address"])
            self.fixture.forwarded += 1


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("directory")
    parser.add_argument("--block-direct", action="store_true")
    args = parser.parse_args()
    asyncio.run(Fixture(args.directory, args.block_direct).start())
