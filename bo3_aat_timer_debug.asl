state("boiii", "BOIII Community v1.1.6")
{
    int levelTime : "blackops3.exe", 0xA5502C0;
    string13 currentMap : "blackops3.exe", 0x940C5E8;
    int HitmarkerAll : "blackops3.exe", 0xA08B690;

    // --- AAT Slot addresses per map group ---
    byte Slot_09D0 : "blackops3.exe", 0x19CB09D0;
    byte Slot_1530 : "blackops3.exe", 0x19CB1530;
    byte Slot_0B70 : "blackops3.exe", 0x19CB0B70;
    byte Slot_9250 : "blackops3.exe", 0x19CB9250;
    byte Slot_8890 : "blackops3.exe", 0x19CB8890;
    byte Slot_86F0 : "blackops3.exe", 0x19CB86F0;
    byte Slot_8D70 : "blackops3.exe", 0x19CB8D70;
    byte Slot_8BD0 : "blackops3.exe", 0x19CB8BD0;
    byte Slot_90B0 : "blackops3.exe", 0x19CB90B0;
    byte Slot_8F10 : "blackops3.exe", 0x19CB8F10;
    byte Slot_98D0 : "blackops3.exe", 0x19CB98D0;
    byte Slot_8550 : "blackops3.exe", 0x19CB8550;
    byte Slot_7B90 : "blackops3.exe", 0x19CB7B90;

    // --- AAT trigger addresses ---
    short DeadWireAddr3 : "blackops3.exe", 0x4D5C5C8;
    int DeadWireAddr1 : "blackops3.exe", 0xA5511CC;
    int DeadWireAddr2 : "blackops3.exe", 0xA5511C4;
    short BlastFurnaceAddr : "blackops3.exe", 0x4D5C590;
    int FireWorksAddr : "blackops3.exe", 0x51A44E0;
    int ThunderWallAddr : "blackops3.exe", 0x51B4F70;
    int TurnedAddr1 : "blackops3.exe", 0x49C5730;
    int TurnedAddr2 : "blackops3.exe", 0x49C5780;
}

