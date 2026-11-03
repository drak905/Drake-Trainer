"""Dead Cells trainer: patch the HashLink bytecode (hlboot.dat) with F-key cheats.

usage: build_patch.py <vanilla.hl> <patched.hl>

Everything is resolved by class / method / field *name*, so the script keeps working on other
game builds as long as the names below still exist. It aborts (without writing) otherwise.

Hotkeys (handled in a new function called at the start of pr.Game.update every frame):
  F1  God mode                (toggle)
  F2  +100,000 gold, +500 cells (one shot)
  F3  Unlimited gold & cells  (toggle)
  F4  Unlimited air jumps     (toggle)
  F5  Move speed x2           (toggle)
  F6  Reveal map + all items  (toggle, re-applied on every new level)
  F7  Unlimited items: flasks, ammo, no skill cooldowns (toggle)
  F8  Full heal               (one shot)
  F12 Show / hide the trainer menu (top-left of the HUD; toggle lines are green when ON)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import hlcode
from hlcode import HBOOL, HI32, HF64, HVOID, HREF, HNULL, HOBJ
from hlasm import Asm, insert, new_function

TAG = "[DC Trainer]"


class Ctx:
    def __init__(self, c):
        self.c = c
        self.T = {}
        self._prim()

    def _prim(self):
        c = self.c
        self.t_bool = c.find_type(HBOOL)
        self.t_i32 = c.find_type(HI32)
        self.t_f64 = c.find_type(HF64)
        self.t_void = c.find_type(HVOID)
        self.t_ref_bool = self._wrap(HREF, self.t_bool)
        self.t_null_i32 = self._wrap(HNULL, self.t_i32)
        self.t_null_f64 = self._wrap(HNULL, self.t_f64)

    def _wrap(self, kind, inner):
        for i, t in enumerate(self.c.types):
            if t.kind == kind and t.tparam == inner:
                return i
        raise KeyError(f"wrap type {kind}<{inner}> missing")

    def ty(self, name):
        return self.c.type_by_name[name]

    def fn(self, name):
        return self.c.func_by_name(name)

    def field(self, cls, name):
        fl = self.c.obj_fields(self.ty(cls))
        hits = [i for i, (n, _) in enumerate(fl) if self.c.strings[n] == name]
        if len(hits) != 1:
            raise KeyError(f"{cls}.{name}")
        return hits[0]

    def proto(self, cls, name):
        tbl = self.c.obj_protos(self.ty(cls))
        hits = [i for i, e in enumerate(tbl) if e and e[0] == name]
        if len(hits) != 1:
            raise KeyError(f"{cls}::{name}")
        return hits[0]

    def ret_type(self, f):
        return self.c.types[f.type].ret

    # -- constants
    def const_string(self, s):
        c = self.c
        g = c.add_global(self.ty("String"))
        si = c.add_string(s)
        li = c.add_int(len(s.encode("utf-16-le")) // 2)
        c.constants.append((g, [si, li]))
        return g

    def new_bool_global(self):
        return self.c.add_global(self.t_bool)


def build(src, dst):
    c = hlcode.Code(open(src, "rb").read())
    X = Ctx(c)

    # ---------------------------------------------------------------- symbols
    f_game_update = X.fn("pr.Game.update")
    f_is_pressed = X.fn("hxd.$Key.isPressed")
    f_log_text = X.fn("ui.LogManager.text")
    f_hero_kill = X.fn("en.Hero.kill")
    f_can_recv = X.fn("en.Hero.canReceiveAttack")
    f_sub_money = X.fn("en.Hero.substractMoney")
    f_sub_cells = X.fn("en.Hero.substractCells")
    f_hud_money = X.fn("en.Hero.hudSetMoney")
    f_hud_cells = X.fn("en.Hero.hudSetCells")
    f_explorer = X.fn("en.Hero.triggerExplorerInstinct")
    f_full_heal = X.fn("en.Hero.fullHeal")
    f_reveal_all = X.fn("ui.hud.MiniMap.revealAll")
    f_aj_canuse = X.fn("tool.mainSkills.AirJump.canUse")
    f_aj_set = X.fn("tool.mainSkills.AirJump.set_airJumps")
    f_run_mul = X.fn("tool.hero.HeroActiveSkillsManager.getRunSpeedMul")
    f_start_cd = X.fn("tool.hero.HeroActiveSkill.startCooldown")
    f_set_heal = X.fn("tool.mainSkills.Heal.set_healings")
    f_max_heal = X.fn("tool.mainSkills.Heal.get_maxHealings")
    f_consume = X.fn("tool.Weapon.consumeAmmo")
    f_consume2 = X.fn("tool.weap.dual.OffHandRanged.consumeAmmo")

    p_add_money = X.proto("en.Hero", "addMoney")
    p_add_cells = X.proto("en.Hero", "addCells")
    p_heal = X.proto("en.Hero", "heal")

    # menu overlay (h2d UI in the HUD layer)
    f_flow_new = X.fn("h2d.$Flow.__constructor__")
    f_flow_vert = X.fn("h2d.Flow.set_isVertical")
    f_flow_pad = X.fn("h2d.Flow.set_padding")
    f_flow_vsp = X.fn("h2d.Flow.set_verticalSpacing")
    f_flow_bg = X.fn("h2d.Flow.set_backgroundTile")
    f_tile_color = X.fn("h2d.$Tile.fromColor")
    f_make_text = X.fn("Assets.makeText")
    f_text_color = X.fn("h2d.HtmlText.set_textColor")
    f_set_visible = X.fn("h2d.Object.set_visible")
    f_hud_ps = X.fn("ui.HUD.get_pixelScale")
    fd_hud_root = X.field("ui.HUD", "root")
    fd_obj_x = X.field("h2d.Flow", "x")
    fd_obj_y = X.field("h2d.Flow", "y")
    fd_obj_pc = X.field("h2d.Flow", "posChanged")

    fd_game_hero = X.field("pr.Game", "hero")
    fd_game_data = X.field("pr.Game", "data")
    fd_game_hud = X.field("pr.Game", "hud")
    fd_game_log = X.field("pr.Game", "log")
    fd_money = X.field("tool.GameData", "money")
    fd_cells = X.field("en.Hero", "cells")
    fd_life = X.field("en.Hero", "life")
    fd_maxlife = X.field("en.Hero", "maxLife")
    fd_hlevel = X.field("en.Hero", "_level")
    fd_lvl_map = X.field("pr.Level", "map")
    fd_hud_mini = X.field("ui.HUD", "minimap")
    fd_mini_fow = X.field("ui.hud.MiniMap", "fow")
    fd_mini_lvl = X.field("ui.hud.MiniMap", "level")

    t_game, t_hero = X.ty("pr.Game"), X.ty("en.Hero")
    t_data, t_level = X.ty("tool.GameData"), X.ty("pr.Level")
    t_hud, t_mini = X.ty("ui.HUD"), X.ty("ui.hud.MiniMap")
    t_log, t_str = X.ty("ui.LogManager"), X.ty("String")
    t_tile = X.ty("h2d.Tile")
    t_lmap = c.obj_fields(t_level)[fd_lvl_map][1]
    t_fow = c.obj_fields(t_mini)[fd_mini_fow][1]

    # sanity: the method signatures we rely on
    def sig(f):
        return c.tname(f.type)
    expect = {
        f_is_pressed: "(i32)->bool",
        f_can_recv: "(en.Hero,tool.atk.AttackData)->bool",
        f_hero_kill: "(en.Hero)->void",
        f_sub_money: "(en.Hero,i32,Ref<bool>)->void",
        f_sub_cells: "(en.Hero,i32,Ref<bool>)->void",
        f_explorer: "(en.Hero,Ref<bool>)->void",
        f_aj_canuse: "(tool.mainSkills.AirJump)->bool",
        f_aj_set: "(tool.mainSkills.AirJump,i32)->i32",
        f_run_mul: "(tool.hero.HeroActiveSkillsManager)->f64",
        f_set_heal: "(tool.mainSkills.Heal,i32)->i32",
        f_max_heal: "(tool.mainSkills.Heal)->i32",
        f_consume: "(tool.Weapon)->bool",
        f_consume2: "(tool.weap.dual.OffHandRanged)->bool",
        f_log_text: "(ui.LogManager,String,Null<i32>,h2d.Tile,Null<f64>)->void",
        f_reveal_all: "(ui.hud.MiniMap)->void",
        f_full_heal: "(en.Hero)->void",
        f_game_update: "(pr.Game)->void",
        f_hud_money: "(en.Hero,i32)->void",
        f_hud_cells: "(en.Hero,i32)->void",
        f_flow_new: "(h2d.Flow,h2d.Object)->void",
        f_flow_vert: "(h2d.Flow,bool)->bool",
        f_flow_pad: "(h2d.Flow,i32)->i32",
        f_flow_vsp: "(h2d.Flow,i32)->i32",
        f_flow_bg: "(h2d.Flow,h2d.Tile)->h2d.Tile",
        f_make_text: "(String,Null<i32>,Null<bool>,h2d.Object)->ui.Text",
        f_text_color: "(h2d.HtmlText,i32)->i32",
        f_set_visible: "(h2d.Object,bool)->bool",
        f_hud_ps: "(ui.HUD)->f64",
    }
    if not sig(f_tile_color).startswith("(i32,Null<i32>,Null<i32>,Null<f64>,") or not sig(f_tile_color).endswith(")->h2d.Tile"):
        raise SystemExit("Tile.fromColor signature changed")
    for f, s in expect.items():
        if sig(f) != s:
            raise SystemExit(f"signature changed: f{f.findex} {c.fname[f.findex]} {sig(f)} != {s}")
    if not sig(f_start_cd).endswith(")->void"):
        raise SystemExit("startCooldown signature changed")

    # ---------------------------------------------------------------- globals
    G = {k: X.new_bool_global() for k in ("god", "infmoney", "jump", "speed", "map", "items", "menuhide")}
    g_map_level = c.add_global(t_level)
    g_map_mini = c.add_global(t_mini)
    t_flow, t_uitext = X.ty("h2d.Flow"), X.ty("ui.Text")
    g_menu = c.add_global(t_flow)          # the menu panel
    g_menu_hud = c.add_global(t_hud)       # HUD it was built in (HUD is rebuilt between levels)
    TOGGLES = [("god", 112, "F1   God mode"), ("infmoney", 114, "F3   Unlimited gold & cells"),
               ("jump", 115, "F4   Unlimited jumps"), ("speed", 116, "F5   Speed x2"),
               ("map", 117, "F6   Reveal map & items"), ("items", 118, "F7   Unlimited flasks / ammo / skills")]
    g_line = {k: c.add_global(t_uitext) for k, _, _ in TOGGLES}
    S = {}
    names = {"god": "God mode", "infmoney": "Unlimited gold & cells", "jump": "Unlimited jumps",
             "speed": "Speed x2", "map": "Reveal map & items", "items": "Unlimited flasks/ammo/skills"}
    for k, n in names.items():
        S[k + "1"] = X.const_string(f"{TAG} {n}: ON")
        S[k + "0"] = X.const_string(f"{TAG} {n}: OFF")
    S["gold"] = X.const_string(f"{TAG} +100000 gold, +500 cells")
    S["heal"] = X.const_string(f"{TAG} Full heal")
    MENU_HEAD = X.const_string("DC TRAINER   (F12 hide / show)")
    MENU_LINES = {k: X.const_string(t) for k, _, t in TOGGLES}
    MENU_F2 = X.const_string("F2   +100,000 gold  +500 cells")
    MENU_F8 = X.const_string("F8   Full heal")
    COL_HEAD, COL_ON, COL_OFF, COL_BTN = 0xFFD24A, 0x5CFF5C, 0x8C8C8C, 0xFFFFFF

    # ---------------------------------------------------------------- tick(game)
    a = Asm([t_game])
    rb, rb2 = a.reg(X.t_bool), a.reg(X.t_bool)
    ri, ri2 = a.reg(X.t_i32), a.reg(X.t_i32)
    rv = a.reg(X.t_void)
    rs = a.reg(t_str)
    rlog = a.reg(t_log)
    rni, rtile, rnf = a.reg(X.t_null_i32), a.reg(t_tile), a.reg(X.t_null_f64)
    rhero, rdata, rlvl, rprev = a.reg(t_hero), a.reg(t_data), a.reg(t_level), a.reg(t_level)
    rlmap, rhud, rmini, rmprev, rfow = a.reg(t_lmap), a.reg(t_hud), a.reg(t_mini), a.reg(t_mini), a.reg(t_fow)
    rref = a.reg(X.t_ref_bool)
    rhealret = a.reg(X.ret_type(c.fidx[c.obj_protos(t_hero)[p_heal][1]]))
    rmoneyret = a.reg(X.ret_type(c.fidx[c.obj_protos(t_hero)[p_add_money][1]]))
    rcellret = a.reg(X.ret_type(c.fidx[c.obj_protos(t_hero)[p_add_cells][1]]))
    rflow, rflow2 = a.reg(t_flow), a.reg(t_flow)
    rhud2 = a.reg(t_hud)
    rroot = a.reg(c.obj_fields(t_hud)[fd_hud_root][1])
    rtext = a.reg(t_uitext)
    rnb = a.reg(c.types[f_make_text.type].args[2])
    ralloc = a.reg(c.types[f_tile_color.type].args[4])
    rf, rf2 = a.reg(X.t_f64), a.reg(X.t_f64)
    rtile2 = a.reg(t_tile)
    uid = [0]

    def L(prefix):
        uid[0] += 1
        return f"{prefix}{uid[0]}"

    def say_reg():
        """Show string in register rs through game.log.text (if the log exists)."""
        skip = L("say")
        a.op("Field", rlog, 0, fd_game_log)
        a.jmp("JNull", rlog, to=skip)
        a.op("Null", rni); a.op("Null", rtile); a.op("Null", rnf)
        a.op("CallN", rv, f_log_text.findex, 5, rlog, rs, rni, rtile, rnf)
        a.label(skip)

    def say(gs):
        a.op("GetGlobal", rs, gs)
        say_reg()

    def key(code, to):
        a.op("Int", ri, c.add_int(code))
        a.op("Call1", rb, f_is_pressed.findex, ri)
        a.jmp("JFalse", rb, to=to)

    def toggle(code, k, after=None):
        nxt, off, show = L("n"), L("off"), L("show")
        key(code, nxt)
        a.op("GetGlobal", rb, G[k])
        a.op("Not", rb2, rb)
        a.op("SetGlobal", G[k], rb2)
        if after:
            after()
        a.jmp("JFalse", rb2, to=off)
        a.op("GetGlobal", rs, S[k + "1"])
        a.jmp("JAlways", to=show)
        a.label(off)
        a.op("GetGlobal", rs, S[k + "0"])
        a.label(show)
        say_reg()
        a.label(nxt)

    a.op("Field", rhero, 0, fd_game_hero)

    def reset_map():  # force the reveal to run again on the next frame
        a.op("Null", rprev)
        a.op("SetGlobal", g_map_level, rprev)

    toggle(112, "god")        # F1
    toggle(114, "infmoney")   # F3
    toggle(115, "jump")       # F4
    toggle(116, "speed")      # F5
    toggle(117, "map", reset_map)  # F6
    toggle(118, "items")      # F7

    # F2: add gold / cells
    nx = L("n")
    key(113, nx)
    a.jmp("JNull", rhero, to=nx)
    a.op("Bool", rb, 1)
    a.op("Ref", rref, rb)
    a.op("Int", ri, c.add_int(100000))
    a.op("CallMethod", rmoneyret, p_add_money, 3, rhero, ri, rref)
    a.op("Int", ri, c.add_int(500))
    a.op("CallMethod", rcellret, p_add_cells, 3, rhero, ri, rref)
    say(S["gold"])
    a.label(nx)

    # F8: full heal
    nx = L("n")
    key(119, nx)
    a.jmp("JNull", rhero, to=nx)
    a.op("Call1", rv, f_full_heal.findex, rhero)
    say(S["heal"])
    a.label(nx)

    # F12: hide / show the menu
    nx = L("n")
    key(123, nx)
    a.op("GetGlobal", rb, G["menuhide"])
    a.op("Not", rb2, rb)
    a.op("SetGlobal", G["menuhide"], rb2)
    a.label(nx)

    # ---- trainer menu, top-left of the HUD layer (rebuilt whenever the game rebuilds its HUD)
    a.op("Field", rhud, 0, fd_game_hud)
    a.jmp("JNull", rhud, to="nomenu")
    a.op("Field", rroot, rhud, fd_hud_root)
    a.jmp("JNull", rroot, to="nomenu")
    a.op("GetGlobal", rflow, g_menu)
    a.jmp("JNull", rflow, to="build")
    a.op("GetGlobal", rhud2, g_menu_hud)
    a.jmp("JEq", rhud, rhud2, to="update")
    a.label("build")
    a.op("New", rflow)
    a.op("Call2", rv, f_flow_new.findex, rflow, rroot)
    a.op("Bool", rb, 1)
    a.op("Call2", rb, f_flow_vert.findex, rflow, rb)
    a.op("Int", ri, c.add_int(8))
    a.op("Call2", ri, f_flow_pad.findex, rflow, ri)
    a.op("Int", ri, c.add_int(1))
    a.op("Call2", ri, f_flow_vsp.findex, rflow, ri)
    a.op("Int", ri, c.add_int(0x000000))          # translucent black background
    a.op("Null", rni); a.op("Null", rni)
    a.op("Float", rf, c.add_float(0.6))
    a.op("ToDyn", rnf, rf)
    a.op("Null", ralloc)
    a.op("CallN", rtile2, f_tile_color.findex, 5, ri, rni, rni, rnf, ralloc)
    a.op("Call2", rtile2, f_flow_bg.findex, rflow, rtile2)
    a.op("Call1", rf, f_hud_ps.findex, rhud)       # margin = 6 * HUD pixel scale
    a.op("Float", rf2, c.add_float(6.0))
    a.op("Mul", rf, rf, rf2)
    a.op("SetField", rflow, fd_obj_x, rf)
    a.op("SetField", rflow, fd_obj_y, rf)
    a.op("Bool", rb, 1)
    a.op("SetField", rflow, fd_obj_pc, rb)
    a.op("Null", rnb)

    def line(gs, color, store=None):
        a.op("GetGlobal", rs, gs)
        a.op("Int", ri, c.add_int(color))
        a.op("ToDyn", rni, ri)
        a.op("Call4", rtext, f_make_text.findex, rs, rni, rnb, rflow)
        if store is not None:
            a.op("SetGlobal", store, rtext)

    line(MENU_HEAD, COL_HEAD)
    for k, _, _ in TOGGLES:
        line(MENU_LINES[k], COL_OFF, g_line[k])
    line(MENU_F2, COL_BTN)
    line(MENU_F8, COL_BTN)
    a.op("SetGlobal", g_menu, rflow)
    a.op("SetGlobal", g_menu_hud, rhud)
    a.label("update")
    # visibility + green/grey state colours (both setters return early when nothing changed)
    a.op("GetGlobal", rb, G["menuhide"])
    a.op("Not", rb2, rb)
    a.op("Call2", rb2, f_set_visible.findex, rflow, rb2)
    for k, _, _ in TOGGLES:
        off = L("c")
        set_ = L("s")
        a.op("GetGlobal", rtext, g_line[k])
        a.jmp("JNull", rtext, to=set_ + "x")
        a.op("Int", ri, c.add_int(COL_OFF))
        a.op("GetGlobal", rb, G[k])
        a.jmp("JFalse", rb, to=set_)
        a.op("Int", ri, c.add_int(COL_ON))
        a.label(set_)
        a.op("Call2", ri, f_text_color.findex, rtext, ri)
        a.label(set_ + "x")
    a.label("nomenu")

    # ---- per-frame effects (need a hero)
    a.jmp("JNull", rhero, to="end")

    # God mode: keep life topped up (covers damage paths that skip canReceiveAttack)
    a.op("GetGlobal", rb, G["god"])
    a.jmp("JFalse", rb, to="nogod")
    a.op("Field", ri, rhero, fd_life)
    a.op("Field", ri2, rhero, fd_maxlife)
    a.jmp("JSGte", ri, ri2, to="nogod")
    a.op("Sub", ri2, ri2, ri)
    a.op("CallMethod", rhealret, p_heal, 2, rhero, ri2)
    a.label("nogod")

    # Unlimited gold & cells: keep balances at a floor (spending is blocked by the method patches)
    a.op("GetGlobal", rb, G["infmoney"])
    a.jmp("JFalse", rb, to="nomoney")
    a.op("Field", rdata, 0, fd_game_data)
    a.jmp("JNull", rdata, to="cells")
    a.op("Field", ri, rdata, fd_money)
    a.op("Int", ri2, c.add_int(999999))
    a.jmp("JSGte", ri, ri2, to="cells")
    a.op("SetField", rdata, fd_money, ri2)
    a.op("Call2", rv, f_hud_money.findex, rhero, ri2)
    a.label("cells")
    a.op("Field", ri, rhero, fd_cells)
    a.op("Int", ri2, c.add_int(9999))
    a.jmp("JSGte", ri, ri2, to="nomoney")
    a.op("SetField", rhero, fd_cells, ri2)
    a.op("Call2", rv, f_hud_cells.findex, rhero, ri2)
    a.label("nomoney")

    # Reveal map: once per (level, minimap) pair
    a.op("GetGlobal", rb, G["map"])
    a.jmp("JFalse", rb, to="nomap")
    a.op("Field", rlvl, rhero, fd_hlevel)
    a.jmp("JNull", rlvl, to="nomap")
    a.op("Field", rlmap, rlvl, fd_lvl_map)
    a.jmp("JNull", rlmap, to="nomap")
    a.op("Field", rhud, 0, fd_game_hud)
    a.jmp("JNull", rhud, to="nomap")
    a.op("Field", rmini, rhud, fd_hud_mini)
    a.jmp("JNull", rmini, to="nomap")
    a.op("Field", rfow, rmini, fd_mini_fow)
    a.jmp("JNull", rfow, to="nomap")
    a.op("Field", rprev, rmini, fd_mini_lvl)
    a.jmp("JNull", rprev, to="nomap")
    a.op("GetGlobal", rprev, g_map_level)
    a.op("GetGlobal", rmprev, g_map_mini)
    a.jmp("JNotEq", rlvl, rprev, to="doreveal")
    a.jmp("JEq", rmini, rmprev, to="nomap")
    a.label("doreveal")
    a.op("SetGlobal", g_map_level, rlvl)
    a.op("SetGlobal", g_map_mini, rmini)
    a.op("Bool", rb, 1)
    a.op("Ref", rref, rb)
    a.op("Call2", rv, f_explorer.findex, rhero, rref)
    a.op("Call1", rv, f_reveal_all.findex, rmini)
    a.label("nomap")

    a.label("end")
    a.op("Ret", rv)
    tick = new_function(c, f_game_update.type, a, f_game_update.debug[0] if f_game_update.debug else None)

    # ---------------------------------------------------------------- method patches
    def prepend(f, build_fn):
        pa = Asm(f.regs)
        build_fn(pa)
        insert(c, f, 0, pa)

    def ret_if(gkey, value=None, kind=None):
        """if (G) return <value>; value: None -> void, bool/float constant otherwise."""
        def b(pa):
            r = pa.reg(X.t_bool)
            pa.op("GetGlobal", r, G[gkey])
            pa.jmp("JFalse", r, to="body")
            if kind == "void":
                rv_ = pa.reg(X.t_void)
                pa.op("Ret", rv_)
            elif kind == "bool":
                rr = pa.reg(X.t_bool)
                pa.op("Bool", rr, 1 if value else 0)
                pa.op("Ret", rr)
            elif kind == "f64":
                rr = pa.reg(X.t_f64)
                pa.op("Float", rr, c.add_float(value))
                pa.op("Ret", rr)
        return b

    # Game loop -> trainer tick
    def call_tick(pa):
        r = pa.reg(X.t_void)
        pa.op("Call1", r, tick, 0)
    prepend(f_game_update, call_tick)

    prepend(f_can_recv, ret_if("god", False, "bool"))       # attacks pass through the hero
    prepend(f_hero_kill, ret_if("god", kind="void"))        # scripted/instant kills ignored
    prepend(f_sub_money, ret_if("infmoney", kind="void"))   # spending gold does nothing
    prepend(f_sub_cells, ret_if("infmoney", kind="void"))   # spending cells does nothing
    prepend(f_run_mul, ret_if("speed", 1.0, "f64"))         # +100% run speed (base bonus is 0.0)
    prepend(f_start_cd, ret_if("items", kind="void"))       # skills never go on cooldown
    prepend(f_consume, ret_if("items", True, "bool"))       # ammo is never consumed
    prepend(f_consume2, ret_if("items", True, "bool"))

    def aj(pa):  # reset the air-jump counter before every canUse check
        r = pa.reg(X.t_bool)
        r0 = pa.reg(X.t_i32)
        pa.op("GetGlobal", r, G["jump"])
        pa.jmp("JFalse", r, to="body")
        pa.op("Int", r0, c.add_int(0))
        pa.op("Call2", r0, f_aj_set.findex, 0, r0)
    prepend(f_aj_canuse, aj)

    def heal_set(pa):  # any write to the flask counter writes the maximum instead
        r = pa.reg(X.t_bool)
        pa.op("GetGlobal", r, G["items"])
        pa.jmp("JFalse", r, to="body")
        pa.op("Call1", 1, f_max_heal.findex, 0)
    prepend(f_set_heal, heal_set)

    out = c.serialize()
    # self-check: the result must parse and contain the new function
    chk = hlcode.Code(out)
    assert len(chk.functions) == len(c.functions) and tick in chk.fidx
    open(dst, "wb").write(out)
    print(f"patched: {len(out)} bytes, tick=f{tick}, globals +{len(c.globals) - X.c.nglobals}")
    return tick


if __name__ == "__main__":
    build(sys.argv[1], sys.argv[2])
