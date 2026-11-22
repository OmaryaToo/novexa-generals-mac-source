# Deploying NOVEXA Generals Online on the Windows VPS

**For the Claude Code session running on the VPS.** You are continuing work started on the
developer's MacBook. Read this whole file first. The owner prefers Arabic; reply in Arabic.

## What this project is
NOVEXA Generals Mac runs *C&C Generals / Zero Hour* natively on Apple Silicon (GeneralsX engine, a GPL fork
of EA's source). Online play uses **GeneralsOnlineGameServer** (`server/upstream/GeneralsOnlineGameServer`,
AGPL-3.0, .NET 10, MariaDB): REST API, WebSocket lobby, matchmaking, and a P2P match mesh between clients.

## Already verified on the Mac (2026-11-22)
* Server runs against MariaDB. Real game clients logged in, joined a lobby, and **two Macs played a smooth
  online match on the LAN** (recorded in `match_history`).
* **Release** build in Production mode: the dev login bypass (`ILOVECODE`) is refused, and `GET LoginCode`
  issues codes. `POST LoginCode` with a wrong `X-Api-Key` returns 403; with the right key it returns 200.
  `CheckLogin` then returns a session token. This is exactly the path the phase 2 portal will use.
* `dotnet publish -c Release` passes (Release treats warnings as errors).

## Target architecture
```
Players ──HTTPS/WSS 443──▶ Caddy (play.novexa-jo.com, Let's Encrypt)      [phase 3]
                            ├─ /login*, /auth/*, /motd.txt ─▶ NOVEXA login portal :5080 (Discord) [phase 2]
                            └─ everything else (REST + /ws) ─▶ GenOnlineService :9001           [phase 1]
GenOnlineService ─▶ MariaDB 127.0.0.1:3306 (localhost only)
```
The game client derives every URL from one host: REST `https://HOST/env/live/contract/1/...`,
WebSocket `wss://HOST/ws`, browser login `https://HOST/login/?gamecode=CODE&v=VER`, MOTD `https://HOST/motd.txt`.

## Rules
* **Never run a Debug build of the server on this public machine.** Debug auto-creates accounts for anyone.
* **Never commit secrets.** Secrets live in `C:\ProgramData\NovexaGenerals\secrets.json` (Administrators/SYSTEM
  only). Production config is `C:\NovexaGenerals\GameServer\appsettings.Production.json`, outside the repo.
  Never edit `server/upstream/.../appsettings.json`.
* Ask the owner before opening firewall ports, changing DNS, or anything outside these folders. He types any passwords
  himself; never ask him to paste a secret into chat.
* Report results honestly. Don't claim something works unless you tested it.

---

## Phase 1: game server (do this now)
Run in an **elevated** PowerShell from the repo root. If scripts are blocked, run
`Set-ExecutionPolicy -Scope Process Bypass` first. It only affects that window.

```powershell
cd <repo>\server\deploy\windows
.\1-Install-Prereqs.ps1          # winget: .NET 10 SDK + MariaDB (random root password -> secrets.json)
# open a NEW elevated PowerShell so PATH refreshes
.\2-Setup-Database.ps1           # db + user + schema (19 tables), MariaDB bound to 127.0.0.1
.\3-Install-GameServer.ps1 -PublicHost <VPS public IPv4> -OpenTestPort
.\4-Test-GameServer.ps1          # expect VersionCheck 200, MOTD 401, LoginCode issued
```
* `3-` publishes Release to `C:\NovexaGenerals\GameServer`, writes the production config, and registers the
  scheduled task **"NOVEXA GeneralsOnline GameServer"**. The task runs at boot as SYSTEM and restarts on failure.
  The server's working directory must be the app folder, because it reads `data\*.json` relative to it.
  Logs go to `C:\ProgramData\NovexaGenerals\gameserver.log`.
* `-OpenTestPort` adds a temporary inbound rule for TCP 9001 so the owner can test from the Mac:
  `curl -X POST http://<VPS-IP>:9001/env/live/contract/1/VersionCheck -d '{}'` should return 200.
  Ask the owner to also open 9001 in the hosting provider's panel if it has its own firewall.
