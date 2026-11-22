// NOVEXA login portal: browser login for the game client via Discord OAuth.
// Flow: game opens /login/?gamecode=CODE -> Discord -> /auth/discord/callback -> find/create user
// -> POST LoginCode to the game server (X-Api-Key) -> the game's CheckLogin poll completes.
// Configured only through environment variables (see README.md). Listens on 127.0.0.1:5080.

using System.Collections.Concurrent;
using System.Net;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using MySqlConnector;

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.UseUrls(Env("PORTAL_LISTEN_URL", "http://127.0.0.1:5080"));
builder.Services.AddHttpClient();
var app = builder.Build();

var cfg = new PortalConfig(
	ClientId: Env("DISCORD_CLIENT_ID"),
	ClientSecret: Env("DISCORD_CLIENT_SECRET"),
	WebserverKey: Env("WEBSERVER_KEY"),
	PublicUrl: Env("PORTAL_PUBLIC_URL", "https://play.novexa-jo.com").TrimEnd('/'),
	GameServerUrl: Env("GAMESERVER_URL", "http://127.0.0.1:9001").TrimEnd('/'),
	Db: new MySqlConnectionStringBuilder
	{
		Server = Env("DB_HOST", "127.0.0.1"),
		Port = uint.Parse(Env("DB_PORT", "3307")),
		Database = Env("DB_NAME", "generalsonline"),
		UserID = Env("DB_USER", "genonline"),
		Password = Env("DB_PASSWORD"),
	}.ConnectionString,
	MotdFile: Env("MOTD_FILE", Path.Combine(AppContext.BaseDirectory, "motd.txt")));

string redirectUri = cfg.PublicUrl + "/auth/discord/callback";
var pending = new ConcurrentDictionary<string, (string Code, DateTime Expires)>();
var gameCodeRx = new Regex("^[A-Za-z0-9]{16,64}$");

// Matches both /login and /login/ (ASP.NET routing ignores the trailing slash).
app.MapGet("/login",(string? gamecode) =>
{
	if (gamecode is null || !gameCodeRx.IsMatch(gamecode))
		return Page("Invalid login link", "Start the login again from inside the game.", false, 400);
	if (string.IsNullOrEmpty(cfg.ClientId) || string.IsNullOrEmpty(cfg.ClientSecret))
		return Page("Login unavailable", "Discord login is not configured on this server yet.", false, 503);

	foreach (var kv in pending) if (kv.Value.Expires < DateTime.UtcNow) pending.TryRemove(kv.Key, out _);
	string state = Convert.ToHexString(RandomNumberGenerator.GetBytes(24));
	pending[state] = (gamecode, DateTime.UtcNow.AddMinutes(10));

	string url = "https://discord.com/oauth2/authorize?response_type=code&scope=identify&prompt=none"
		+ "&client_id=" + Uri.EscapeDataString(cfg.ClientId)
		+ "&redirect_uri=" + Uri.EscapeDataString(redirectUri)
		+ "&state=" + state;
	return Results.Redirect(url);
});

app.MapGet("/auth/discord/callback", async (string? code, string? state, string? error, IHttpClientFactory http, ILogger<Program> log) =>
{
	if (state is null || !pending.TryRemove(state, out var p) || p.Expires < DateTime.UtcNow)
		return Page("Login expired", "This login link has expired. Start the login again from inside the game.", false, 400);

	if (error is not null || code is null)
	{
		await ReportLogin(http, p.Code, -1, false, log);
		return Page("Login cancelled", "You cancelled the Discord login. You can return to the game.", false, 200);
	}

	try
	{
		var client = http.CreateClient();
		var tokenResp = await client.PostAsync("https://discord.com/api/v10/oauth2/token", new FormUrlEncodedContent(new Dictionary<string, string>
		{
			["grant_type"] = "authorization_code",
			["code"] = code,
			["redirect_uri"] = redirectUri,
			["client_id"] = cfg.ClientId,
			["client_secret"] = cfg.ClientSecret,
		}));
		if (!tokenResp.IsSuccessStatusCode) throw new Exception($"token exchange {(int)tokenResp.StatusCode}");
		using var tokenJson = JsonDocument.Parse(await tokenResp.Content.ReadAsStringAsync());
		string accessToken = tokenJson.RootElement.GetProperty("access_token").GetString()!;

		var meReq = new HttpRequestMessage(HttpMethod.Get, "https://discord.com/api/v10/users/@me");
		meReq.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
		var meResp = await client.SendAsync(meReq);
		if (!meResp.IsSuccessStatusCode) throw new Exception($"users/@me {(int)meResp.StatusCode}");
		using var me = JsonDocument.Parse(await meResp.Content.ReadAsStringAsync());
		long discordId = long.Parse(me.RootElement.GetProperty("id").GetString()!);
		string username = me.RootElement.GetProperty("username").GetString() ?? "player";
		string? globalName = me.RootElement.TryGetProperty("global_name", out var g) && g.ValueKind == JsonValueKind.String ? g.GetString() : null;

		var (userId, banned, displayName) = await FindOrCreateUser(discordId, username, globalName);
		if (banned)
		{
			await ReportLogin(http, p.Code, userId, false, log);
			return Page("Account banned", "This account is banned from NOVEXA Generals Online.", false, 403);
		}

		if (!await ReportLogin(http, p.Code, userId, true, log))
			return Page("Login expired", "The game stopped waiting for this login. Start the login again from inside the game.", false, 410);

		log.LogInformation("Login OK: user {UserId} ({Name}) discord {DiscordId}", userId, displayName, discordId);
		return Page($"Welcome, {displayName}", "You are logged in. Return to the game. You can close this tab.", true, 200);
	}
	catch (Exception ex)
	{
		log.LogError(ex, "Discord login failed");
		await ReportLogin(http, p.Code, -1, false, log);
		return Page("Login failed", "Something went wrong during login. Please try again from inside the game.", false, 502);
	}
});

