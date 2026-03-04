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

    vars.ByteToAAT = (Func<byte, string>)((val) => {
        if (val == 200) return "BlastFurnace";
        if (val == 208) return "DeadWire";
        if (val == 216) return "FireWorks";
        if (val == 224) return "ThunderWall";
        if (val == 232) return "Turned";
        return val == 16 ? "None" : "";
    });

    vars.SetText = (Action<string, object>)((text1, text2) => {
        string val = text2 != null ? text2.ToString() : "";
        var comps = timer.Layout.Components.Where(x => x.GetType().Name == "TextComponent");
        foreach (var c in comps) {
            var s = c.GetType().GetProperty("Settings").GetValue(c, null);
            if ((string)s.GetType().GetProperty("Text1").GetValue(s, null) == text1) {
                s.GetType().GetProperty("Text2").SetValue(s, val);
            }
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

    vars.componentsCreated = false;
    refreshRate = 100;
}

init
{
    vars.componentsCreated = false;
}

update
{
    if (current.levelTime == 0) return;

    if (current.levelTime < 20) {
        vars.ResetAll();
        return;
    }

    int now = Environment.TickCount;

    // --- MAPA E SLOTS ---
    string map = current.currentMap ?? "";
    vars.SetText("Map:", string.IsNullOrEmpty(map) ? "---" : map);

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
    vars.SetText("AAT:", currentAAT);
    vars.SetText("Slot:", vars.activeSlot.ToString());

    // --- MONITORAMENTO DOS GATILHOS ---

    if (current.HitmarkerAll > old.HitmarkerAll) vars.lastHMTime = now;

    if (old.DeadWireAddr3 != current.DeadWireAddr3) vars.lastDWTime = now;
    if (old.DeadWireAddr1 != current.DeadWireAddr1) vars.lastDWTime = now;
    if (old.DeadWireAddr2 != current.DeadWireAddr2) vars.lastDWTime = now;
    if (old.BlastFurnaceAddr != current.BlastFurnaceAddr) vars.lastBFTime = now;
    if (old.FireWorksAddr != current.FireWorksAddr) vars.lastFWTime = now;
    if (old.ThunderWallAddr != current.ThunderWallAddr) vars.lastTWTime = now;

    // --- VERIFICAÇÃO DE COINCIDÊNCIA (BI-DIRECIONAL, janela de 150ms real) ---
    
    // Dead Wire
    if (!vars.aatActive["DeadWire"] && currentAAT == "DeadWire" && current.levelTime >= vars.dwDetectionCooldownUntil) {
        if (vars.lastDWTime > 0 && vars.lastHMTime > 0 && Math.Abs(vars.lastDWTime - vars.lastHMTime) <= vars.biWindow) {
            vars.aatStarts["DeadWire"] = current.levelTime;
            vars.aatActive["DeadWire"] = true;
            vars.dwDetectionCooldownUntil = current.levelTime + 60;
            vars.ConsumeDetection();
        }
    }

    // Blast Furnace
    if (!vars.aatActive["BlastFurnace"] && currentAAT == "BlastFurnace" && current.levelTime >= vars.bfDetectionCooldownUntil) {
        if (vars.lastBFTime > 0 && vars.lastHMTime > 0 && Math.Abs(vars.lastBFTime - vars.lastHMTime) <= vars.biWindow) {
            vars.aatStarts["BlastFurnace"] = current.levelTime;
            vars.aatActive["BlastFurnace"] = true;
            vars.bfDetectionCooldownUntil = current.levelTime + 260;
            vars.ConsumeDetection();
        }
    }

    // Fire Works
    if (!vars.aatActive["FireWorks"] && currentAAT == "FireWorks") {
        if (vars.lastFWTime > 0 && vars.lastHMTime > 0 && Math.Abs(vars.lastFWTime - vars.lastHMTime) <= vars.biWindow) {
            vars.aatStarts["FireWorks"] = current.levelTime;
            vars.aatActive["FireWorks"] = true;
            vars.ConsumeDetection();
        }
    }

    // Thunder Wall
    if (!vars.aatActive["ThunderWall"] && currentAAT == "ThunderWall") {
        if (vars.lastTWTime > 0 && vars.lastHMTime > 0 && Math.Abs(vars.lastTWTime - vars.lastHMTime) <= vars.biWindow) {
            vars.aatStarts["ThunderWall"] = current.levelTime;
            vars.aatActive["ThunderWall"] = true;
            vars.ConsumeDetection();
        }
    }

    // Turned
    if (!vars.aatActive["Turned"] && (current.TurnedAddr1 == 1852994900 || current.TurnedAddr2 == 1852994900)) {
        vars.aatStarts["Turned"] = current.levelTime;
        vars.aatActive["Turned"] = true;
    }

    // --- RENDERIZAÇÃO ---
    string[] labels = {"Dead Wire", "Blast Furnace", "Fire Works", "Thunder Wall", "Turned"};
    string[] keys = {"DeadWire", "BlastFurnace", "FireWorks", "ThunderWall", "Turned"};
    string[] setKeys = {"AAT_DeadWire", "AAT_BlastFurnace", "AAT_FireWorks", "AAT_ThunderWall", "AAT_Turned"};

    for (int i = 0; i < keys.Length; i++) {
        if (vars.aatActive[keys[i]] && (current.levelTime - vars.aatStarts[keys[i]]) >= vars.aatCooldowns[keys[i]]) {
            vars.aatActive[keys[i]] = false;
        }
        if (!settings[setKeys[i]]) continue;

        if (vars.aatActive[keys[i]]) {
            int rem = vars.aatCooldowns[keys[i]] - (current.levelTime - vars.aatStarts[keys[i]]);
            int ms = Math.Max(0, rem * 50);
            vars.SetText(labels[i], string.Format("{0}:{1:D2}", ms / 1000, (ms % 1000) / 10));
        } else {
            vars.SetText(labels[i], "0:00");
        }
    }
}
