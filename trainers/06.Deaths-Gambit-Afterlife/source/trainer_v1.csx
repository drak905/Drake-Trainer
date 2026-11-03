// DG-AFTERLIFE TRAINER v1 — UTMT C# script (run via: UndertaleModCli load <data.win> -s trainer_v1.csx -o <patched.win>)
using System;
using System.Linq;
using System.Threading.Tasks;
using UndertaleModLib.Util;

EnsureDataLoaded();

if (Data.IsYYC())
{
    ScriptError("YYC build: no code available.");
    return;
}

GlobalDecompileContext globalDecompileContext = new(Data);
var decompilerSettings = Data.ToolInfo.DecompilerSettings;

string GetGML(string name)
{
    var code = Data.Code.ByName(name);
    if (code == null) { ScriptMessage("MISSING: " + name); return null; }
    return new Underanalyzer.Decompiler.DecompileContext(globalDecompileContext, code, decompilerSettings).DecompileToString();
}

string trainerBlock = @"
// === DG-AFTERLIFE TRAINER v1 (auto) ===
if (instance_exists(obj_player))
{
    if (global.ProHealth < global.ProMaxHealth) { global.ProHealth = global.ProMaxHealth; }
    if (global.PotionUse < global.PotionMax) { global.PotionUse = global.PotionMax; }
    if (global.Endurance < global.EnduranceMax) { global.Endurance = global.EnduranceMax; }
    if (global.soulenergy < global.soulenergymax) { global.soulenergy = global.soulenergymax; }
    with (obj_player) { energyammo = 100; if (arrowammo < 40) { arrowammo = 40; } }
}
if (keyboard_check_pressed(ord(""G"")))
{
    global.player_ultra_essence += 99999;
    save_inventorydata();
}
";

string InsertBeforeEnum(string gml, string insert)
{
    int ei = gml.IndexOf("\nenum ");
    if (ei >= 0)
        return gml.Substring(0, ei) + "\n" + insert + "\n" + gml.Substring(ei);
    return gml + "\n" + insert + "\n";
}

var importGroup = new UndertaleModLib.Compiler.CodeImportGroup(Data)
{
    MainThreadAction = MainThreadAction
};

string gv = GetGML("gml_Object_GlobalVariables_Step_0");
if (gv != null)
    importGroup.QueueReplace("gml_Object_GlobalVariables_Step_0", InsertBeforeEnum(gv, trainerBlock));

string es = GetGML("gml_Object_obj_essence_Destroy_0");
if (es != null)
    importGroup.QueueReplace("gml_Object_obj_essence_Destroy_0", InsertBeforeEnum(es, "\nglobal.player_ultra_essence += 999;\n"));

SetProgressBar(null, "Performing final import...", 0, 2);
importGroup.Import();
HideProgressBar();
ScriptMessage("TRAINER_V1_DONE");
