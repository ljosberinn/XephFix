Collection of former utiltiy WeakAuras or similar.

## How To Disable A Module For Yourself

- edit the `XephFix.toc` file and remove the file name you want to disable, then reload, that's all

## Modules

The following modules are enabled for everyone by default:

- AddonSuiteProfileSwapReminder
  - only loads if you have the addon `AddonSuite` installed
  - reminder for myself to swap addon profile depending on whether I'm in raid or not
- AutoGreet
  - the equivalent of /p hi
- BuffWarningPatch
  - removes the stupid alpha change for expiring auras
- CharacterSheetImprovements
  - extends the default ui character sheed with enchants, gems, and item level
- DraggableFrames
  - makes a couple additional default ui frames draggable
    - applies to Spellbook and the Group Finder
- GearUpgradeRankTooltipRenamer
  - port of https://wago.io/78z7JtUxS
- GearUpgradeReminder
  - port of https://wago.io/DA3OzoIsi
- HiddenQuestCleanup
  - automatically unwatches hidden watched quests
  - sounds stupid - but this, based on unknown factors - can be a significant performance improvement, I personally gained ~9 fps in dornogal
- MDTSim
  - port of https://wago.io/LTwpBiuz_
- TalentReminders
  - plays TTS when entering Midnight dungeons and you're missing certain talents
  - only implemented for evoker, doesn't do anything if you're not an evoker
- TurnSpeed
  - reverts turn speed back to 180 should it get lowered
- WeakAuras
  - /wa binding for the cooldown manager...

The following modules are ONLY ACTIVE IF YOUR CHARACTER NAME MATCHES MINE:

- CleanNamesInInstances
  - port of https://wago.io/M13VlqtM-
- Stopwatch
  - modifies the ingame stopwatch to act as combat timer. has ui elemenets hidden such as hours, buttons and background
- TargetShield
  - shows remaining amount of absorb on the target
- UIScale
  - port of !UIScale addon, but doesn't throw an error when reloading ui mid-combat
  - set to 1440p resolution
