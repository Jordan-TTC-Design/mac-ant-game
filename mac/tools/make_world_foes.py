#!/usr/bin/env python3
"""Draws an icon (16x16 pixel art) for every foe of the big world and every great monster, into one sheet.

    python3 tools/make_world_foes.py                    # writes Resources/World/foes.png and foes.json
    python3 tools/make_world_foes.py --preview out.png  # also a zoomed contact sheet with the ids

The phone's map and battle replays (and later the Mac's world window) show these instead of emoji, so the big world is
pixel art like the camp. foes.json maps each id to its place in the sheet (8 across). The camp's own monsters (slime,
giant rat, bat, frog) are drawn by make_monsters.py; their first frame is used here, so they look the same everywhere.

Most icons are drawn as the left half (8 columns) and mirrored; the rest are drawn whole. Letters are colours from the
icon's palette, "." is empty; a dark outline goes round everything.
"""
import json
import os
import sys

from make_goblin import Canvas, SIZE, write_png
import make_monsters

COLS = 8
BASE = {
    "e": (24, 22, 30), "w": (250, 250, 246), "k": (46, 34, 34), "r": (206, 52, 52), "t": (240, 232, 206),
    "y": (250, 214, 70), "i": (150, 156, 170), "I": (104, 110, 124), "p": (240, 150, 170),
}


def sym(rows):
    assert len(rows) == SIZE and all(len(r) == 8 for r in rows), rows
    return [r + r[::-1] for r in rows]


def whole(rows):
    assert len(rows) == SIZE and all(len(r) == SIZE for r in rows), rows
    return rows


class Icon:
    def __init__(self, rows, pal, outline=(34, 28, 34)):
        self.rows, self.pal, self.outline = rows, dict(BASE, **pal), outline

    def canvas(self):
        c = Canvas()
        for y, row in enumerate(self.rows):
            for x, ch in enumerate(row):
                if ch != ".":
                    c.put(x, y, ch)
        c.outline()
        return c

    def pixels(self):
        c = self.canvas()
        out = [[(0, 0, 0, 0)] * SIZE for _ in range(SIZE)]
        for y in range(SIZE):
            for x in range(SIZE):
                ch = c.px[y][x]
                if ch == "O":
                    out[y][x] = self.outline + (255,)
                elif ch is not None:
                    out[y][x] = self.pal[ch] + (255,)
        return out


class Borrowed:
    """The first frame of one of the camp's monsters (make_monsters.py)."""

    def __init__(self, draw):
        self.draw = draw

    def pixels(self):
        c = self.draw(0)
        return [[(make_monsters.PAL[ch] + (255,)) if ch is not None else (0, 0, 0, 0) for ch in row] for row in c.px]


GREY = {"a": (150, 152, 160), "A": (104, 106, 118), "h": (226, 224, 216)}
ICONS = {}

# --- the camp's own monsters ---------------------------------------------------------------------------------------
ICONS["slime"] = Borrowed(make_monsters.slime)
ICONS["giant_rat"] = Borrowed(make_monsters.rat)
ICONS["bat"] = Borrowed(make_monsters.bat)
ICONS["frog"] = Borrowed(make_monsters.frog)

# --- beasts ------------------------------------------------------------------------------------------------------
ICONS["big_slime"] = Icon(sym([
    "........",
    "........",
    ".....aaa",
    "...aaaaa",
    "..ahhaaa",
    ".ahhaaaa",
    ".aaaaaaa",
    "aaawwaaa",
    "aaaewaaa",
    "aaaeeaaa",
    "aaaaaaam",
    "aaaaaamm",
    "AaaaaaaA",
    "AAAaaaAA",
    ".AAAAAAA",
    "........",
]), {"a": (96, 196, 110), "A": (54, 140, 80), "h": (196, 244, 200), "m": (30, 90, 60)})

ICONS["wolf"] = Icon(sym([
    "........",
    "..a.....",
    "..aa....",
    "..aAa...",
    "..aaaaaa",
    ".aaaaaaa",
    ".aawwaaa",
    ".aaewaaa",
    ".aaaaahh",
    "..aaahhh",
    "..aaahhk",
    "...aahhh",
    "....ahhr",
    ".....hhh",
    "........",
    "........",
]), GREY)

