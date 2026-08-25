# AddonManagement In-Game Verification

This checklist collects every in-game step from `AddonManagementPlan.md` (Tasks 1-7)
into one run, grouped by what's being verified rather than by task. Run top to
bottom in one sitting; a couple of steps note a precondition inline where the
plan set one up earlier.

**Before you start:** three load-time bugs were already found and fixed on this
branch — the settings buttons were missing a mandatory argument, a static popup
declared the wrong `text` field, and the character-roster write ran before realm
data was available. Re-check those areas first (settings buttons, the name-entry
popup, and character roster population on login) since they're the most likely
places for a regression to resurface.

---

## First-run and saved variables

- [ ] On a fresh login (or after `/run XephUISaved.AddonManagementDB = nil` followed by `/reload`), run:
  ```
  /dump XephUISaved.AddonManagementDB
  ```
  Expected: a table with `NextProfileId = 1`, empty `Profiles`, `KnownCharacters` containing exactly one entry keyed `"Name-Realm"` whose value is the player's class file name (e.g. `"MAGE"`), empty `ActiveProfile`.

## Module load integrity

- [ ] Run:
  ```
  /dump type(XephUIMultiSelectDropdownControlMixin)
  ```
  Expected: `"table"`.
- [ ] Run:
  ```
  /run local frame = CreateFrame("Frame", nil, UIParent, "XephUIMultiSelectDropdownControlTemplate") print(frame.Control ~= nil)
  ```
  Expected: prints `true` and produces no Lua error. This confirms the XML template resolved its inheritance and mixin.

## Applying a profile

Precondition: run this before creating any profiles through the settings panel — it manually seeds `Profiles[1]`, which a panel-created profile would otherwise collide with.

- [ ] Run:
  ```
  /run XephUISaved.AddonManagementDB.Profiles[1] = { Id = 1, Name = "Test", Addons = {}, ContentTypes = {}, Characters = {} }
  /run XephUISaved.AddonManagementDB.NextProfileId = 2
  /xephui Nope
  ```
  Expected: `no profile named "Nope". Available:` followed by ` - Test`.
- [ ] Run:
  ```
  /xephui Test
  ```
  Expected: the UI reloads. After the reload, open the game's own AddOns list: every non-Blizzard addon except XephUI is unchecked, XephUI is still checked.
- [ ] Run:
  ```
  /dump XephUISaved.AddonManagementDB.ActiveProfile
  ```
  Expected: one entry mapping the character key to `1`.
- [ ] Re-enable your addons through the game's AddOns list before continuing.

## The settings panel

Precondition: wipe leftover test data first:
```
/run XephUISaved.AddonManagementDB = nil
/reload
```

- [ ] Run:
  ```
  /xephui
  ```
  Expected: the Settings window opens on a category named **XephUI Addon Management** in the AddOns list, showing rows: Profile, New Profile, Rename Profile, Delete Profile, a "Profile Contents" header, Addons, Characters, Content Types.
- [ ] Click **New Profile**, type `Raid`, accept. Expected: the Profile dropdown now reads `Raid`.
- [ ] Open the **Addons** dropdown. Expected: a scrolling checkbox list of your non-Blizzard addons, XephUI absent. Tick three. Expected: the closed dropdown reads `3 / <total>`.
- [ ] Open the **Characters** dropdown. Expected: the current character listed once, in class colour, already ticked.
- [ ] Open the **Content Types** dropdown. Expected: six checkboxes, no stepper arrows either side. Tick `Raid`.
- [ ] Run:
  ```
  /reload
  /dump XephUISaved.AddonManagementDB.Profiles[1]
  ```
  Expected: `Name = "Raid"`, three entries in `Addons`, `ContentTypes = { [4] = true }`, `Characters` holding the current character key.
- [ ] Create a second profile, switch the Profile dropdown between them. Expected: the Addons, Characters, and Content Types rows repaint to match the selected profile without leaving the category.
- [ ] Delete a profile. Expected: it disappears from the Profile dropdown; the remaining profile is unaffected.

## The content-type swap prompt

Precondition: through the settings panel, set up two profiles: `Open World` with Content Types = Open World, and `Raid` with Content Types = Raid. Put the current character in both, and give them different addon sets.

- [ ] Run:
  ```
  /xephui Open World
  ```
  Expected: reload; afterwards `ActiveProfile` points at the Open World profile.
- [ ] Enter any raid instance. Expected: on the loading screen ending, a dialog reading `Content changed to Raid. Switch addon profile and reload?` with a dropdown listing `Raid`, plus Accept and Cancel.
- [ ] Press **Escape**. Expected: the dialog closes and does not return while you stay in the raid.
- [ ] Zone out to the open world, then back into the raid. Expected: the dialog appears again. This confirms the dismissal is scoped to one content-type change.
- [ ] Accept it. Expected: the UI reloads and the raid profile's addon set is active.
- [ ] Add a third profile also flagged Raid, containing the current character. Zone out and back in. Expected: the dialog's dropdown lists both raid profiles.
- [ ] Uncheck the current character from one of those profiles. Zone out and back in. Expected: only the remaining profile is offered. This confirms the soft gate.

## Full regression pass

- [ ] Run:
  ```
  /run XephUISaved.AddonManagementDB = nil
  /reload
  ```
- [ ] Walk the whole flow once: create a profile, pick addons, pick content types, apply it with `/xephui <name>`, zone into matching and non-matching content, confirm the prompt fires and dismisses correctly.

## Cleanup

- [ ] Run:
  ```
  /reload
  ```
  Expected: no Lua errors, and `/xephui` still opens the settings category. (Confirms removing the superseded `AddonSuiteProfileSwapReminder` module didn't break anything.)

## The second-character flow

This needs a relog — do it last.

- [ ] Log out, log in on a second character on any realm, then run:
  ```
  /dump XephUISaved.AddonManagementDB.KnownCharacters
  ```
  Expected: two entries. This confirms lazy roster growth.
- [ ] Still on this second character: nothing should have changed about that character's addons. The settings panel lists every profile. The Characters dropdown now offers the second character, and ticking it makes that profile a swap candidate there.

---

## Final pre-merge checklist

From `AddonManagementPlan.md` Task 7's pre-merge sign-off list (`stylua --check` and the `git grep` sweeps were already run mechanically — see `task-7-report.md`):

- [ ] Profiles survive a reload
- [ ] Applying a profile enables exactly its addon set and nothing else
- [ ] XephUI cannot be disabled by a profile
- [ ] `Blizzard_*` addons are never touched
- [ ] Swap prompt fires only on a content-type change
- [ ] Escape dismisses the prompt and it does not immediately return
- [ ] A second character sees all profiles but joins none until opted in
- [ ] No Lua errors on a clean saved-variables file