startup
{
    settings.Add("AAT Timers", true, "AAT Cooldown Timers");
    settings.Add("AAT_DeadWire", true, "Dead Wire (5s)", "AAT Timers");
    settings.Add("AAT_BlastFurnace", true, "Blast Furnace (15s)", "AAT Timers");
    settings.Add("AAT_FireWorks", true, "Fire Works (20s)", "AAT Timers");
    settings.Add("AAT_ThunderWall", true, "Thunder Wall (10s)", "AAT Timers");
    settings.Add("AAT_Turned", true, "Turned (15s)", "AAT Timers");
    settings.Add("AAT_Debug", false, "Show Map & AAT Debug", "AAT Timers");

    vars.aatCooldowns = new Dictionary<string, int> {
        {"DeadWire", 100}, {"BlastFurnace", 300}, {"FireWorks", 400}, {"ThunderWall", 200}, {"Turned", 300}
    };

    vars.aatStarts = new Dictionary<string, int>();
    vars.aatActive = new Dictionary<string, bool>();
    string[] aats = new string[] { "DeadWire", "BlastFurnace", "FireWorks", "ThunderWall", "Turned" };
    foreach (string a in aats) { vars.aatStarts[a] = -99999; vars.aatActive[a] = false; }

    vars.activeSlot = 0;
    vars.dwDetectionCooldownUntil = 0;
    vars.bfDetectionCooldownUntil = 0;
    
    vars.lastHMTime = -999999;
    vars.lastDWTime = -999999;
    vars.lastBFTime = -999999;
    vars.lastFWTime = -999999;
    vars.lastTWTime = -999999;
    vars.biWindow = 150;

    // --- LOG ---
    vars.logPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "AAT_Debug_Log.txt");
    File.WriteAllText(vars.logPath, "=== AAT DEBUG LOG - " + DateTime.Now.ToString() + " ===\n\n");

    vars.Log = (Action<string>)((msg) => {
        try { File.AppendAllText(vars.logPath, msg + "\n"); } catch {}
    });

    vars.ByteToAAT = (Func<byte, string>)((val) => {
        if (val == 200) return "BlastFurnace";
        if (val == 208) return "DeadWire";
        if (val == 216) return "FireWorks";
        if (val == 224) return "ThunderWall";
        if (val == 232) return "Turned";
        return val == 16 ? "None" : "";
    });

    vars.SetText = (Action<string, object>)((text1, text2) => {
        string textValue = text2 != null ? text2.ToString() : "";

        var textSettings = timer.Layout.Components.Where(x => x.GetType().Name == "TextComponent")
            .Select(x => x.GetType().GetProperty("Settings").GetValue(x, null));
        var textSetting = textSettings.FirstOrDefault(x => (x.GetType().GetProperty("Text1").GetValue(x, null) as string) == text1);

        if (textSetting != null)
        {
            textSetting.GetType().GetProperty("Text2").SetValue(textSetting, textValue);
        }
        else if (!string.IsNullOrEmpty(textValue))
        {
            try
            {
                var textComponentAssembly = Assembly.LoadFrom("Components\\LiveSplit.Text.dll");
                var textComponent = Activator.CreateInstance(textComponentAssembly.GetType("LiveSplit.UI.Components.TextComponent"), timer);
                timer.Layout.LayoutComponents.Add(new LiveSplit.UI.Components.LayoutComponent("LiveSplit.Text.dll", textComponent as LiveSplit.UI.Components.IComponent));

                textSetting = textComponent.GetType().GetProperty("Settings", BindingFlags.Instance | BindingFlags.Public).GetValue(textComponent, null);
                textSetting.GetType().GetProperty("Text1").SetValue(textSetting, text1);
                textSetting.GetType().GetProperty("Text2").SetValue(textSetting, textValue);
            }
            catch (Exception ex)
            {
            }
        }
    });

    vars.RemoveText = (Action<string>)((text1) => {
        try
        {
            var textComponents = timer.Layout.Components.Where(x => x.GetType().Name == "TextComponent").ToList();
            var componentToRemove = textComponents.FirstOrDefault(x =>
            {
                var s = x.GetType().GetProperty("Settings").GetValue(x, null);
                return (s.GetType().GetProperty("Text1").GetValue(s, null) as string) == text1;
            });

            if (componentToRemove != null)
            {
                var layoutComponentsList = timer.Layout.LayoutComponents as System.Collections.IList;
                if (layoutComponentsList != null)
                {
                    for (int i = layoutComponentsList.Count - 1; i >= 0; i--)
                    {
                        var lc = layoutComponentsList[i];
                        var comp = lc.GetType().GetProperty("Component").GetValue(lc, null);
                        if (comp == componentToRemove)
                        {
                            layoutComponentsList.RemoveAt(i);
                            break;
                        }
                    }
                }
            }
        }
        catch (Exception ex)
        {
        }
    });

    vars.ResetAll = (Action)(() => {
        string[] all = new string[] { "DeadWire", "BlastFurnace", "FireWorks", "ThunderWall", "Turned" };
        foreach (string a in all) {
            vars.aatStarts[a] = -99999;
            vars.aatActive[a] = false;
        }
        vars.lastHMTime = -999999;
        vars.lastDWTime = -999999;
        vars.lastBFTime = -999999;
        vars.lastFWTime = -999999;
        vars.lastTWTime = -999999;
        vars.dwDetectionCooldownUntil = 0;
        vars.bfDetectionCooldownUntil = 0;
        vars.activeSlot = 0;
    });

    vars.ConsumeDetection = (Action)(() => {
        vars.lastHMTime = -999999;
        vars.lastDWTime = -999999;
        vars.lastBFTime = -999999;
        vars.lastFWTime = -999999;
        vars.lastTWTime = -999999;
    });

    refreshRate = 100;
}

init
{
    vars.Log("--- INIT: Processo conectado ---");
}