ICONS["alpha_wolf"] = Icon(sym([
    ".m......",
    ".ma.....",
    ".maa....",
    ".maAa...",
    "mmaaaaaa",
    "maaaaaaa",
    "maayyaaa",
    "maaeyaaa",
    "mmaaaahh",
    "mmmaahhh",
    ".mmaahhk",
    ".mmmahhh",
    "..mmahhr",
    "...mmhhh",
    "....mm..",
    "........",
]), {"a": (120, 130, 150), "A": (84, 92, 110), "h": (236, 236, 240), "m": (206, 214, 230)})

ICONS["bear"] = Icon(sym([
    "........",
    ".AA.....",
    ".AhA....",
    ".AAaaaaa",
    "..aaaaaa",
    ".aaaaaaa",
    ".aawaaaa",
    ".aaeaaaa",
    ".aaaaahh",
    ".aaaahhk",
    "..aaahhh",
    "..aaaahr",
    "...aaaaa",
    "....aaaa",
    "........",
    "........",
]), {"a": (126, 82, 46), "A": (86, 54, 30), "h": (206, 164, 116)})

ICONS["boar"] = Icon(sym([
    "........",
    "..A.....",
    "..aA....",
    "..aaaaaa",
    ".aaaaaaa",
    ".aawaaaa",
    ".aaeaaaa",
    ".aaaannn",
    "..aannnk",
    "..tannnn",
    "..ttaaaa",
    "...aaaaa",
    "....aaaa",
    "........",
    "........",
    "........",
]), {"a": (132, 94, 72), "A": (94, 64, 48), "n": (226, 150, 150)})

ICONS["rat_king"] = Icon(sym([
    "........",
    "...y.y.y",
    "...yyyyy",
    "...yryyy",
    ".f.aaaaa",
    ".ffaaaaa",
    ".faawaaa",
    "..aaeaaa",
    "..aaaaaa",
    "...aaass",
    "...aassk",
    "....asst",
    ".....sss",
    "........",
    "........",
    "........",
]), {"a": (110, 96, 90), "f": (232, 150, 164), "s": (196, 178, 164)})

ICONS["giant_spider"] = Icon(sym([
    "........",
    "........",
    ".l......",
    "..l..aaa",
    "l..laaaa",
    ".l..aaaa",
    "..llaaaa",
    "l...arar",
    ".lllaaaa",
    "....aaaa",
    ".llaaaaa",
    "l..aAAaa",
    "..l.aAAa",
    ".l...aaa",
    "........",
    "........",
]), {"a": (60, 50, 70), "A": (110, 40, 60), "l": (40, 34, 46)})

ICONS["spider_queen"] = Icon(sym([
    "....y.y.",
    "....yyyy",
    ".l...aaa",
    "..l.aaaa",
    "l..laaaa",
    ".l..arar",
    "..llaaaa",
    "l...aaaa",
    ".lllaaaa",
    "....aAAa",
    ".llaaArA",
    "l..aaAAa",
    "..l.aaaa",
    ".l...aaa",
    "........",
    "........",
]), {"a": (90, 50, 110), "A": (200, 60, 80), "l": (60, 34, 70)})

ICONS["killer_bee"] = Icon(whole([
    "................",
    "....ww....ww....",
    "...wwww..wwww...",
    "...wwwwwwwwww...",
    "....wwwaawww....",
    ".....aaaaaa.....",
    "....aewaawea....",
    "....aaaaaaaa....",
    ".....ykkkky.....",
    "....yyyyyyyy....",
    "....kkkkkkkk....",
    ".....yyyyyy.....",
    "......kkkk......",
    ".......kk.......",
    ".......k........",
    "................",
]), {"a": (60, 50, 40), "y": (248, 200, 50), "w": (220, 236, 250)})

ICONS["queen_bee"] = Icon(whole([
    "......y.y.......",
    ".ww...yyy...ww..",
    "wwww..ryr..wwww.",
    "wwwwwaaaaawwwww.",
    ".wwwaaaaaaawww..",
    "....aewaaweaa...",
    "....aaaaaaaa....",
    "....ykkkkkky....",
    "...yyyyyyyyyy...",
    "...kkkkkkkkkk...",
    "...yyyyyyyyyy...",
    "....kkkkkkkk....",
    ".....yyyyyy.....",
    "......kkkk......",
    ".......kk.......",
    "................",
]), {"a": (70, 56, 40), "y": (248, 196, 40), "w": (220, 236, 250)})