app.MapGet("/motd.txt", () =>
	Results.Text(File.Exists(cfg.MotdFile) ? File.ReadAllText(cfg.MotdFile) : "Welcome to NOVEXA Generals Online!", "text/plain; charset=utf-8"));

app.MapGet("/healthz", () => Results.Text("ok"));

// ---- public website (wwwroot) + read-only stats API ----

string downloadsDir = Env("DOWNLOADS_DIR", @"C:\NovexaGenerals\Downloads");
string[] pages = ["download", "dashboard"];
app.Use(async (ctx, next) =>
{
	// clean URLs: /download -> /download.html
	string p = ctx.Request.Path.Value?.Trim('/') ?? "";
	if (pages.Contains(p)) ctx.Request.Path = "/" + p + ".html";
	await next();
});
app.UseDefaultFiles();
app.UseStaticFiles(new StaticFileOptions
{
	OnPrepareResponse = c => c.Context.Response.Headers.CacheControl = "no-cache",
});

var statsCache = new ConcurrentDictionary<string, (DateTime At, object Value)>();
async Task<object> Cached(string key, TimeSpan ttl, Func<Task<object>> make)
{
	if (statsCache.TryGetValue(key, out var e) && DateTime.UtcNow - e.At < ttl) return e.Value;
	var v = await make();
	statsCache[key] = (DateTime.UtcNow, v);
	return v;
}

app.MapGet("/api/stats", async (IHttpClientFactory http) => Results.Json(await Cached("stats", TimeSpan.FromSeconds(15), async () =>
{
	int players = 0, lobbies = 0; bool online = false;
	try
	{
		using var live = JsonDocument.Parse(await http.CreateClient().GetStringAsync(cfg.GameServerUrl + "/env/live/contract/1/Monitoring/BasicStats"));
		players = live.RootElement.GetProperty("players").GetInt32();
		lobbies = live.RootElement.GetProperty("lobbies").GetInt32();
		online = true;
	}
	catch { /* server down -> online=false */ }

	await using var db = new MySqlConnection(cfg.Db);
	await db.OpenAsync();
	return new
	{
		online, players_online = players, lobbies,
		registered = await Scalar(db, "SELECT COUNT(*) FROM users WHERE banned=0"),
		matches_total = await Scalar(db, "SELECT COUNT(*) FROM match_history WHERE finished=1"),
		matches_today = await Scalar(db, "SELECT COUNT(*) FROM match_history WHERE finished=1 AND started >= CURDATE()"),
		new_players_week = await Scalar(db, "SELECT COUNT(*) FROM users WHERE banned=0 AND created_at >= NOW() - INTERVAL 7 DAY"),
	};
})));

