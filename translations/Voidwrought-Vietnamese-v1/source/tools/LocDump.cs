// Recon plugin (NOT shipped): dumps Voidwrought's I2 Localization source (all languages), TMP fonts and settings
// to BepInEx\loc_dump. Read-only.
using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text;
using BepInEx;
using I2.Loc;
using TMPro;
using UnityEngine;

namespace VwLocDump
{
    [BepInPlugin("com.research.vwlocdump", "Vw Loc Dump", "0.1.0")]
    public class LocDumpPlugin : BaseUnityPlugin
    {
        float t0;
        bool termsDone, fontsDone;
        string outDir;

        void Awake()
        {
            outDir = Path.Combine(Paths.BepInExRootPath, "loc_dump");
            Directory.CreateDirectory(outDir);
            t0 = Time.realtimeSinceStartup;
        }

        static string J(string s)
        {
            if (s == null) return "null";
            var sb = new StringBuilder("\"");
            foreach (char c in s)
            {
                switch (c)
                {
                    case '"': sb.Append("\\\""); break;
                    case '\\': sb.Append("\\\\"); break;
                    case '\n': sb.Append("\\n"); break;
                    case '\r': sb.Append("\\r"); break;
                    case '\t': sb.Append("\\t"); break;
                    default:
                        if (c < 32) sb.AppendFormat("\\u{0:x4}", (int)c); else sb.Append(c);
                        break;
                }
            }
            return sb.Append('"').ToString();
        }

        void Update()
        {
            if (Time.realtimeSinceStartup - t0 < 8f) return;
            try
            {
                if (!termsDone && LocalizationManager.Sources.Count > 0) { DumpTerms(); termsDone = true; }
                if (!fontsDone && termsDone && Time.realtimeSinceStartup - t0 > 20f) { DumpFonts(); fontsDone = true; }
            }
            catch (Exception e) { Logger.LogError(e.ToString()); termsDone = fontsDone = true; }
        }

        void DumpTerms()
        {
            var sb = new StringBuilder();
            for (int s = 0; s < LocalizationManager.Sources.Count; s++)
            {
                var src = LocalizationManager.Sources[s];
                src.LoadAllLanguages(true);
                sb.Append("{\"source\":").Append(s).Append(",\"global\":").Append(src.mIsGlobalSource ? "true" : "false");
                sb.Append(",\"owner\":").Append(J(src.ownerObject != null ? src.ownerObject.name : null));
                sb.Append(",\"languages\":[");
                for (int i = 0; i < src.mLanguages.Count; i++)
                {
                    var l = src.mLanguages[i];
                    if (i > 0) sb.Append(',');
                    sb.Append("{\"name\":").Append(J(l.Name)).Append(",\"code\":").Append(J(l.Code)).Append(",\"flags\":").Append((int)l.Flags).Append('}');
                }
                sb.Append("],\"terms\":[\n");
                for (int i = 0; i < src.mTerms.Count; i++)
                {
                    var t = src.mTerms[i];
                    if (i > 0) sb.Append(",\n");
                    sb.Append("{\"t\":").Append(J(t.Term)).Append(",\"ty\":").Append((int)t.TermType).Append(",\"v\":[");
                    for (int k = 0; k < t.Languages.Length; k++) { if (k > 0) sb.Append(','); sb.Append(J(t.Languages[k])); }
                    sb.Append("]}");
                }
                sb.Append("\n]}\n");
                Logger.LogInfo("source " + s + ": langs=" + src.mLanguages.Count + " terms=" + src.mTerms.Count);
            }
            File.WriteAllText(Path.Combine(outDir, "terms.jsonl"), sb.ToString(), new UTF8Encoding(false));
            Logger.LogInfo("terms dumped; current language = " + LocalizationManager.CurrentLanguage + " all=" + string.Join(",", LocalizationManager.GetAllLanguages(true).ToArray()));
        }

        void DumpFonts()
        {
            var sb = new StringBuilder();
            string vi = "ăâđêôơưĂÂĐÊÔƠƯàáảãạằắẳẵặầấẩẫậèéẻẽẹềếểễệìíỉĩịòóỏõọồốổỗộờớởỡợùúủũụừứửữựỳýỷỹỵÀÁẢÃẠẰẮẲẴẶẦẤẨẪẬÈÉẺẼẸỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌỒỐỔỖỘỜỚỞỠỢÙÚỦŨỤỪỨỬỮỰỲÝỶỸỴ";
            var fonts = Resources.FindObjectsOfTypeAll<TMP_FontAsset>();
            foreach (var f in fonts)
            {
                int missing = 0; var miss = new StringBuilder();
                foreach (char c in vi) if (!f.HasCharacter(c, false)) { missing++; miss.Append(c); }
                sb.Append(f.name).Append("\tpop=").Append(f.atlasPopulationMode)
                  .Append("\tchars=").Append(f.characterTable != null ? f.characterTable.Count : -1)
                  .Append("\tfallbacks=");
                if (f.fallbackFontAssetTable != null) foreach (var fb in f.fallbackFontAssetTable) sb.Append(fb != null ? fb.name : "null").Append(';');
                sb.Append("\tviMissing=").Append(missing).Append(" [").Append(miss).Append("]")
                  .Append("\tsrcfont=").Append(f.sourceFontFile != null ? f.sourceFontFile.name : "-")
                  .Append("\tatlas=").Append(f.atlasWidth).Append('x').Append(f.atlasHeight)
                  .Append("\tpt=").Append(f.faceInfo.pointSize).Append("\tpad=").Append(f.atlasPadding)
                  .Append("\tmat=").Append(f.material != null ? f.material.name + "/" + (f.material.shader != null ? f.material.shader.name : "?") : "-").Append('\n');
            }
            var gf = TMP_Settings.fallbackFontAssets;
            sb.Append("TMP_Settings fallbacks: ");
            if (gf != null) foreach (var f in gf) sb.Append(f != null ? f.name : "null").Append(';');
            sb.Append('\n');
            // Initializer / SettingsMenu serialized font arrays
            foreach (var typeName in new[] { "Initializer", "UI.SettingsMenu" })
            {
                var t = typeof(Initializer).Assembly.GetType(typeName);
                if (t == null) continue;
                var objs = Resources.FindObjectsOfTypeAll(t);
                sb.Append(typeName).Append(" instances=").Append(objs.Length).Append('\n');
                foreach (var o in objs)
                    foreach (var fi in t.GetFields(BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public))
                    {
                        if (fi.FieldType == typeof(TMP_FontAsset)) { var v = fi.GetValue(o) as TMP_FontAsset; sb.Append("  ").Append(fi.Name).Append('=').Append(v != null ? v.name : "null").Append('\n'); }
                        else if (fi.FieldType == typeof(TMP_FontAsset[])) { var v = fi.GetValue(o) as TMP_FontAsset[]; sb.Append("  ").Append(fi.Name).Append('=').Append(v == null ? "null" : string.Join(",", Array.ConvertAll(v, x => x != null ? x.name : "null"))).Append('\n'); }
                    }
            }
            File.WriteAllText(Path.Combine(outDir, "fonts.txt"), sb.ToString(), new UTF8Encoding(false));
            Logger.LogInfo("fonts dumped: " + fonts.Length);
        }
    }
}