ICONS["giant_crab"] = Icon(sym([
    "........",
    ".aa.....",
    "aa.a....",
    "aa.a....",
    ".aaa....",
    "..a..w..",
    "..a..e..",
    "..aaaaaa",
    ".aaaaaaa",
    "aaahaaaa",
    "aahhaaaa",
    ".aaaaaaa",
    "..A.AAAA",
    ".A..A...",
    "........",
    "........",
]), {"a": (220, 96, 60), "A": (160, 60, 40), "h": (250, 170, 130)})

ICONS["water_snake"] = Icon(whole([
    "................",
    "........aaaa....",
    ".......aaaaaa...",
    ".......awaaaa...",
    ".......aeaaaar..",
    "........aaaa.r..",
    ".........aa.....",
    "....aaaaaaa.....",
    "...aahhhhhaa....",
    "..aahaaaaaaaa...",
    "..aaaaaaaaaaaa..",
    "...aahhhhhhhaa..",
    "....aaaaaaaaa...",
    "................",
    "................",
    "................",
]), {"a": (58, 154, 138), "h": (150, 220, 190)})

ICONS["kappa"] = Icon(sym([
    "........",
    "....cccc",
    "...cCCCC",
    "..aaaaaa",
    ".aaaaaaa",
    ".aawwaaa",
    ".aaewaaa",
    ".aaaaayy",
    "..aaaayy",
    "..aaaaaa",
    ".sssaaaa",
    "ssSssaaa",
    "sSsSsaaa",
    ".ssssaaa",
    "...aa.aa",
    "........",
]), {"a": (96, 170, 90), "c": (200, 230, 240), "C": (130, 190, 210), "s": (90, 120, 70), "S": (60, 84, 50), "y": (240, 200, 80)})

ICONS["naiad"] = Icon(sym([
    "........",
    "....hhhh",
    "...hhhhh",
    "..hhssss",
    "..hsssss",
    ".hhswsss",
    ".hhsesss",
    ".hhsssps",
    ".hh.ssss",
    ".h..dddd",
    ".h.ddddd",
    "...dddDd",
    "..ddddDd",
    "..dddDdd",
    ".ddddddd",
    "........",
]), {"h": (90, 170, 240), "s": (200, 236, 250), "d": (60, 130, 210), "D": (130, 200, 250)})

ICONS["mushroom_folk"] = Icon(sym([
    "........",
    "....aaaa",
    "..aaaaaa",
    ".aawaaaa",
    ".awwaaaw",
    "aaaaaaaw",
    "aAAAAAAA",
    "...sssss",
    "...swsss",
    "...sesss",
    "...sssss",
    "....ssss",
    "....s..s",
    "...ss..s",
    "........",
    "........",
]), {"a": (214, 84, 70), "A": (160, 56, 50), "s": (240, 226, 196)})

ICONS["spore_mother"] = Icon(sym([
    ".g......",
    "...aaaaa",
    ".aaaaaaa",
    "aawaaaaa",
    "awwaaawa",
    "aaaaaawa",
    "AAAAAAAA",
    ".g.sssss",
    "...swsss",
    "...sesss",
    "..ssssss",
    "..sssggs",
    "..ssssss",
    "...ss..s",
    "..sss..s",
    "........",
]), {"a": (170, 110, 190), "A": (120, 70, 140), "s": (236, 222, 196), "g": (176, 240, 110)})

ICONS["treant"] = Icon(sym([
    "..l.l...",
    ".lll.l..",
    "llllll.l",
    "lLllllll",
    "..llllll",
    "...aaaaa",
    "..aaaaaa",
    "..aakaaa",
    "..aaykaa",
    "..aaaaaa",
    "..aakkkk",
    "..aaaaaa",
    "..aaaaaa",
    ".aaa.aaa",
    "aa...aaa",
    "........",
]), {"l": (70, 150, 60), "L": (40, 100, 40), "a": (120, 84, 50), "y": (240, 220, 90)})

# --- people --------------------------------------------------------------------------------------------------------
SKIN = {"s": (238, 196, 160), "S": (206, 160, 124)}

ICONS["barbarian"] = Icon(sym([
    "........",
    ".t......",
    ".tt.....",
    "..tiiiii",
    "..iiiiii",
    "..ssssss",
    "..sweess",
    "..srssss",
    "..bbssss",
    "..bbbbbb",
    ".ffbbbbb",
    "fffffbbb",
    "ffffffss",
    ".fffffss",
    "..ffffff",
    "........",
]), dict(SKIN, b=(170, 90, 40), f=(150, 120, 90)))

