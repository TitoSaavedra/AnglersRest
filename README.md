# Angler's Rest

A small fishing addon for **WoW: Forever** (`_forever_`), with a fishing audio mode on the minimap icon
and a panel skinned like [FlareUI](https://github.com/malkkav/FlareUI).

- **Left click the minimap icon** — reads your own sound settings, keeps a full copy, and switches to
  fishing mode: general, effects and music at 100 %, ambience and dialogue silenced, and your fishing
  pole equipped on the main hand.
- **Left click again** — every value comes back exactly as it was, and the weapon you were holding
  returns to your hand.
- **Double right-click the world** — casts the line.
- **Right click the icon** — opens the panel.

While the mode is **off** the addon does nothing at all: no fishing, no messages, no sound or weapon
changes.

## The panel

FlareUI's bronze edge (`Media/Borders/FlareUI-Thin.tga`, 8 px), the game's rock texture in warm dark
bronze, WoW-yellow titles, bronze-gold labels, Friz Quadrata with a hard shadow, atlas checkboxes and a
slider drawn in the addon.

- One line per sound channel: General, Effects, Music, Ambience, Dialogue and the channel switches this
  client actually has. Each has a value (0–100 %, steps of 5) and a box that turns the channel off.
- **The pole**: put it on automatically and hand back what was in your hand; `Equip pole now` and
  `Give my weapon back` buttons.
- Sound and weapon back when the line comes in, double right-click to cast, icon on the minimap.
- Draggable; `Shift` + mouse wheel over the window changes its scale. It never grows past the screen.

## Commands

| Command | Action |
|---|---|
| `/ar` or `/anglersrest` | Toggle fishing mode |
| `/ar on` · `/ar off` | Switch explicitly |
| `/ar cast` | Cast the line |
| `/ar pole` | Equip the pole now |
| `/ar ui` | Open the panel |
| `/ar reset` | Centre the panel |

## Install

Copy this folder into `World of Warcraft\_forever_\Interface\AddOns\AnglersRest` and reload the game.

No libraries are needed. Only the border bitmap comes from FlareUI, under its MIT licence
(`LICENSE-FlareUI.txt`).

## Notes

- The audio snapshot is kept in saved variables: if the game closes mid-session, the sound is restored
  at logout and again at the next login.
- In combat nothing is touched; the switch waits for the fight to end.
- The catch restores your sound (and offers your weapon back) before the next cast.
