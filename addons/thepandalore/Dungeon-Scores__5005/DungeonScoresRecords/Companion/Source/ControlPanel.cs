using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

internal static partial class Program
{
    private static readonly SemaphoreSlim ControlAction = new(1, 1);
    private static int controlSyncInProgress;

    private static async Task<int> OpenControlPanelAsync(string[] args)
    {
        var config = await LoadConfigurationAsync(args);
        ValidateConfig(config);
        await InstallRuntimeAsync(config);
        if (!IsInstalledRuntimeProcess())
        {
            Console.Error.WriteLine("Open the companion controls with the Open-Controls launcher for your operating system.");
            return 2;
        }
        if (HasStartupRegistration())
        {
            // Adopt an older registered watcher while preserving the user's
            // existing login preference.
            SetStartupRegistration(true);
            StartWatcher(InstalledWatcherLaunchSpec());
        }

        using var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start(8);
        var port = ((IPEndPoint)listener.LocalEndpoint).Port;
        var token = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32))
            .TrimEnd('=').Replace('+', '-').Replace('/', '_');
        var url = $"http://127.0.0.1:{port}/{token}/";
        var closed = 0;
        long lastRequestTicks = DateTime.UtcNow.Ticks;
        try
        {
            Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine("Could not open your browser: " + exception.Message);
        }
        Console.WriteLine("Dungeon Scores Companion controls: " + url);
        Console.WriteLine("Keep this window open while using the controls. The watcher runs separately.");

        _ = Task.Run(async () =>
        {
            while (Volatile.Read(ref closed) == 0)
            {
                await Task.Delay(TimeSpan.FromSeconds(15));
                if (DateTime.UtcNow.Ticks - Interlocked.Read(ref lastRequestTicks)
                    > TimeSpan.FromMinutes(2).Ticks)
                {
                    Interlocked.Exchange(ref closed, 1);
                    listener.Stop();
                }
            }
        });

        while (Volatile.Read(ref closed) == 0)
        {
            try
            {
                var client = await listener.AcceptTcpClientAsync();
                _ = Task.Run(() => HandleControlClientAsync(client, token, port, config,
                    () => Interlocked.Exchange(ref lastRequestTicks, DateTime.UtcNow.Ticks),
                    () => { Interlocked.Exchange(ref closed, 1); listener.Stop(); }));
            }
            catch (SocketException) when (Volatile.Read(ref closed) != 0) { break; }
            catch (ObjectDisposedException) when (Volatile.Read(ref closed) != 0) { break; }
        }
        return 0;
    }

    private static async Task HandleControlClientAsync(TcpClient client, string token, int port,
        UploaderConfig config, Action touchPanel, Action closePanel)
    {
        using (client)
        {
            client.ReceiveTimeout = 3000;
            client.SendTimeout = 3000;
            var stream = client.GetStream();
            try
            {
                var header = await ReadControlHeadersAsync(stream);
                if (header is null) return;
                var lines = header.Split("\r\n", StringSplitOptions.None);
                var first = lines[0].Split(' ', StringSplitOptions.RemoveEmptyEntries);
                if (first.Length != 3 || first[2] != "HTTP/1.1")
                {
                    await WriteControlResponseAsync(stream, 400, "text/plain", "Bad request");
                    return;
                }
                var headers = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                foreach (var line in lines.Skip(1))
                {
                    var separator = line.IndexOf(':');
                    if (separator > 0) headers[line[..separator].Trim()] = line[(separator + 1)..].Trim();
                }
                var origin = $"http://127.0.0.1:{port}";
                if (!headers.TryGetValue("Host", out var host)
                    || host != $"127.0.0.1:{port}"
                    || headers.ContainsKey("Transfer-Encoding")
                    || (headers.TryGetValue("Content-Length", out var length) && length != "0"))
                {
                    await WriteControlResponseAsync(stream, 403, "text/plain", "Forbidden");
                    return;
                }
                var path = first[1];
                var prefix = $"/{token}/";
                if (!path.StartsWith(prefix, StringComparison.Ordinal))
                {
                    await WriteControlResponseAsync(stream, 404, "text/plain", "Not found");
                    return;
                }
                touchPanel();
                var route = path[prefix.Length..];
                if (first[0] == "GET" && route == "")
                {
                    await WriteControlResponseAsync(stream, 200, "text/html; charset=utf-8",
                        ControlHtml.Replace("__TOKEN__", token, StringComparison.Ordinal));
                    return;
                }
                if (first[0] == "GET" && route == "status")
                {
                    var lastSync = File.Exists(LastSyncStatusPath())
                        ? File.ReadAllText(LastSyncStatusPath()) : "No sync has run yet.";
                    var savedAt = File.Exists(config.SavedVariablesPath)
                        ? File.GetLastWriteTime(config.SavedVariablesPath).ToString("g")
                        : "No ESO save found";
                    await WriteControlResponseAsync(stream, 200, "application/json; charset=utf-8",
                        JsonSerializer.Serialize(new {
                            version = CompanionVersion,
                            monitoring = IsWatcherRunning(),
                            startAtLogin = IsStartupEnabled(),
                            syncInProgress = Volatile.Read(ref controlSyncInProgress) != 0,
                            savedAt,
                            lastSync = lastSync[..Math.Min(lastSync.Length, 2000)],
                        }));
                    return;
                }
                if (first[0] != "POST" || !headers.TryGetValue("Origin", out var suppliedOrigin)
                    || suppliedOrigin != origin)
                {
                    await WriteControlResponseAsync(stream, 403, "text/plain", "Forbidden");
                    return;
                }
                var result = await RunControlActionAsync(route, config);
                await WriteControlResponseAsync(stream, result.ok ? 200 : 409,
                    "application/json; charset=utf-8",
                    JsonSerializer.Serialize(new { ok = result.ok, message = result.message }));
                if (route == "close" && result.ok) closePanel();
            }
            catch (Exception exception)
            {
                try
                {
                    await WriteControlResponseAsync(stream, 500, "application/json; charset=utf-8",
                        JsonSerializer.Serialize(new { ok = false, message = exception.Message }));
                }
                catch { /* The browser may have closed before the response. */ }
            }
        }
    }

    private static async Task<string?> ReadControlHeadersAsync(NetworkStream stream)
    {
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(3));
        using var buffer = new MemoryStream();
        var next = new byte[1];
        while (buffer.Length < 8192)
        {
            if (await stream.ReadAsync(next, timeout.Token) == 0) return null;
            buffer.WriteByte(next[0]);
            var bytes = buffer.GetBuffer();
            var length = (int)buffer.Length;
            if (length >= 4 && bytes[length - 4] == '\r' && bytes[length - 3] == '\n'
                && bytes[length - 2] == '\r' && bytes[length - 1] == '\n')
                return Encoding.ASCII.GetString(bytes, 0, length - 4);
        }
        throw new InvalidDataException("Request headers are too large");
    }

    private static async Task WriteControlResponseAsync(NetworkStream stream, int status,
        string contentType, string content)
    {
        var body = Encoding.UTF8.GetBytes(content);
        var phrase = status switch { 200 => "OK", 400 => "Bad Request", 403 => "Forbidden",
            404 => "Not Found", 409 => "Conflict", _ => "Internal Server Error" };
        var header = $"HTTP/1.1 {status} {phrase}\r\nContent-Type: {contentType}\r\n"
            + $"Content-Length: {body.Length}\r\nConnection: close\r\nCache-Control: no-store\r\n"
            + "Referrer-Policy: no-referrer\r\nX-Content-Type-Options: nosniff\r\n"
            + "Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; "
            + "script-src 'unsafe-inline'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'\r\n\r\n";
        await stream.WriteAsync(Encoding.ASCII.GetBytes(header));
        await stream.WriteAsync(body);
    }

    private static async Task<(bool ok, string message)> RunControlActionAsync(string route,
        UploaderConfig config)
    {
        if (route == "close") return (true, "Control window closed. Monitoring continues.");
        if (route == "sync")
        {
            if (Interlocked.Exchange(ref controlSyncInProgress, 1) != 0)
                return (false, "A sync is already running.");
            try
            {
                return await Task.Run(() =>
                {
                    var output = new StringWriter();
                    var errors = new StringWriter();
                    var result = RunOnceSerialized(["--sync", "--config", InstalledConfigPath()],
                        output, errors);
                    var summary = (output.ToString() + errors.ToString()).Trim();
                    WriteLastSyncStatus(result, summary);
                    summary = summary[..Math.Min(summary.Length, 2000)];
                    return (result == 0, result == 0 ? "Sync complete. " + summary : summary);
                });
            }
            finally { Interlocked.Exchange(ref controlSyncInProgress, 0); }
        }
        await ControlAction.WaitAsync();
        try
        {
            switch (route)
            {
                case "start":
                    await InstallRuntimeAsync(config);
                    StartWatcher(InstalledWatcherLaunchSpec());
                    return (true, "Monitoring started.");
                case "stop":
                    return StopWatcher()
                        ? (true, "Monitoring stopped for this session.")
                        : (true, "Stop requested. The current sync will finish first.");
                case "autostart-on":
                    SetStartupRegistration(true);
                    return (true, "Start at login is on.");
                case "autostart-off":
                    SetStartupRegistration(false);
                    return (true, "Start at login is off. Current monitoring continues.");
                default:
                    return (false, "Unknown control.");
            }
        }
        catch (Exception exception) { return (false, exception.Message); }
        finally { ControlAction.Release(); }
    }

    private const string ControlHtml = """
        <!doctype html><html lang="en"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <title>Dungeon Scores Companion</title>
        <style>
          :root{font:16px system-ui,sans-serif;color:#ecf1fa;background:#101722}
          *{box-sizing:border-box}body{margin:0;padding:24px;max-width:800px}
          header{display:flex;align-items:center;justify-content:space-between;gap:12px}
          h1{font-size:1.6rem;margin:0}h2{font-size:1rem;margin:0 0 12px;color:#b9c9df}
          .card{background:#1a2535;border:1px solid #34465e;border-radius:12px;padding:20px;margin-top:18px}
          .row{display:flex;flex-wrap:wrap;align-items:center;gap:12px;margin-top:14px}
          .pill{border-radius:20px;padding:6px 12px;background:#3d4753;font-weight:700}
          .running{background:#145b43;color:#d9ffed}.stopped{background:#643d3d;color:#ffe5e5}
          button{border:1px solid #6b8db2;border-radius:8px;background:#294869;color:white;padding:11px 16px;font:inherit;cursor:pointer}
          button:hover{background:#356084}button:disabled{opacity:.45;cursor:default}
          .primary{background:#286151;border-color:#55aa8e}.muted{background:transparent}
          .meta{color:#b9c9df;font-size:.92rem}.notice{color:#d1dceb;line-height:1.45}
          pre{white-space:pre-wrap;overflow-wrap:anywhere;margin:0;font:13px ui-monospace,monospace;line-height:1.5}
          label{display:flex;align-items:center;gap:10px;cursor:pointer}input{width:19px;height:19px}
          #message{min-height:24px;color:#c8e7ff}
        </style></head><body>
        <header><div><h1>Dungeon Scores Companion</h1><div class="meta">Local controls · <span id="version">Loading…</span></div></div><span id="state" class="pill">Checking…</span></header>
        <section class="card"><h2>Monitoring</h2><div class="notice">Watches ESO saves and refreshes public records while ESO is running.</div>
          <div class="row"><button id="start" class="primary">Start monitoring</button><button id="stop">Stop monitoring</button></div>
          <div class="row"><label><input type="checkbox" id="login"> Start at login</label></div>
          <div class="meta">Stopping now leaves the login preference unchanged.</div>
        </section>
        <section class="card"><h2>Sync</h2><div class="notice">Processes only scores you queued in ESO and refreshes public records. ESO must save first; use /reloadui if you want to sync a run immediately.</div>
          <div class="row"><button id="sync" class="primary">Sync saved data now</button><span class="meta">Last ESO save: <span id="saved">—</span></span></div>
        </section>
        <section class="card"><h2>Latest sync</h2><pre id="last">Checking…</pre></section>
        <div class="row"><button id="close" class="muted">Close controls</button><span id="message"></span></div>
        <script>
          const root='/__TOKEN__/';
          const byId=id=>document.getElementById(id);
          let busy=false;
          async function refresh(){
            try{
              const s=await(await fetch(root+'status',{cache:'no-store'})).json();
              byId('version').textContent='Version '+s.version;
              byId('state').textContent=s.monitoring?'Running':'Stopped';
              byId('state').className='pill '+(s.monitoring?'running':'stopped');
              byId('start').disabled=busy||s.monitoring;
              byId('stop').disabled=busy||!s.monitoring;
              byId('sync').disabled=busy||s.syncInProgress;
              byId('login').checked=s.startAtLogin;
              byId('login').disabled=busy;
              byId('saved').textContent=s.savedAt;
              byId('last').textContent=s.lastSync;
            }catch(e){byId('message').textContent='Control connection lost.';}
          }
          async function act(name){
            busy=true;await refresh();byId('message').textContent='Working…';
            let closing=false;
            try{
              const response=await fetch(root+name,{method:'POST',body:''});
              const result=await response.json();
              byId('message').textContent=result.message;
              if(name==='close'&&result.ok){closing=true;document.body.innerHTML='<p>Control window closed. Monitoring continues if it was running.</p>';return;}
            }catch(e){byId('message').textContent='Action failed: '+e.message;}
            finally{busy=false;if(!closing)await refresh();}
          }
          for(const name of ['start','stop','sync','close'])byId(name).onclick=()=>act(name);
          byId('login').onchange=e=>act(e.target.checked?'autostart-on':'autostart-off');
          refresh();setInterval(refresh,3000);
        </script></body></html>
        """;
}