* These scripts were written on a Mac and only **syntax-checked**. They have never been run on Windows.
  Expect to fix small things: winget package IDs, the MariaDB MSI override properties, and PATH refresh. If
  winget isn't available on this Windows Server, install .NET 10 SDK and MariaDB 11.x from their official sites.
* Phase 1 is done when `4-Test-GameServer.ps1` passes, the Mac's curl returns 200, and the task survives a VPS
  reboot.

Note: actual game logins from public IPs won't work until phase 2. The client only uses dev login for private
IPs/localhost. For public hosts it opens the browser portal.

## Phase 2: Discord login portal (after phase 1)
Build a small ASP.NET Core (.NET 10) service in `server/portal/NovexaLoginPortal`, listening on 127.0.0.1:5080:
1. `GET /login/?gamecode=CODE&v=VER`. Validate CODE `^[A-Za-z0-9]{16,64}$`. Store `state -> code` for 10 min
   and redirect to Discord OAuth `https://discord.com/oauth2/authorize` (scope `identify`), with
   redirect URI `https://play.novexa-jo.com/auth/discord/callback`.
2. `GET /auth/discord/callback`. Exchange the code at `https://discord.com/api/v10/oauth2/token`, then call
   `GET /users/@me`. Find the user `WHERE discord_id = id` in table `users`. If none, insert
   `account_type = 1` (Discord), `discord_id`, `discord_username`, and a unique `displayname` (≤16 chars,
   `[A-Za-z0-9_-]`). `user_id` is AUTO_INCREMENT. Refuse `banned = 1`.
3. `POST http://127.0.0.1:9001/env/live/contract/1/LoginCode` with header `X-Api-Key: <webserver_key from
   secrets.json>` and JSON `{"env":"live","code":CODE,"user_id":ID,"success":true}` (`success:false` on
   cancel). The game is polling `CheckLogin` and logs in.
4. Show a success page in NOVEXA style: dark `#0B0A14`, gradient `#7C3AED → #EC4899 → #FB923C`, fonts
   Alexandria / Instrument Sans.
5. Also serve `GET /motd.txt`.
Configure it with environment variables only: `DISCORD_CLIENT_ID`, `DISCORD_CLIENT_SECRET`, `WEBSERVER_KEY`,
`DB_*`, `PORTAL_PUBLIC_URL`. The owner creates the Discord application himself at discord.com/developers and adds
the redirect URI above.

## Phase 3: domain + HTTPS
* The owner creates a DNS **A record** `play.novexa-jo.com -> VPS IP`, and opens **80/443** (Windows Firewall +
  provider panel).
* Install **Caddy** for Windows, run it as a service, and use this Caddyfile:
  ```
  play.novexa-jo.com {
      @portal path /login* /auth/* /motd.txt
      reverse_proxy @portal 127.0.0.1:5080
      reverse_proxy 127.0.0.1:9001
  }
  ```
* Re-run `3-Install-GameServer.ps1 -PublicHost play.novexa-jo.com`. This sets `ws_address` to
  `wss://play.novexa-jo.com/ws` and rebinds the server to localhost. Then delete the firewall rule
  `NOVEXA GameServer TEST 9001`.
* The Mac launcher always connects to `play.novexa-jo.com`:443 over HTTPS (no UI choice). The engine
  reads this from `NGMP_SERVER_HOST/PORT/SSL` (engine patch `engine/patches/0001-...`).

## Known follow-ups
* Server log shows "potentially spoofed HWID" for macOS clients. This is non-blocking; investigate before a public launch.
* Back up MariaDB daily (`mariadb-dump generalsonline`) to a folder outside the VPS.

## Publishing a launcher release on the website
Releases are built on the Mac (`scripts/make-dmg.sh`) and attached to a GitHub release on the public repository
`OmaryaToo/novexa-generals-mac-source` as `NOVEXA-Generals-Mac-<ver>.dmg` with a `.sha256` file.
On the VPS (elevated PowerShell, repo up to date with `git pull`):
```powershell
cd <repo>\server\deploy\windows
.\6-Publish-Download.ps1 -Version 0.1.0 -Notes "First public release"
```
It downloads the DMG into `C:\NovexaGenerals\Downloads`, verifies the SHA-256 and writes `latest.json`. The
`/download` page then shows the version, size and date, and enables the button (served by the portal at `/downloads/<file>`).