ICONS["barbarian_archer"] = Icon(whole([
    "................",
    "......bbbb......",
    ".....bbbbbb...w.",
    ".....ssssss..w..",
    ".....swsssw.w...",
    ".....sessse.k...",
    ".....ssrrss.k...",
    "......ssss..k...",
    "....ffffffffk...",
    "...ffffffffsk...",
    "...ff.ffff..k...",
    "...s..ffff...w..",
    "......ffff....w.",
    "......f..f......",
    ".....ff..ff.....",
    "................",
]), dict(SKIN, b=(170, 90, 40), f=(150, 120, 90)))

ICONS["shaman"] = Icon(sym([
    ".g.r....",
    ".gyry...",
    "..gyyyyy",
    "...bbbbb",
    "...sssss",
    "...swsss",
    "...sesss",
    "..rsssss",
    "..bbsssr",
    ".bbbbbbb",
    ".bbbbbbb",
    "..bbbcbb",
    "..bbbbbb",
    "..bbbbbb",
    "...bb.bb",
    "........",
]), dict(SKIN, b=(120, 84, 60), g=(80, 180, 150), c=(60, 200, 170)))

ICONS["guard"] = Icon(sym([
    "........",
    "....iiii",
    "...iiiii",
    "..IiiiII",
    "..IIiIII",
    "..Issssi",
    "..Isweis",
    "...sssss",
    "...ssrss",
    "..dddddd",
    ".ddddyyy",
    ".ddddyyy",
    ".ddddddd",
    ".ss.dddd",
    "....dd.d",
    "........",
]), dict(SKIN, d=(60, 90, 160)))

ICONS["crossbow"] = Icon(whole([
    "................",
    "......iiii......",
    ".....iiiiii.....",
    ".....IssssI.....",
    ".....swsswe.....",
    ".....ssssss.....",
    "......ssss......",
    "....dddddddd....",
    "...ddwwwwwwwk...",
    "...dd..kk..dk...",
    "...s..dddd..w...",
    "......dddd......",
    "......dddd......",
    "......d..d......",
    ".....dd..dd.....",
    "................",
]), dict(SKIN, d=(60, 90, 160), w=(150, 110, 70)))

ICONS["captain"] = Icon(sym([
    "......rr",
    ".....rrr",
    "....iiri",
    "...iiiii",
    "..IiiiII",
    "..Issssi",
    "..Isweis",
    "...sssss",
    "...ssrss",
    "..dddddd",
    ".yydddyy",
    ".yddddyd",
    ".ddddddd",
    ".ss.dddd",
    "....dd.d",
    "........",
]), dict(SKIN, d=(160, 40, 50), y=(236, 190, 60)))

ICONS["bandit"] = Icon(sym([
    "........",
    "...hhhhh",
    "..hhhhhh",
    ".hhhhhhh",
    ".hhsssss",
    ".hkkkkkk",
    ".hkwekkk",
    ".hhsssss",
    "..hhssss",
    "..hhhhhh",
    ".hhhhhhh",
    ".hhhhbbb",
    ".sshhhhh",
    "...hhhhh",
    "...hh.hh",
    "........",
]), dict(SKIN, h=(80, 70, 70), b=(140, 100, 60)))

ICONS["knife_thrower"] = Icon(whole([
    "................",
    ".....hhhhhh.....",
    "....hhhhhhhh....",
    "...hhssssssh....",
    "...hkkkkkkkh....",
    "...hkwekkwek..i.",
    "...hhssssssh.ii.",
    "....hhsssshh.i..",
    "...hhhhhhhhhhk..",
    "..hhhhhhhhhhs...",
    "..s.hhhhhhh.....",
    ".ii..hhhhhh.....",
    "iii..hh..hh.....",
    ".i..hhh..hhh....",
    "................",
    "................",
]), dict(SKIN, h=(70, 80, 90)))

ICONS["bandit_boss"] = Icon(sym([
    "..hhhhhh",
    ".hhhhhhh",
    "hhhhhhhh",
    "...kkkkk",
    "..ssssss",
    "..kwekss",
    "..kkkkss",
    "..ssssbs",
    "..bbbbbb",
    ".rrrrrrr",
    "rrrrrrrr",
    "rrrryyyy",
    "rrrrrrrr",
    "ssrrrrrr",
    "..rr..rr",
    "........",
]), dict(SKIN, h=(60, 44, 40), b=(90, 60, 40), r=(120, 40, 50)))

