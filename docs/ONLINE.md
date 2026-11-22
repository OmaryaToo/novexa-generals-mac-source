# Online play (GeneralsOnline / NGMP)

## Status (2026-11-22, verified on M5)
* Local server: GeneralsOnlineGameServer (AGPL-3.0, .NET 10) built in **Debug** and run against a private MariaDB
  (`scripts/server/setup-local.sh`, `run-local.sh`, `db.sh`). Data + random secrets in `~/Library/NovexaGeneralsServer`
  (secrets.env, mode 600; never committed). Configured only via environment variables.
* The real Zero Hour client logged in (`DEV_ACCOUNT_0`), fetched stats, connected the lobby WebSocket, and
  initialised the P2P mesh (`NetworkMesh initialized`).
* **Two-Mac LAN match verified (2026-11-22):** two Apple Silicon Macs (DEV_ACCOUNT_0 / DEV_ACCOUNT_1) joined lobby 0
  on a LAN server (private IP, port 9001), the match started, was recorded in `match_history`, and the user confirmed it played smoothly with no desync.
* Engine patch `engine/patches/0001-ngmp-runtime-server-selection.patch`: `NGMP_SERVER_HOST/PORT/SSL` and
  `NGMP_WEB_PORTAL_URL` env vars override build-time defaults. The launcher sets them from Settings → Online.
* P2P (Valve GameNetworkingSockets) needs Homebrew `protobuf` + `abseil` at build time; `stage-engine.sh` bundles
  them (and all other Homebrew dylibs) recursively.

## Login modes
* Host is localhost / private IP → client uses dev bypass code; Debug server auto-creates `DEV_ACCOUNT_n`.
* Public domain → client requests a LoginCode and opens `<portal>/login/?gamecode=…`; a web portal must
  authenticate the player and call the server's `LoginCode` endpoint with an API key. Not implemented yet.

## Other services
* online.generalsx.org — the GeneralsX project's public server (same protocol). Not tested with this build.
* playgenerals.online — separate Windows-only service with its own client, OpenID login and EasyAntiCheat;
  not compatible with this client (see conversation notes / README).

## Public deployment (2026-11-22)
* `https://play.novexa-jo.com` behind Cloudflare: VersionCheck 200, MOTD 401 without token, dev bypass refused,
  `/login/` redirects to Discord OAuth. Owner signed in from the game with Discord. Launcher default = NOVEXA Online.
* Origin server IP (kept private) from outside: 3306, 9001, 5080, 443 closed; 80 open (see below).

## Launcher policy
Players always connect to **NOVEXA Online** (`play.novexa-jo.com`, 443, HTTPS); there is no server choice in the UI
and saved per-user choices are ignored. Developers can override per launch with the hidden environment variable
`NOVEXA_DEV_SERVER=host:port[:ssl]`, e.g. `NOVEXA_DEV_SERVER=127.0.0.1:9001` for `scripts/server/run-local.sh`.
