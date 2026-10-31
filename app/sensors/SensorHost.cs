using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.Principal;
using System.Threading;
using System.Web.Script.Serialization;
using LibreHardwareMonitor.Hardware;
using Microsoft.Win32;

// CPU-only, read-only helper. This executable never installs a driver, creates
// a service, changes fan controls, schedules a shutdown, or opens a network port.
internal static class SensorHost
{
    private static readonly JavaScriptSerializer Json = new JavaScriptSerializer();
    private static string OutputPath;
    private static long OwnerPid;

    [STAThread]
    private static int Main(string[] args)
    {
        if (args.Length != 2 || args[0] != "--owner" || !Int64.TryParse(args[1], out OwnerPid) || OwnerPid <= 0 || OwnerPid > Int32.MaxValue) return 2;
        OutputPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Rework", "ReworkPCControl", "Sensors", "cpu.json");
        Directory.CreateDirectory(Path.GetDirectoryName(OutputPath));
        bool own;
        using (var mutex = new Mutex(true, @"Local\ReworkPcCpuSensors-" + WindowsIdentity.GetCurrent().User.Value, out own))
        {
            if (!own) return 0;
            try
            {
                if (!new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator)) { Write(null, null, "admin_required", null); return 3; }
                using (var key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PawnIO"))
                {
                    if (key == null || String.IsNullOrEmpty(key.GetValue("DisplayVersion") as string)) { Write(null, null, "driver_missing", null); return 4; }
                }
                Computer computer = new Computer { IsCpuEnabled = true };
                try
                {
                    computer.Open();
                    while (OwnerIsRunning())
                    {
                        string name = null, source = null;
                        float? temperature = null;
                        int best = -1;
                        foreach (IHardware hardware in computer.Hardware)
                        {
                            if (hardware.HardwareType != HardwareType.Cpu) continue;
                            hardware.Update();
                            name = hardware.Name;
                            foreach (ISensor sensor in hardware.Sensors)
                            {
                                if (sensor.SensorType != SensorType.Temperature || !sensor.Value.HasValue) continue;
                                float value = sensor.Value.Value;
                                if (Single.IsNaN(value) || Single.IsInfinity(value) || value < 0 || value > 125) continue;
                                string label = sensor.Name ?? "";
                                // Prefer package temperature, then core maximum, then the
                                // hottest readable core. Never substitute motherboard/ACPI data.
                                int score = label.IndexOf("Package", StringComparison.OrdinalIgnoreCase) >= 0 ? 3 : label.IndexOf("Core Max", StringComparison.OrdinalIgnoreCase) >= 0 ? 2 : 1;
                                if (score > best || (score == best && (!temperature.HasValue || value > temperature.Value)))
                                { best = score; temperature = value; source = label; }
                            }
                        }
                        Write(name, temperature, temperature.HasValue ? "ready" : "sensor_unavailable", source);
                        Thread.Sleep(2000);
                    }
                }
                finally { computer.Close(); }
            }
            catch (Exception error) { try { Write(null, null, "error", null, error.GetType().Name + ": " + error.Message); } catch { } return 1; }
            finally { mutex.ReleaseMutex(); }
        }
        return 0;
    }
    private static bool OwnerIsRunning()
    {
        try
        {
            using (Process owner = Process.GetProcessById((int)OwnerPid))
                return !owner.HasExited && owner.ProcessName.Equals("ReworkPCControl", StringComparison.OrdinalIgnoreCase);
        }
        catch { return false; }
    }
    private static void Write(string name, float? temperature, string status, string source, string detail = null)
    {
        var snapshot = new { version = 1, timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(), cpuName = name, cpuTemperature = temperature, status = status, source = source, detail = detail };
        string temporary = OutputPath + ".tmp";
        File.WriteAllText(temporary, Json.Serialize(snapshot));
        if (File.Exists(OutputPath)) File.Replace(temporary, OutputPath, null);
        else File.Move(temporary, OutputPath);
    }
}
