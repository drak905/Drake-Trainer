// DG-AFTERLIFE TRAINER v2 — UTMT C# script (run via: UndertaleModCli load <vanilla.win> -s trainer_v2.csx -o <patched.win>)
// Toggles: F1 = God Mode + healing feathers | F2 = Endurance + Soul Energy + Ammo | F3 = Essence pickup bonus
// G (always): +99999 ultra essence + save. All defaults ON. State in global.tr_god/tr_stam/tr_ess (init once).
// Anti-cheat guard: heals clamp to ProMaxHealth (never exceed 19999 room_hacker tripwire).
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
if (!variable_global_exists(""tr_god"")) { global.tr_god = 1; global.tr_stam = 1; global.tr_ess = 1; }
if (keyboard_check_pressed(vk_f1)) { global.tr_god = 1 - global.tr_god; show_debug_message(""Trainer: God "" + string(global.tr_god)); }
if (keyboard_check_pressed(vk_f2)) { global.tr_stam = 1 - global.tr_stam; show_debug_message(""Trainer: Stamina/Soul/Ammo "" + string(global.tr_stam)); }
if (keyboard_check_pressed(vk_f3)) { global.tr_ess = 1 - global.tr_ess; show_debug_message(""Trainer: Essence bonus "" + string(global.tr_ess)); }
if (global.tr_god == 1 && instance_exists(obj_player))
{
    if (global.ProHealth < global.ProMaxHealth) { global.ProHealth = global.ProMaxHealth; }
    if (global.PotionUse < global.PotionMax) { global.PotionUse = global.PotionMax; }
}
if (global.tr_stam == 1)
{
    if (global.Endurance < global.EnduranceMax) { global.Endurance = global.EnduranceMax; }
    if (global.soulenergy < global.soulenergymax) { global.soulenergy = global.soulenergymax; }
    if (instance_exists(obj_player))
    {
        with (obj_player) { energyammo = 100; if (arrowammo < 40) { arrowammo = 40; } }
    }
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
    importGroup.QueueReplace("gml_Object_obj_essence_Destroy_0", InsertBeforeEnum(es, "\nif (variable_global_exists(\"tr_ess\") == 0 || global.tr_ess == 1) { global.player_ultra_essence += 999; }\n"));

SetProgressBar(null, "Performing final import...", 0, 2);
importGroup.Import();
HideProgressBar();
ScriptMessage("TRAINER_V2_DONE");