# --- the dark --------------------------------------------------------------------------------------------------------
BONE = {"b": (236, 230, 212), "B": (190, 184, 166)}

ICONS["skeleton"] = Icon(sym([
    "........",
    "....bbbb",
    "...bbbbb",
    "..bbbbbb",
    "..bkkbbb",
    "..bkrbbb",
    "..bbbbbk",
    "...bbbbb",
    "....bkbk",
    "...b.bbb",
    "..b..bkb",
    "..b..bbb",
    ".....bkb",
    "....b..b",
    "...bb..b",
    "........",
]), BONE)

ICONS["bone_knight"] = Icon(sym([
    "....iiii",
    "...iiiii",
    "..iiiiii",
    "..IkkIIk",
    "..ibbbbb",
    "..bkrbbb",
    "..bbbbbk",
    "...bbbbb",
    "..iiiiii",
    ".iIiiiii",
    ".iiiipIi",
    ".iIiiiii",
    "..iiiiii",
    "..ii..ii",
    ".iii..ii",
    "........",
]), dict(BONE, i=(90, 80, 110), I=(60, 50, 80), p=(160, 60, 200)))

ICONS["wraith"] = Icon(sym([
    "........",
    "....aaaa",
    "...aaaaa",
    "..aaaaaa",
    "..akkaaa",
    "..akcaaa",
    "..aaaaaa",
    ".aaaaaak",
    ".aaaaaaa",
    "aaaaaaaa",
    "aa.aaaaa",
    "a..aaaaa",
    "...aa.aa",
    "...a..aa",
    "......a.",
    "........",
]), {"a": (170, 220, 230), "k": (40, 50, 70), "c": (120, 250, 230)}, outline=(60, 90, 110))

ICONS["gargoyle"] = Icon(sym([
    "........",
    "a.......",
    "aa...a..",
    "aaa..aa.",
    "aaaa.aaa",
    "aaaaaaaa",
    ".aaaaaaa",
    "..aayaaa",
    "..aaaaaa",
    "...aaatt",
    "..aaaaaa",
    "..aaAaaa",
    "..aaAAaa",
    "...aa.aa",
    "..aaa.aa",
    "........",
]), {"a": (110, 110, 124), "A": (80, 80, 94), "y": (250, 120, 60)})

ICONS["vampire_bat"] = Icon(whole([
    "................",
    "..a..........a..",
    ".aa..a....a..aa.",
    "aaaa.aaaaaa.aaaa",
    "aaaaaaaaaaaaaaaa",
    "aaaaaarkkraaaaaa",
    "aa.aaaaaaaaaa.aa",
    "a...aaawwaaa...a",
    ".....aaaaaa.....",
    "......aaaa......",
    ".......aa.......",
    "................",
    "................",
    "................",
    "................",
    "................",
]), {"a": (110, 40, 60), "r": (250, 60, 60)})

ICONS["drake"] = Icon(whole([
    "................",
    "..........aa....",
    ".........aaaa...",
    "..w......aeaaa..",
    ".ww.....aaaaaar.",
    "www....aaaa.....",
    "wwww..aaaa......",
    ".wwwaaaaa.......",
    "..waaaaaaa......",
    "...aahhhaaa.....",
    "...ahhhhaaaa....",
    "....aaaa..aaa...",
    "....a..a....aa..",
    "...aa.aa.....a..",
    "................",
    "................",
]), {"a": (190, 70, 50), "h": (240, 180, 110), "w": (230, 120, 90)})

# --- the great ones ------------------------------------------------------------------------------------------------
ICONS["troll"] = Icon(sym([
    "........",
    "....aaaa",
    "...aaaaa",
    ".a.aaaaa",
    ".aaaAAAA",
    "..awwaaa",
    "..aewaaa",
    "..aaaaaa",
    "..atakkk",
    "..aaaaaa",
    ".aaaaaaa",
    "aaaaaaaa",
    "aaafffff",
    "aa.fffff",
    "...aa.aa",
    "........",
]), {"a": (96, 140, 80), "A": (70, 104, 60), "f": (130, 100, 70)})

ICONS["stone_golem"] = Icon(sym([
    "........",
    "...aaaaa",
    "...aAaaa",
    "...aaaaa",
    "...acccc",
    "...aaaaa",
    ".aa.aaaa",
    "aaAaaaaa",
    "aaaaaccc",
    "aAa.aaca",
    "aaa.aaaa",
    ".a..aAaa",
    "....aaaa",
    "...aaa.a",
    "..aaaa.a",
    "........",
]), {"a": (130, 130, 140), "A": (96, 96, 106), "c": (64, 224, 240)})

