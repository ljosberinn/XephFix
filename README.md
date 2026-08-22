Collection of former utiltiy WeakAuras or similar.

## How To Disable A Module For Yourself

Find the feature you wish to disable in the TOC-file. Either remove it from there, or if you wish to not having to edit files, run:

```lua
-- Stopwatch as example
/run XephUISaved.Stopwatch = false
/reload
```

## Modules

- AddonSuiteProfileSwapReminder
  - only loads if you have the addon `AddonSuite` installed
  - reminder for myself to swap addon profile depending on whether I'm in raid or not
- AutoDialogueInteraction
  - automatically selects specific gossip options in certain dungeons (Pit of Saron, Algeth'ar Academy, etc.)
- AutoGreet
  - the equivalent of /p hi
- AutoKeystone
  - automatically inserts your keystone into the receptacle when it opens
- AutoQuest
  - automatically accepts, selects and turns in quests
- AutoRepair
  - automatically repairs at merchants
- AutoRoleSelect
  - automatically confirms role check popups based on your current specialization
- AutoSellJunk
  - automatically sells junk at merchants
- BuffWarningPatch
  - removes the stupid alpha change for expiring auras
- CharacterSheetImprovements
  - extends the default ui character sheed with enchants, gems, and item level
- CharacterStatsFormatting
  - shows raw combat rating alongside the percentage for secondary stats on the character sheet
- ChatItemEnhancements
  - prepends item icons to item links in chat and appends slot type and item level to the label
- CleanNamesInInstances
  - port of https://wago.io/M13VlqtM-
- CooldownManagerMountOpacity
  - changes the opacity of the cooldown manager when mounted out of combat to 0.25
- CooldownManagerTweaks
  - reskins cooldown manager icons to square with a custom font and black border
  - enables millisecond countdown display below 4 seconds for all viewers
  - supports injecting custom item-triggered auras into the buff icon viewer
- CVars
  - enables aura spell IDs in tooltips
- DamageMeterToggle
  - automatically shows the damage meter in dungeons, but hides it outside
- DraggableFrames
  - makes a couple additional default ui frames draggable
    - applies to Spellbook and the Group Finder
- EventToastBlocker
  - suppresses specific event toast popups (waystone discovery, new stage notifications)
- EvokerLetFly
  - evoker only: mutes the default Deep Breath / Breath of Eons voice lines and plays a custom sound instead
- FocusMarkerAnnouncement
  - announces your focus marker assuming you have a /tm macro wtih the name `focus`
- GearUpgradeRankTooltipRenamer
  - port of https://wago.io/78z7JtUxS
- GearUpgradeReminder
  - port of https://wago.io/DA3OzoIsi
- KeystoneAnnouncer
  - automatically announces your key when you reroll it or at the end of a dungeon and it was your key that was completed
- KeystoneInfo
  - lean implementation of the /key command
  - doesn't execute if you have BigWigs
  - communicates your keystone info to others with e.g. BigWigs
- MDTSim
  - port of https://wago.io/LTwpBiuz_
- PlayerFrameChain
  - adds the winged boss chain overlay to the player frame
- Stopwatch
  - modifies the ingame stopwatch to act as combat timer. has ui elemenets hidden such as hours, buttons and background
- TalentReminders
  - plays TTS when entering Midnight dungeons and you're missing certain talents
  - only implemented for evoker, doesn't do anything if you're not an evoker
- TalkingHeadBlocker
  - hides talking head frames
- TargetShield
  - shows remaining amount of absorb on the target
- TooltipIDs
  - appends item ID and spell ID to their respective tooltips
- UIScale
  - port of !UIScale addon, but doesn't throw an error when reloading ui mid-combat
  - set to 1440p resolution
- UnitTooltipEnhancements
  - hides the tooltip health bar
  - class colors names, guild, spec and reaction lines, colors mob names by tap state
  - rewrites the level line with difficulty color, creature type and classification
