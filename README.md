# Angler's Rest

A small fishing addon for **WoW: Forever** (`_forever_`) with a panel in the
[FlareUI](https://github.com/malkkav/FlareUI) style.

Everything is done with the mouse; there is one command, `/ar`, only for the case where the icon
cannot be clicked.

---

## What it does

### Left click on the minimap icon

1. **Reads your sound settings** and keeps a full copy: general volume, effects, music, ambience,
   dialogue and the channel switches your client has.
2. **Switches to fishing mode**: general, effects and music at 100 %, ambience and dialogue silenced.
3. **Equips your fishing pole** on the main hand, remembering what you were holding.

### Left click again

Puts **every value back exactly** as it was, and returns the weapon to your hand.

While the mode is **off**, the addon does nothing at all: no casting, no messages, no sound or
weapon changes.

### Double right-click on the world

Casts the line. Two short right clicks (nothing else in between); a right click that turns the camera
is never counted.

### Right click on the icon

Opens the panel.

---

## The panel

It opens when the game loads, whether the mode is on or off, and stays where you leave it.

**Sound while fishing** — one line per channel this client has. Each has a value (0–100 %, steps of 5)
and a box on the right that turns that channel off:

| Channel | What it is |
|---|---|
| General | master volume |
| Effects | the splash you listen for |
| Music | music |
| Ambience | ambient sound |
| Dialogue | voice lines |
| Effects on | the effects channel switch |

**The pole** — *Put my fishing pole on, and hand back what was in my hand*, plus two buttons:
*Equip pole now* and *Give my weapon back*.

**Behaviour** — sound and weapon back when the line comes in; double right-click to cast; icon on the
minimap.

The window drags from any empty spot, `Shift` + mouse wheel changes its scale, and it never grows past
the screen. `Centre window` puts it back in the middle.

---

## What comes back on its own

- **The catch**: when the line comes in, your sound returns, and a small window asks whether to put
  your weapon back (so it never grabs your hand mid-fight).
- **Leaving the game**: the sound is restored at logout, and again at the next login if it was left
  mid-session.
- **Combat**: nothing is touched during a fight; the switch waits for it to end.
- **Music**: raised from 0 with the usual WoW fix (drops to 0 and comes back a moment later), so the
  classic "music stays silent" bug does not happen.

---

## Commands

| Command | Action |
|---|---|
| `/ar` | Open or close the panel |

That is all: the mode is switched with the left click on the icon, the way the addon is meant to be
used.

---

## Install

Copy the folder into `World of Warcraft\_forever_\Interface\AddOns\AnglersRest` and start the game.
The icon is the fishing skill's own (`Interface\Icons\Trade_Fishing`).

No libraries are needed. The border bitmap is FlareUI's, under its MIT licence
(`LICENSE-FlareUI.txt`); the rest of the art is the game's own.