ICONS["ancient_dragon"] = Icon(whole([
    "..r.........r...",
    "..rr..aaaa.rr...",
    "...raaaaaaar....",
    "....aayaayaa....",
    "....aaeaaeaa..w.",
    "w...aaaaaaaa.ww.",
    "ww..aattttaawww.",
    "www..aaaaaa.wwww",
    "wwwwaaaaaaaawww.",
    ".wwaahhhhhhaaw..",
    "..aaahhhhhhaaa..",
    "..aa.hhhhhh.aa..",
    ".....aaaaaa.....",
    "....aa....aa....",
    "...aaa....aaa...",
    "................",
]), {"a": (180, 40, 36), "h": (240, 170, 90), "r": (240, 220, 180), "w": (230, 110, 80), "y": (250, 230, 60)})

ICONS["lich_king"] = Icon(sym([
    "..y.y.y.",
    "..yyyyyy",
    "..yryyyy",
    "...bbbbb",
    "..bbbbbb",
    "..bkcbbb",
    "..bbbbbk",
    "...bbkbk",
    "..pppppp",
    ".pppppPp",
    "ppPppppp",
    "pPpppcpp",
    "ppppppPp",
    "pppppppp",
    ".pp.pppp",
    "........",
]), dict(BONE, p=(80, 50, 120), P=(120, 80, 170), c=(170, 120, 255)))

ICONS["hill_giant"] = Icon(sym([
    "....hhhh",
    "...hhhhh",
    "..hsssss",
    "..ssssss",
    "..swesss",
    "..ssssss",
    "..sskkkk",
    "..hhhhhh",
    ".hhhhhhh",
    "sffffffh",
    "sfffffff",
    "sfffbbbb",
    "ssffffff",
    "..ffffff",
    "..ss..ss",
    "........",
]), dict(SKIN, h=(150, 110, 70), f=(120, 100, 70), b=(80, 60, 40)))

ICONS["hydra"] = Icon(whole([
    "..a.....a.....a.",
    ".aea...aea...aea",
    ".aaa...aaa...aaa",
    "..a.....a.....a.",
    "..a.....a....a..",
    "...a....a...a...",
    "....a...a..a....",
    ".....aaaaaa.....",
    "....aahhhhaa....",
    "...aahhhhhhaa...",
    "...aaaaaaaaaa...",
    "..aaaaaaaaaaaa..",
    "..aa.aa..aa.aa..",
    "................",
    "................",
    "................",
]), {"a": (70, 150, 90), "h": (160, 220, 150), "e": (250, 220, 60)})

ICONS["minotaur"] = Icon(sym([
    "t.......",
    "tt......",
    ".tt.aaaa",
    "..ttaaaa",
    "...aaaaa",
    "..aawaaa",
    "..aaeaaa",
    "..aaaahh",
    "...aahhk",
    "...aahyh",
    ".aaaaaaa",
    "aaaaaaaa",
    "aaaffffa",
    "aa.fffff",
    "...aa.aa",
    "........",
]), {"a": (120, 76, 50), "h": (180, 130, 100), "f": (90, 60, 40), "y": (236, 190, 60)})

ICONS["enemy_town"] = Icon(sym([
    "........",
    "...r....",
    "...rr...",
    "...i....",
    "..iii...",
    "..iiiiii",
    "..iIiiii",
    "..iiiiii",
    "iiiiiiii",
    "iIiiiIii",
    "iiiiiiii",
    "iiiikkkk",
    "iiiikkkk",
    "iiiikkkk",
    "........",
    "........",
]), {})


# --- the beginners' crowd (2026-09-28) -------------------------------------------------------------------------------
ICONS["rabbit"] = Icon(sym([
    "........",
    "...aa...",
    "...aha..",
    "...aha..",
    "...aha..",
    "...aaaaa",
    "..aaaaaa",
    "..awaaaa",
    "..aeaaaa",
    "..aaaapp",
    "...aaaak",
    "...aaaaa",
    "..aaaaaa",
    "..aa.aaa",
    "........",
    "........",
]), {"a": (236, 228, 220), "h": (240, 170, 180), "p": (240, 170, 180)})

