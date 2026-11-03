# Friend connections for testing, Steam later

The current Windows demo build provides Host a game / Create game / Copy private invite and Join a game / Paste invite / Join friend. No account, Steam install, port entry, manual router configuration or developer service credentials are required for that normal flow. The game uses Noray, a free MIT-licensed connection orchestrator and UDP relay, through its public test endpoint foxssake.studio:8890. The UDP registrar is on port 8809. The public endpoint is explicitly intended by its maintainer for testing, not a production availability guarantee.

Gameplay runs on the host player's PC. Noray exchanges endpoints so the game can first try a direct UDP path, with automatic relay fallback when that fails. Relay machines forward encrypted packets and do not execute the match simulation. This is peer-hosted gameplay with supporting connection infrastructure, rather than a dedicated game server.

## Connection and trust boundaries

1. The host creates an ephemeral RSA key and self-signed certificate, a cryptographically random 256-bit invitation secret, and a 15-minute invitation expiry. No private key is written to disk or sent to the connection service. A temporary public-certificate file works around Godot 4.7.2's NUL-terminated save_to_string behavior and is immediately deleted.
2. The private invitation carries the host's certificate, the secret, the ephemeral rendezvous ID and expiry. It is a bearer invitation; the person holding it can be the second player. The UI asks the host to send it privately. It is not a verified Steam/account identity.
3. A bounded plaintext UDP handshake opens a path through routers before an encrypted ENet peer owns the port. It contains no secret or game state and never authenticates a player.
4. Godot establishes DTLS using TLSOptions.client with the certificate supplied in the private invitation and a matching hostname. Certificate validation is mandatory; there is no unsafe TLS or plaintext fallback in friend mode.
5. SceneMultiplayer.auth_callback holds the peer outside normal game RPC processing. A fresh 32-byte server nonce and role-separated HMAC-SHA256 proofs validate the invitation in both directions. Proofs use constant-time comparison, expire, and cannot simply be replayed against a fresh nonce. Pending authentication and message sizes are bounded. The match accepts one authenticated guest and then refuses new peers.
6. The host remains authoritative for movement validation, health, hits, ammunition, reloads, level selection, scoring and rounds. Guests send intentions. Object decoding stays disabled.
7. Timeouts are bounded; cancellation closes rendezvous, UDP and authentication state. Peer resources are released outside multiplayer signal polling. Closing or joining invalidates the active invite; established matches can continue after invitation expiry.

The application never prints or persists private invitation tokens or private keys. Tests exchange invitations only inside a mode-0700 temporary directory, which is removed afterward. The user-controlled clipboard retains a copied invite according to the operating system's normal clipboard behavior.

The connection service sees rendezvous identifiers and network addresses. Its control channel is not the source of trust for gameplay: the privately shared certificate and secret bind the DTLS connection and authorization. The service or network can still disrupt connectivity. Direct connections disclose peer addresses to each other. The connection layer does not claim to conceal addresses, prevent a trusted host from modifying their own game, or provide a public competitive anti-cheat service.

LAN / direct-IP is an explicit separate option using the original unencrypted ENet transport. It does not inherit the private invitation security properties. Friend mode never silently downgrades to it.

## Implementation boundary for Steam

FriendConnection owns rendezvous, timeout, retry, NAT traversal, relay fallback, private invites and encrypted MultiplayerPeer creation. It reports invite_ready, status_changed and failed, and supports host_game, join_game, connected and close. Main retains the existing host/guest gameplay callbacks and authoritative RPCs. A future Steam adapter would supply private Steam lobbies/invites, Steam identity and its MultiplayerPeer through that boundary. Steam integration is not included and will require the game's actual Steamworks setup; no public test App ID is shipped as a production credential.

## Evidence and limits

Two real Godot game processes completed a friend-invite match through Noray's public service, including forced encrypted relay use. The normal public-service automatic path was also tested. Local-only Noray protocol fixtures exercised forced direct failure with relay recovery, incorrect invitation secrets, mismatched certificates, and successful legitimate joining after rejection. Malformed/expired invites, cancellation and UI entry points have separate bounded tests. The certificate rejection case intentionally logs native TLS handshake errors; it never falls back to unverified transport.

These are headless tests on Linux, not two Windows machines on separate home networks. Windows execution, restrictive corporate/mobile networks, sustained packet loss and long sessions still need playtesting. Noray's community test service can be unavailable. This implementation received a focused source review of the invite/authentication paths; it is not independently security audited.

## Reproducible checks

See README.md for commands. tools/test_friends.py runs for at most 60 seconds, supports --local, --relay, --block-direct, --wrong-secret and --wrong-certificate, and stores redacted results under artifacts/friends-*.log. tools/noray_fixture.py is a local-only protocol test fixture, not a deployed service. Gameplay and service configuration can be overridden programmatically in tests; invitations cannot redirect the application to an arbitrary rendezvous service.

Primary references: [Noray source and protocol](https://github.com/foxssake/noray), [netfox public test service](https://foxssake.github.io/netfox/latest/hosting/), [Godot ENetConnection / DTLS](https://docs.godotengine.org/en/4.7/classes/class_enetconnection.html), [SceneMultiplayer authentication gate](https://docs.godotengine.org/en/4.7/classes/class_scenemultiplayer.html), [Godot cryptography primitives](https://docs.godotengine.org/en/4.7/classes/class_crypto.html), [future Steam transport](https://partner.steamgames.com/doc/features/multiplayer/networking).

Demo compatibility: private invites carry the build ID and authentication proofs include it. A different build is rejected before gameplay. Both players explicitly Ready after authentication; rematches return to the same ready room. The free public endpoint was rechecked against the maintainer hosting documentation on 2 November 2026. Direct gameplay and encrypted relay are both supported; two separate home networks still require human verification.