app.MapGet("/api/leaderboard", async () => Results.Json(await Cached("lb", TimeSpan.FromSeconds(60), async () =>
{
	await using var db = new MySqlConnection(cfg.Db);
	await db.OpenAsync();
	await using var c = new MySqlCommand(@"SELECT u.user_id, u.displayname, u.elo_rating, u.elo_num_matches, u.last_match_at,
		COALESCE(SUM(l.wins),0), COALESCE(SUM(l.losses),0)
		FROM users u LEFT JOIN leaderboard_yearly l ON l.user_id=u.user_id
		WHERE u.banned=0 AND u.displayname IS NOT NULL
		GROUP BY u.user_id ORDER BY u.elo_num_matches > 0 DESC, u.elo_rating DESC, u.lastlogin DESC LIMIT 50", db);
	var rows = new List<object>();
	await using var r = await c.ExecuteReaderAsync();
	while (await r.ReadAsync())
		rows.Add(new
		{
			id = r.GetInt64(0), name = r.GetString(1), elo = r.GetInt32(2), rated_matches = r.GetInt32(3),
			last_match = r.IsDBNull(4) ? null : (DateTime?)r.GetDateTime(4), wins = r.GetInt64(5), losses = r.GetInt64(6),
		});
	return rows;
})));

app.MapGet("/api/matches/recent", async () => Results.Json(await Cached("recent", TimeSpan.FromSeconds(30), async () =>
{
	await using var db = new MySqlConnection(cfg.Db);
	await db.OpenAsync();
	await using var c = new MySqlCommand(@"SELECT match_id, map_name, match_roster_type, started, time_finished,
		(member_slot_0 IS NOT NULL)+(member_slot_1 IS NOT NULL)+(member_slot_2 IS NOT NULL)+(member_slot_3 IS NOT NULL)
		+(member_slot_4 IS NOT NULL)+(member_slot_5 IS NOT NULL)
		FROM match_history WHERE finished=1 ORDER BY match_id DESC LIMIT 15", db);
	var rows = new List<object>();
	await using var r = await c.ExecuteReaderAsync();
	while (await r.ReadAsync())
	{
		string map = r.GetString(1);
		rows.Add(new
		{
			id = r.GetInt64(0), map = Path.GetFileNameWithoutExtension(map.Replace('\\', '/')), roster = r.GetString(2),
			started = r.GetDateTime(3), minutes = Math.Max(0, (int)(r.GetDateTime(4) - r.GetDateTime(3)).TotalMinutes), players = r.GetInt32(5),
		});
	}
	return rows;
})));

app.MapGet("/api/download", () =>
{
	// C:\NovexaGenerals\Downloads\latest.json: {"version":"1.0.0","file":"NOVEXA-Generals-Mac-1.0.0.dmg","notes":"..."}
	string manifest = Path.Combine(downloadsDir, "latest.json");
	if (!File.Exists(manifest)) return Results.Json(new { available = false });
	using var j = JsonDocument.Parse(File.ReadAllText(manifest));
	string file = Path.GetFileName(j.RootElement.GetProperty("file").GetString() ?? "");
	var fi = new FileInfo(Path.Combine(downloadsDir, file));
	if (!fi.Exists) return Results.Json(new { available = false });
	return Results.Json(new
	{
		available = true,
		version = j.RootElement.TryGetProperty("version", out var v) ? v.GetString() : "",
		notes = j.RootElement.TryGetProperty("notes", out var n) ? n.GetString() : "",
		file, size = fi.Length, updated = fi.LastWriteTimeUtc, url = "/downloads/" + Uri.EscapeDataString(file),
	});
});

app.MapGet("/downloads/{file}", (string file) =>
{
	var fi = new FileInfo(Path.Combine(downloadsDir, Path.GetFileName(file)));
	if (!fi.Exists || fi.Name.Equals("latest.json", StringComparison.OrdinalIgnoreCase)) return Results.NotFound();
	return Results.File(fi.FullName, "application/octet-stream", fi.Name, enableRangeProcessing: true);
});

app.Run();

static async Task<long> Scalar(MySqlConnection db, string sql)
{
	await using var c = new MySqlCommand(sql, db);
	return Convert.ToInt64(await c.ExecuteScalarAsync());
}

// ---- helpers ----

async Task<(long Id, bool Banned, string DisplayName)> FindOrCreateUser(long discordId, string username, string? globalName)
{
	await using var db = new MySqlConnection(cfg.Db);
	await db.OpenAsync();

	await using (var find = new MySqlCommand("SELECT user_id, banned, COALESCE(displayname,'') FROM users WHERE discord_id=@d LIMIT 1", db))
	{
		find.Parameters.AddWithValue("@d", discordId);
		await using var r = await find.ExecuteReaderAsync();
		if (await r.ReadAsync())
		{
			long id = r.GetInt64(0); bool banned = r.GetInt32(1) != 0; string name = r.GetString(2);
			await r.CloseAsync();
			await using var upd = new MySqlCommand("UPDATE users SET discord_username=@u, lastlogin=NOW() WHERE user_id=@id", db);
			upd.Parameters.AddWithValue("@u", Trunc(username, 32)); upd.Parameters.AddWithValue("@id", id);
			await upd.ExecuteNonQueryAsync();
			return (id, banned, name);
		}
	}

	string baseName = SanitizeName(globalName) is { Length: >= 3 } gn ? gn : SanitizeName(username);
	if (baseName.Length < 3) baseName = "Player";
	string display = baseName;
	for (int i = 0; await NameTaken(db, display); i++)
	{
		string suffix = i < 50 ? RandomNumberGenerator.GetInt32(10, 9999).ToString() : Convert.ToHexString(RandomNumberGenerator.GetBytes(3));
		display = Trunc(baseName, 16 - suffix.Length) + suffix;
	}

	await using var ins = new MySqlCommand(
		"INSERT INTO users (account_type, discord_id, discord_username, displayname) VALUES (1, @d, @u, @n)", db);
	ins.Parameters.AddWithValue("@d", discordId);
	ins.Parameters.AddWithValue("@u", Trunc(username, 32));
	ins.Parameters.AddWithValue("@n", display);
	await ins.ExecuteNonQueryAsync();
	return (ins.LastInsertedId, false, display);
}

static async Task<bool> NameTaken(MySqlConnection db, string name)
{
	await using var c = new MySqlCommand("SELECT 1 FROM users WHERE LOWER(displayname)=LOWER(@n) LIMIT 1", db);
	c.Parameters.AddWithValue("@n", name);
	return await c.ExecuteScalarAsync() is not null;
}

static string SanitizeName(string? s) => Trunc(Regex.Replace(s ?? "", "[^A-Za-z0-9_-]", ""), 16);
static string Trunc(string s, int n) => s.Length <= n ? s : s[..n];

async Task<bool> ReportLogin(IHttpClientFactory http, string gameCode, long userId, bool success, ILogger log)
{
	try
	{
		var req = new HttpRequestMessage(HttpMethod.Post, cfg.GameServerUrl + "/env/live/contract/1/LoginCode")
		{
			Content = new StringContent(JsonSerializer.Serialize(new { env = "live", code = gameCode, user_id = userId, success }), Encoding.UTF8, "application/json"),
		};
		req.Headers.Add("X-Api-Key", cfg.WebserverKey);
		var resp = await http.CreateClient().SendAsync(req);
		if (!resp.IsSuccessStatusCode) log.LogWarning("LoginCode returned {Status}", (int)resp.StatusCode);
		return resp.IsSuccessStatusCode;
	}
	catch (Exception ex)
	{
		log.LogError(ex, "LoginCode call failed");
		return false;
	}
}

static IResult Page(string title, string message, bool ok, int status)
{
	string t = WebUtility.HtmlEncode(title), m = WebUtility.HtmlEncode(message);
	string icon = ok ? "&#10003;" : "!";
	string html = $$"""
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{{t}} &middot; NOVEXA Generals Online</title>
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Alexandria:wght@300;700&family=Instrument+Sans:wght@400;500&family=IBM+Plex+Mono:wght@500&display=swap" rel="stylesheet">
<style>
*{box-sizing:border-box;margin:0}
body{min-height:100vh;display:grid;place-items:center;background:#F3F4F6;color:#0F1115;font-family:'Instrument Sans',system-ui,sans-serif;padding:24px}
.card{max-width:460px;width:100%;padding:40px 36px;border-radius:22px;background:#fff;border:1px solid #DADDE2}
.logo{font:700 19px/1 Alexandria,sans-serif;letter-spacing:-.02em;display:inline-flex;align-items:center;gap:10px;color:#0F1115;text-decoration:none}
.logo i{width:20px;height:20px;border-radius:6px;background:#0F1115;position:relative}
.logo i::after{content:"";position:absolute;inset:5px;border-radius:2px;background:#2433FF}
.eyebrow{display:block;margin-top:28px;font:500 12px 'IBM Plex Mono',monospace;letter-spacing:.12em;text-transform:uppercase;color:{{(ok ? "#127A4A" : "#9AA0AA")}}}
h1{font:300 32px/1.2 Alexandria,sans-serif;margin:12px 0}
p{color:#5A606B;line-height:1.7}
a.btn{display:inline-flex;margin-top:28px;min-height:44px;align-items:center;padding:0 20px;border-radius:999px;background:#0F1115;color:#fff;text-decoration:none;font-size:14px}
a.btn:hover{background:#2433FF}
</style></head>
<body><main class="card"><a class="logo" href="/"><i></i>novexa</a><span class="eyebrow">{{(ok ? "Signed in" : "Generals Online")}}</span><h1>{{t}}</h1><p>{{m}}</p><a class="btn" href="/dashboard">Player board</a></main></body></html>
""";
	return Results.Content(html, "text/html; charset=utf-8", Encoding.UTF8, status);
}

static string Env(string name, string fallback = "") => Environment.GetEnvironmentVariable(name) is { Length: > 0 } v ? v : fallback;

record PortalConfig(string ClientId, string ClientSecret, string WebserverKey, string PublicUrl, string GameServerUrl, string Db, string MotdFile);
