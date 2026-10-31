using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Web.Script.Serialization;

// C# adapter from the Astra widget. Only reads account limits; no model calls.
internal static class AstraLimitsBridge
{
    static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = 1048576 };
    static string FindCodex()
    {
        string root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "OpenAI", "Codex", "bin");
        if (Directory.Exists(root)) {
            string found = Directory.EnumerateFiles(root, "codex.exe", SearchOption.AllDirectories).OrderByDescending(File.GetLastWriteTimeUtc).FirstOrDefault();
            if (found != null) return found;
        }
        foreach (string directory in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(';')) {
            try { string p = Path.Combine(directory.Trim('"'), "codex.exe"); if (File.Exists(p)) return p; } catch (ArgumentException) { }
        }
        throw new FileNotFoundException();
    }
    static object Reply(Process process, int id, DateTime deadline)
    {
        while (DateTime.UtcNow < deadline) {
            var line = process.StandardOutput.ReadLineAsync();
            int timeout = Math.Max(1, (int)(deadline - DateTime.UtcNow).TotalMilliseconds);
            if (!line.Wait(timeout)) throw new TimeoutException();
            if (line.Result == null) throw new EndOfStreamException();
            if (line.Result.Length > 1048576) throw new InvalidDataException();
            Dictionary<string, object> message;
            try { message = Json.DeserializeObject(line.Result) as Dictionary<string, object>; } catch (ArgumentException) { continue; }
            if (message == null || !message.ContainsKey("id") || !Object.Equals(message["id"], id)) continue;
            if (message.ContainsKey("error")) throw new InvalidOperationException();
            object result; if (!message.TryGetValue("result", out result)) throw new InvalidDataException();
            return result;
        }
        throw new TimeoutException();
    }
    static object Fetch()
    {
        var start = new ProcessStartInfo(FindCodex(), "app-server --listen stdio://") {
            UseShellExecute = false, CreateNoWindow = true,
            RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8, StandardErrorEncoding = Encoding.UTF8
        };
        using (var process = Process.Start(start)) {
            process.ErrorDataReceived += delegate { }; process.BeginErrorReadLine();
            try {
                DateTime deadline = DateTime.UtcNow.AddSeconds(20);
                process.StandardInput.WriteLine("{\"id\":1,\"method\":\"initialize\",\"params\":{\"clientInfo\":{\"name\":\"astra_limits_pc_control\",\"title\":\"Astra Limits\",\"version\":\"1.0.0\"}}}");
                process.StandardInput.Flush(); Reply(process, 1, deadline);
                process.StandardInput.WriteLine("{\"method\":\"initialized\",\"params\":{}}");
                process.StandardInput.WriteLine("{\"id\":2,\"method\":\"account/rateLimits/read\"}");
                process.StandardInput.Flush(); return Reply(process, 2, deadline);
            } finally {
                try { process.StandardInput.Close(); if (!process.WaitForExit(1000)) { process.Kill(); process.WaitForExit(1000); } } catch (InvalidOperationException) { }
            }
        }
    }
    static int Main()
    {
        Console.OutputEncoding = new UTF8Encoding(false);
        try { Console.WriteLine(Json.Serialize(new { id = 2, result = Fetch() })); return 0; }
        catch { Console.WriteLine("{\"id\":2,\"error\":true}"); return 1; }
    }
}