ICONS["snail"] = Icon(whole([
    "................",
    "................",
    "................",
    ".......ssss.....",
    ".....sshhhss....",
    "....sshsSSshs...",
    "....shsSssShs...",
    "....shsSsShhs...",
    "..a.shssSShs....",
    ".aea.shhhhs.....",
    ".aaa..ssss......",
    ".aaaaaaaaaaaaa..",
    "..aaaaaaaaaaaaa.",
    "................",
    "................",
    "................",
]), {"s": (200, 150, 100), "S": (150, 100, 60), "h": (236, 200, 150), "a": (170, 200, 120)})

ICONS["caterpillar"] = Icon(whole([
    "................",
    "................",
    "................",
    "................",
    "..y..y..........",
    "..aaaa..........",
    ".aaaaaa.........",
    ".awaawa.........",
    ".aeaaea..bb..bb.",
    ".aaaaaabbbbbbbbb",
    "..aaaabbhbbhbbhb",
    "...k.kbbbbbbbbbb",
    "......k.k.k.k.k.",
    "................",
    "................",
    "................",
]), {"a": (120, 190, 70), "b": (150, 210, 80), "h": (220, 240, 150)})

ICONS["beetle"] = Icon(sym([
    "........",
    "......hh",
    ".......h",
    "....k..h",
    "...k.aaa",
    ".....aaa",
    "..k.awaa",
    "...kbbbb",
    "..kbbhbb",
    "...bbhbb",
    "..kbbbbb",
    "...bbbbb",
    "..k.bbbb",
    ".....bbb",
    "........",
    "........",
]), {"a": (40, 44, 60), "b": (58, 90, 140), "h": (110, 150, 200)})

ICONS["crow"] = Icon(whole([
    "................",
    "................",
    ".......aaaa.....",
    "......aaaaaa....",
    "......awaaaayy..",
    "......aeaaaayyy.",
    ".....aaaaaaa....",
    "....aaaaaaaa....",
    "...aaaAaaaaa....",
    "..aaAAaaaaaa....",
    ".aaAAaaaaaa.....",
    "aaa..aaaaa......",
    "......y..y......",
    ".....yy.yy......",
    "................",
    "................",
]), {"a": (44, 44, 60), "A": (80, 80, 110), "y": (220, 180, 60)})

ICONS["pigeon"] = Icon(whole([
    "................",
    "................",
    "................",
    ".......aaa......",
    "......aaaaa.....",
    "......awaaayy...",
    "......aeaaa.....",
    ".......ggg......",
    "......gpgggaa...",
    ".....aaaaaaaaa..",
    ".....aaaaaaaAAa.",
    "......aaaaaaAAA.",
    ".......y..y.....",
    "......yy.yy.....",
    "................",
    "................",
]), {"a": (170, 172, 184), "A": (110, 112, 130), "g": (90, 160, 140), "p": (170, 110, 160), "y": (230, 120, 110)})

ICONS["squirrel"] = Icon(whole([
    "................",
    "..........tt....",
    ".........tttt...",
    "..a.a...tthtt...",
    "..aaaa..tthtt...",
    ".aawaa..tthtt...",
    ".aaeaa..ttttt...",
    ".aaaah...ttt....",
    "..kahh..ttt.....",
    "..aaahhaatt.....",
    "..aaahhaat......",
    "..aaaaaaa.......",
    "..y.aa.aa.......",
    "................",
    "................",
    "................",
]), {"a": (190, 110, 60), "h": (240, 210, 170), "t": (200, 120, 70), "y": (160, 100, 50)})

ICONS["hedgehog"] = Icon(whole([
    "................",
    "................",
    "................",
    "......s.s.s.....",
    ".....s.sss.s....",
    "....ssSsSsSss...",
    "...sSsSsSsSsSs..",
    "..fffSsSsSsSss..",
    ".fwfffsSsSsSss..",
    ".fefffSsSsSsss..",
    "kffffSsSsSsss...",
    ".fffffffffff....",
    "...f.f...f.f....",
    "................",
    "................",
    "................",
]), {"s": (130, 110, 90), "S": (90, 72, 60), "f": (230, 200, 160)})

ICONS["goose"] = Icon(whole([
    "................",
    "........aaa.....",
    ".......aaaa.....",
    ".......awaayy...",
    ".......aeaayyy..",
    "........aa......",
    "........aa......",
    ".......aaa......",
    "..aaaaaaaa......",
    ".aaAAaaaaaa.....",
    "aaaaAAaaaaa.....",
    ".aaaaaaaaa......",
    "...yy..yy.......",
    "...y...y........",
    "................",
    "................",
]), {"a": (248, 248, 246), "A": (200, 204, 210), "y": (240, 160, 50)})