update
{
    if (current.levelTime == 0) return;

    if (current.levelTime < 20) {
        vars.Log(string.Format("[LT:{0}] RESTART DETECTADO", current.levelTime));
        vars.ResetAll();
        return;
    }

    int now = Environment.TickCount;

    // --- MAPA E SLOTS ---
    string map = current.currentMap ?? "";

    byte[] slots;
    if (map.Contains("zm_zod")) {
        slots = new byte[] { current.Slot_09D0, current.Slot_1530, current.Slot_0B70 };
    }
    else if (map.Contains("zm_prototype")) {
        slots = new byte[] { current.Slot_9250, current.Slot_8890, current.Slot_86F0, current.Slot_90B0 };
    }
    else if (map.Contains("zm_factory") || map.Contains("zm_castle") || map.Contains("zm_island") 
          || map.Contains("zm_stalingrad") || map.Contains("zm_theater")) {
        slots = new byte[] { current.Slot_9250, current.Slot_8890, current.Slot_86F0 };
    }
    else if (map.Contains("zm_genesis")) {
        slots = new byte[] { current.Slot_8D70, current.Slot_8BD0 };
    }
    else if (map.Contains("zm_tomb")) {
        slots = new byte[] { current.Slot_8D70, current.Slot_8F10, current.Slot_98D0 };
    }
    else if (map.Contains("zm_moon") || map.Contains("zm_cosmodrome") || map.Contains("zm_asylum") 
          || map.Contains("zm_sumpf") || map.Contains("zm_temple")) {
        slots = new byte[] { current.Slot_8550, current.Slot_7B90 };
    }
    else {
        slots = new byte[] { current.Slot_9250, current.Slot_8890, current.Slot_86F0 };
    }

    if (vars.activeSlot == 0 || vars.activeSlot > slots.Length) {
        for (int i = 0; i < slots.Length; i++) {
            if (slots[i] == 16 || slots[i] >= 200) { vars.activeSlot = i + 1; break; }
        }
    }

    string currentAAT = vars.activeSlot > 0 ? vars.ByteToAAT(slots[vars.activeSlot-1]) : "None";

    // --- DEBUG (Map e AAT na mão) ---
    if (settings["AAT_Debug"]) {
        vars.SetText("Map:", string.IsNullOrEmpty(map) ? "---" : map);
        vars.SetText("AAT:", currentAAT);
    } else {
        vars.RemoveText("Map:");
        vars.RemoveText("AAT:");
    }

    // --- MONITORAMENTO DOS GATILHOS + LOG ---

    if (current.HitmarkerAll > old.HitmarkerAll) {
        vars.lastHMTime = now;
        vars.Log(string.Format("[LT:{0}] [TC:{1}] HITMARKER | {2} -> {3} | AAT:{4}",
            current.levelTime, now, old.HitmarkerAll, current.HitmarkerAll, currentAAT));
    }

    if (old.DeadWireAddr3 != current.DeadWireAddr3) {
        vars.lastDWTime = now;
        vars.Log(string.Format("[LT:{0}] [TC:{1}] DW3_ADDR (0x4D5C5C8) | {2} -> {3} | AAT:{4} | HM_delta:{5}ms",
            current.levelTime, now, old.DeadWireAddr3, current.DeadWireAddr3, currentAAT,
            vars.lastHMTime > 0 ? (now - vars.lastHMTime).ToString() : "N/A"));
    }

    if (old.DeadWireAddr1 != current.DeadWireAddr1) {
        vars.lastDWTime = now;
        vars.Log(string.Format("[LT:{0}] [TC:{1}] DW1_ADDR (0xA5511CC) | {2} -> {3} | AAT:{4} | HM_delta:{5}ms",
            current.levelTime, now, old.DeadWireAddr1, current.DeadWireAddr1, currentAAT,
            vars.lastHMTime > 0 ? (now - vars.lastHMTime).ToString() : "N/A"));
    }

    if (old.DeadWireAddr2 != current.DeadWireAddr2) {
        vars.lastDWTime = now;
        vars.Log(string.Format("[LT:{0}] [TC:{1}] DW2_ADDR (0xA5511C4) | {2} -> {3} | AAT:{4} | HM_delta:{5}ms",
            current.levelTime, now, old.DeadWireAddr2, current.DeadWireAddr2, currentAAT,
            vars.lastHMTime > 0 ? (now - vars.lastHMTime).ToString() : "N/A"));
    }

    if (old.BlastFurnaceAddr != current.BlastFurnaceAddr) {
        vars.lastBFTime = now;
        vars.Log(string.Format("[LT:{0}] [TC:{1}] BF_ADDR (0x4D5C590) | {2} -> {3} | AAT:{4} | HM_delta:{5}ms",
            current.levelTime, now, old.BlastFurnaceAddr, current.BlastFurnaceAddr, currentAAT,
            vars.lastHMTime > 0 ? (now - vars.lastHMTime).ToString() : "N/A"));
    }

    if (old.FireWorksAddr != current.FireWorksAddr) {
        vars.lastFWTime = now;
        vars.Log(string.Format("[LT:{0}] [TC:{1}] FW_ADDR (0x51A44E0) | {2} -> {3} | AAT:{4} | HM_delta:{5}ms",
            current.levelTime, now, old.FireWorksAddr, current.FireWorksAddr, currentAAT,
            vars.lastHMTime > 0 ? (now - vars.lastHMTime).ToString() : "N/A"));
    }

    if (old.ThunderWallAddr != current.ThunderWallAddr) {
        vars.lastTWTime = now;
        vars.Log(string.Format("[LT:{0}] [TC:{1}] TW_ADDR (0x51B4F70) | {2} -> {3} | AAT:{4} | HM_delta:{5}ms",
            current.levelTime, now, old.ThunderWallAddr, current.ThunderWallAddr, currentAAT,
            vars.lastHMTime > 0 ? (now - vars.lastHMTime).ToString() : "N/A"));
    }

    if (old.TurnedAddr1 != current.TurnedAddr1) {
        vars.Log(string.Format("[LT:{0}] [TC:{1}] TURNED1 (0x49C5730) | {2} -> {3} | AAT:{4}",
            current.levelTime, now, old.TurnedAddr1, current.TurnedAddr1, currentAAT));
    }

    if (old.TurnedAddr2 != current.TurnedAddr2) {
        vars.Log(string.Format("[LT:{0}] [TC:{1}] TURNED2 (0x49C5780) | {2} -> {3} | AAT:{4}",
            current.levelTime, now, old.TurnedAddr2, current.TurnedAddr2, currentAAT));
    }

    // --- VERIFICAÇÃO DE COINCIDÊNCIA (BI-DIRECIONAL, janela de 150ms real) ---
    
    // Dead Wire
    if (!vars.aatActive["DeadWire"] && currentAAT == "DeadWire" && current.levelTime >= vars.dwDetectionCooldownUntil) {
        if (vars.lastDWTime > 0 && vars.lastHMTime > 0 && Math.Abs(vars.lastDWTime - vars.lastHMTime) <= vars.biWindow) {
            vars.aatStarts["DeadWire"] = current.levelTime;
            vars.aatActive["DeadWire"] = true;
            vars.dwDetectionCooldownUntil = current.levelTime + 60;
            vars.Log(string.Format("[LT:{0}] [TC:{1}] >>> TIMER ATIVADO: DeadWire | DW_time:{2} HM_time:{3} delta:{4}ms",
                current.levelTime, now, vars.lastDWTime, vars.lastHMTime, Math.Abs(vars.lastDWTime - vars.lastHMTime)));
            vars.ConsumeDetection();
        }
    }

    // Blast Furnace
    if (!vars.aatActive["BlastFurnace"] && currentAAT == "BlastFurnace" && current.levelTime >= vars.bfDetectionCooldownUntil) {
        if (vars.lastBFTime > 0 && vars.lastHMTime > 0 && Math.Abs(vars.lastBFTime - vars.lastHMTime) <= vars.biWindow) {
            vars.aatStarts["BlastFurnace"] = current.levelTime;
            vars.aatActive["BlastFurnace"] = true;
            vars.bfDetectionCooldownUntil = current.levelTime + 260;
            vars.Log(string.Format("[LT:{0}] [TC:{1}] >>> TIMER ATIVADO: BlastFurnace | BF_time:{2} HM_time:{3} delta:{4}ms",
                current.levelTime, now, vars.lastBFTime, vars.lastHMTime, Math.Abs(vars.lastBFTime - vars.lastHMTime)));
            vars.ConsumeDetection();
        }
    }

    // Fire Works
    if (!vars.aatActive["FireWorks"] && currentAAT == "FireWorks") {
        if (vars.lastFWTime > 0 && vars.lastHMTime > 0 && Math.Abs(vars.lastFWTime - vars.lastHMTime) <= vars.biWindow) {
            vars.aatStarts["FireWorks"] = current.levelTime;
            vars.aatActive["FireWorks"] = true;
            vars.Log(string.Format("[LT:{0}] [TC:{1}] >>> TIMER ATIVADO: FireWorks | FW_time:{2} HM_time:{3} delta:{4}ms",
                current.levelTime, now, vars.lastFWTime, vars.lastHMTime, Math.Abs(vars.lastFWTime - vars.lastHMTime)));
            vars.ConsumeDetection();
        }
    }

    // Thunder Wall
    if (!vars.aatActive["ThunderWall"] && currentAAT == "ThunderWall") {
        if (vars.lastTWTime > 0 && vars.lastHMTime > 0 && Math.Abs(vars.lastTWTime - vars.lastHMTime) <= vars.biWindow) {
            vars.aatStarts["ThunderWall"] = current.levelTime;
            vars.aatActive["ThunderWall"] = true;
            vars.Log(string.Format("[LT:{0}] [TC:{1}] >>> TIMER ATIVADO: ThunderWall | TW_time:{2} HM_time:{3} delta:{4}ms",
                current.levelTime, now, vars.lastTWTime, vars.lastHMTime, Math.Abs(vars.lastTWTime - vars.lastHMTime)));
            vars.ConsumeDetection();
        }
    }

    // Turned
    if (!vars.aatActive["Turned"] && (current.TurnedAddr1 == 1852994900 || current.TurnedAddr2 == 1852994900)) {
        vars.aatStarts["Turned"] = current.levelTime;
        vars.aatActive["Turned"] = true;
        vars.Log(string.Format("[LT:{0}] [TC:{1}] >>> TIMER ATIVADO: Turned | Addr1:{2} Addr2:{3}",
            current.levelTime, now, current.TurnedAddr1, current.TurnedAddr2));
    }

    // --- RENDERIZAÇÃO ---
    string[] labels = {"Dead Wire", "Blast Furnace", "Fire Works", "Thunder Wall", "Turned"};
    string[] keys = {"DeadWire", "BlastFurnace", "FireWorks", "ThunderWall", "Turned"};
    string[] setKeys = {"AAT_DeadWire", "AAT_BlastFurnace", "AAT_FireWorks", "AAT_ThunderWall", "AAT_Turned"};

    for (int i = 0; i < keys.Length; i++) {
        if (vars.aatActive[keys[i]] && (current.levelTime - vars.aatStarts[keys[i]]) >= vars.aatCooldowns[keys[i]]) {
            vars.aatActive[keys[i]] = false;
        }

        if (!settings[setKeys[i]]) {
            vars.RemoveText(labels[i]);
            continue;
        }

        if (vars.aatActive[keys[i]]) {
            int rem = vars.aatCooldowns[keys[i]] - (current.levelTime - vars.aatStarts[keys[i]]);
            int ms = Math.Max(0, rem * 50);
            vars.SetText(labels[i], string.Format("{0}:{1:D2}", ms / 1000, (ms % 1000) / 10));
        } else {
            vars.SetText(labels[i], "0:00");
        }
    }
}
