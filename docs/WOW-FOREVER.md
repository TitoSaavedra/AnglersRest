# WoW: Forever — lo que este cliente tiene de verdad

Guía sacada de la instalación real (`G:\BattleNet\World of Warcraft\_forever_`), no de Retail.
Sirve como punto de partida para cualquier addon de Forever.

- Cliente: `_forever_` (producto `wowf`), `Interface: 16001`
- Fecha de la revisión: 15/11/2026
- Fuente: `Config.wtf`, `Logs\General.log`, `Logs\FrameXML.log`, y el código de FlareUI 6.8.1 instalado

---

## 1. Antes de escribir código

Comprobar siempre, en este orden:

1. **La carpeta correcta de juego.** En este PC conviven `_retail_` y `_forever_`. El addon va en
   `_forever_\Interface\AddOns\<Nombre>`.
2. **Qué APIs usan los addons que ya funcionan** (FlareUI es la mejor referencia: es moderno, MIT y
   está instalado).
3. **Los logs**, después de probar:
   - `_forever_\Logs\General.log` → errores de Lua (`[E][Lua]`).
   - `_forever_\Logs\FrameXML.log` → errores al cargar archivos del `.toc`.
4. **`Config.wtf`** para CVars: si no está ahí o no aparece en los logs, no existe.

---

## 2. Audio

CVars de sonido reales en `Config.wtf`:

```
Sound_MasterVolume          (0..1)
Sound_SFXVolume             (0..1)
Sound_MusicVolume           (0..1)
Sound_AmbienceVolume        (0..1)
Sound_DialogVolume          (0..1)
Sound_EnableDialog          (0/1)
Sound_EnableSoundWhenGameIsInBG
Sound_ZoneMusicNoDelay
Sound_NumChannels
```

Aparecen además en los logs (se validan al arrancar, existen):
`Sound_AmbienceHighpassDSPCutoff`, `Sound_AllyPlayerHighpassDSPCutoff`,
`Sound_EnemyPlayerHighpassDSPCutoff`, `Sound_NPCHighpassDSPCutoff`.

**No existen** (no las pongas sin comprobarlas):
`Sound_EnableMusic`, `Sound_EnableAmbience`, `Sound_EnableAllSound`, `Sound_VolumeSFX`.

Notas:
- Leer y escribir con `C_CVar.GetCVar` / `C_CVar.SetCVar`. Los valores vuelven como texto (`"1"`,
  `"0.5"`); convertir con `tonumber` y tolerar que no sea número.
- Un CVar puede devolver un valor "secreto" en clientes nuevos: leerlo está bien, pero no lo uses en
  aritmética sin convertirlo antes.
- Truco conocido: subir `Sound_MusicVolume` de 0 a su valor en un solo paso a veces no suena; baja a 0
  y vuelve a subir unos 0,1 s después.
- La UI del juego (deslizador de sonido) puede no refrescarse aunque el valor haya cambiado.

---

## 3. Hechizos

| Necesidad | API que usa Forever |
|---|---|
| Nombre de un hechizo | `C_Spell.GetSpellName(id)` |
| Datos del hechizo | `C_Spell.GetSpellInfo(id)` |
| ¿Se está lanzando? | `C_Spell.IsCurrentSpell(id)` |
| ¿Se puede usar? | `C_Spell.IsSpellUsable(id)` |
| ¿Lo conoce el jugador? | `C_SpellBook.IsSpellKnown(id, Enum.SpellBookSpellBank.Player)` |
| Libro de hechizos | `C_SpellBook.GetNumSpellBookSkillLines()`, `C_SpellBook.GetSpellBookSkillLineInfo()`, `C_SpellBook.GetSpellBookItemInfo(index, bank)` |
| Buscar un hechizo | `C_SpellBook.FindSpellBookSlotForSpell(id)` |
| Lanzar | `CastSpellByID(id)` (funciona desde un addon) |

Pesca = hechizo **7620**. El canal dura mientras `C_Spell.IsCurrentSpell(7620)` sea verdadero.

---

## 4. Objetos e inventario

| Necesidad | API |
|---|---|
| Datos básicos | `C_Item.GetItemInfoInstant(id)` → devuelve 7 valores; clase en la posición 6 y subclase en la 7 |
| Nombre | `C_Item.GetItemNameByID(id)` / `GetItemInfo(id)` |
| Recuento | `C_Item.GetItemCount(id)` |
| Equipado | `C_Item.IsEquippedItem(id)` |
| Qué llevas en la mano | `GetInventoryItemID("player", INVSLOT_MAINHAND)` y `GetInventoryItemLink("player", INVSLOT_MAINHAND)` |
| Equipar por código | `EquipItemByName(id)` |
| Bolsas | `C_Container.GetContainerNumSlots(bag)`, `C_Container.GetContainerItemID(bag, slot)` |
| Instantes clásicos | `GetContainerNumSlots`, `GetContainerItemID` (también presentes) |