ICONS["fox"] = Icon(sym([
    "........",
    "..a.....",
    "..aa....",
    "..ahaaaa",
    "..aaaaaa",
    ".aaaaaaa",
    ".aawwaaa",
    ".aaewaaa",
    "..aaahhh",
    "..aahhhh",
    "...ahhhk",
    "....hhhh",
    ".....hhh",
    "........",
    "........",
    "........",
]), {"a": (232, 128, 58), "h": (250, 240, 230)})

# --- by the roads ------------------------------------------------------------------------------------------------
ICONS["robber"] = Icon(sym([
    "........",
    "....rrrr",
    "...rrrrr",
    "..rrssss",
    "..rsssss",
    "..kkkkkk",
    "..kwekkk",
    "..ssssss",
    "...sssss",
    "..bbbbbb",
    ".bbbbbbb",
    ".bbbbyyy",
    ".ssbbbbb",
    "...bbbbb",
    "...bb.bb",
    "........",
]), dict(SKIN, r=(170, 50, 50), b=(110, 90, 70)))

ORC = {"g": (110, 150, 80), "G": (80, 112, 60), "f": (100, 80, 60), "i": (130, 134, 140)}
ICONS["orc_grunt"] = Icon(sym([
    "........",
    "...iiiii",
    "..iiiiii",
    "..gggggg",
    ".ggggggg",
    ".ggyeggg",
    ".gggGggg",
    ".gtgkkkk",
    "..gggggg",
    ".ffffiff",
    "ffffffff",
    "ggffffff",
    "ggffffff",
    "..ffffff",
    "..gg..gg",
    "........",
]), ORC)

ICONS["orc_archer"] = Icon(whole([
    "................",
    "......ffff......",
    ".....ffffff...w.",
    ".....gggggg..w..",
    "....ggyeggeyw...",
    "....ggggggggk...",
    "....gtgkkkgtk...",
    ".....gggggg.k...",
    "...ffffffffk....",
    "..ffffffffgk....",
    "..ff.ffff...w...",
    "..g..ffff....w..",
    "......ffff......",
    "......gg.gg.....",
    ".....ggg.ggg....",
    "................",
]), ORC)

ICONS["orc_chief"] = Icon(sym([
    "r.......",
    "rr..iiii",
    ".r.iiiii",
    "..iIiiii",
    ".ggggggg",
    ".ggyeggg",
    ".gggGggg",
    ".gtgkkkk",
    ".ttggggg",
    "iiiiiiii",
    "iIiirrrr",
    "iiiirrrr",
    "ggiiiiii",
    "gg.iiiii",
    "...gg.gg",
    "........",
]), dict(ORC, r=(170, 40, 40), I=(96, 100, 110)))


def sheet():
    ids = list(ICONS)
    rows = (len(ids) + COLS - 1) // COLS
    img = [[(0, 0, 0, 0)] * (COLS * SIZE) for _ in range(rows * SIZE)]
    for n, key in enumerate(ids):
        px = ICONS[key].pixels()
        ox, oy = (n % COLS) * SIZE, (n // COLS) * SIZE
        for y in range(SIZE):
            for x in range(SIZE):
                img[oy + y][ox + x] = px[y][x]
    return img, {key: n for n, key in enumerate(ids)}


def preview(path, img, zoom=8):
    h, w = len(img), len(img[0])
    out = [[(214, 218, 200, 255)] * (w * zoom) for _ in range(h * zoom)]
    for y in range(h):
        for x in range(w):
            px = img[y][x]
            if px[3]:
                for dy in range(zoom):
                    for dx in range(zoom):
                        out[y * zoom + dy][x * zoom + dx] = px
    write_png(path, out)


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources", "World")
    os.makedirs(root, exist_ok=True)
    img, index = sheet()
    write_png(os.path.join(root, "foes.png"), img)
    with open(os.path.join(root, "foes.json"), "w", encoding="utf-8") as f:
        json.dump({"size": SIZE, "cols": COLS, "icons": index}, f, ensure_ascii=False, indent=1)
        f.write("\n")
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1], img)
    print("wrote", os.path.normpath(root), len(index), "icons")


if __name__ == "__main__":
    main()