Caña de pescar: `classID == 2` (arma) y `subclassID == 20` (caña). FlareUI lo comprueba exactamente
así con `Enum.ItemClass.Weapon` y `Enum.ItemWeaponSubclass.Fishingpole`.

---

## 5. Frames

- **`CreateFrame` necesita nombre.** Un `CreateFrame("Frame", nil, ...)` falla en este cliente con
  `CreateFrame: frame name is required`. Es la causa de que una ventana aparezca vacía: el error corta
  el archivo a medias. Nombra cada frame (`"MiAddon" .. n`) o pásalo por un helper que lo garantice.
- Nunca uses métodos de plantilla en frames sin plantilla. Ejemplo real: `SetCheckedTexture` solo
  existe en `InterfaceOptionsCheckButtonTemplate`; en un `Button` normal da
  `attempt to call a nil value`.
- No guardes tus datos en campos que puedan chocar con el API del frame: `label`, `value`, `text`,
  `status` pueden ser métodos. Usa nombres propios (`textLabel`, `valueText`, `rows`) o una tabla
  aparte.
- `BackdropTemplate` para bordes con `SetBackdrop`.
- `UIPanelButtonTemplate`, `OptionsSliderTemplate`, `InterfaceOptionsCheckButtonTemplate` existen y
  son lo más rápido; si quieres aspecto propio, dibuja tú la casilla/deslizador.

---

## 6. Eventos que sí funcionan aquí

- `ADDON_LOADED`, `PLAYER_LOGIN`, `PLAYER_LOGOUT`, `PLAYER_ENTERING_WORLD`
- `PLAYER_EQUIPMENT_CHANGED`
- `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` (combate)
- `GLOBAL_MOUSE_DOWN` / `GLOBAL_MOUSE_UP`
- `UNIT_SPELLCAST_CHANNEL_START` / `_STOP` (con `RegisterUnitEvent(..., "player")`)

Para doble clic: cuenta solo clics cortos (pulsar y soltar en ~0,05 s sin mover el cursor) y exige
dos seguidos. Con `GLOBAL_MOUSE_DOWN` el botón llega a veces como número (`2`) y a veces como
`"RightButton"`: comprueba ambos.

---

## 7. Cadenas del juego

Los textos de la interfaz se heredan del cliente usando sus globales, para no traducir a mano:

- Nombres de opciones de sonido: busca las globales `GAME_SOUND_*` / `SOUND_OPTIONS_*` del cliente y
  usa la primera que exista; si no hay ninguna, cae a una tabla propia.
- Verificado: en este cliente esas globales pueden no estar, así que el addon necesita su tabla.

Comparación de resultado en AnglersRest:

| Cliente | Se ve |
|---|---|
| enUS | Sound / Fishing off |
| esMX / esES | Sonido / Pesca: no |
| deDE | Ton / Angeln aus |
| jaJP (sin traducir) | respaldo en inglés |

`GetLocale()` devuelve `esMX` en este PC.

---

## 8. Librerías

- **No instales dependencias externas**: el addon debe funcionar solo.
- Si otro addon trae `LibStub` + `LibDBIcon-1.0` + `LibDataBroker-1.1` (Accountant, GatherLite,
  FlareUI), puedes registrarte ahí; pero siempre ten un botón propio de reserva.

---

## 9. Cosas aprendidas a golpes (checklist antes de entregar)

1. ¿Está en `_forever_` y no en `_retail_`?
2. ¿Todos los `CreateFrame` llevan nombre?
3. ¿Algún método de plantilla usado sin plantilla?
4. ¿Nombres de campo que chocan con el API del frame?
5. ¿CVars de audio verificadas en `Config.wtf`?
6. ¿Probado con `ADDON_LOADED` + `PLAYER_LOGIN` simulados y el panel visible?
7. ¿Revisados `General.log` y `FrameXML.log` tras la primera prueba real?

---

## 10. Archivos de referencia

```
G:\BattleNet\World of Warcraft\_forever_\Interface\AddOns\FlareUI\      (código modelo, MIT)
G:\BattleNet\World of Warcraft\_forever_\WTF\Config.wtf                (CVars reales)
G:\BattleNet\World of Warcraft\_forever_\Logs\General.log              (errores Lua)
G:\BattleNet\World of Warcraft\_forever_\Logs\FrameXML.log             (errores de carga)
G:\BattleNet\World of Warcraft\_forever_\WTF\Account\<cuenta>\SavedVariables\
```
