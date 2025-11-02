# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HadesCoopMod is a cooperative multiplayer mod for the game Hades. It consists of:
- **C++ DLL** (`HadesCoopGame.dll`) that hooks into Hades game internals
- **Lua scripts** that implement the coop gameplay logic

The mod intercepts game functions using symbol hooking and extends the player manager to support multiple players.

## ⚠️ CRITICAL: Line Endings

**The game will crash on startup if Lua files have Windows (CRLF) line endings!**

All `.lua` and `.sjson` files **MUST** use Unix (LF) line endings. The `.gitattributes` file enforces this with:
```
*.lua text eol=lf
*.sjson text eol=lf
```

### Symptoms of CRLF Line Endings
- Game crashes when selecting Coop mode
- No error messages, just immediate crash
- New files created with text editors may have CRLF by default

### How to Fix Line Endings
If you create new `.lua` files and the game crashes:

```bash
# Check line endings (should show "ASCII text" not "ASCII text, with CRLF")
file yourfile.lua

# Convert CRLF to LF
dos2unix yourfile.lua

# Or use sed if dos2unix not available
sed -i 's/\r$//' yourfile.lua
```

**Always verify line endings before deploying new Lua files to the game!**

## Build Commands

### Build with CMake (Windows x64)
```powershell
cmake -A x64 . -B build_msvc
cmake --build build_msvc --config Release
```

Binary files are output to the `bin` folder.

### Build with Visual Studio GUI
1. Install CMake support in Visual Studio Installer
2. Open the project in Visual Studio
3. Build → Build All
4. Check `bin` folder for `HadesCoopGame.dll`

## Development Setup

The mod is designed to be developed in-place within the Hades game directory:

1. Create `Hades/Hades/Content/ModModules/TN_CoopMod/`
2. Copy the repository to `Hades/Hades/Content/ModModules/TN_CoopMod/dev`
3. Create `init.lua` in `TN_CoopMod/` with: `ModRequire "dev/game/scripts/init.lua"`
4. Create `meta.sjson` in `TN_CoopMod/` specifying the mod name, DLL path, and author

This allows you to edit code directly in the repository and see changes in the game.

## Architecture

### C++ Native Layer (`game/src/`)

The C++ DLL integrates with Hades through the mod API defined in `HadesModApi.h`:

- **`HookTable`** (`HookTable.h/cpp`): Resolves game symbols by name to get function/object addresses. Stores pointers to game internals like `PlayerManager`, `UnitManager`, `World`, etc.

- **`CoopContext`** (`CoopContext.h/cpp`): Singleton managing coop state. Creates/removes players and player units through the `PlayerManagerExtension`.

- **`PlayerManagerExtension`** (`extensions/PlayerManagerExtension.h/cpp`): Extends Hades' `PlayerManager` to support multiple players beyond the standard single player.

- **`LuaFunctionDefs`** (`extensions/LuaFunctionDefs.h/cpp`): Registers custom Lua C functions exposed to the Lua layer for coop operations.

- **Interface headers** (`interface/*.h`): Define structures matching Hades internal classes (Player, Unit, Entity, World, etc.) to allow manipulation from C++.

### Lua Game Logic Layer (`game/scripts/`)

The Lua layer implements the actual coop gameplay:

- **`init.lua`**: Entry point. Loads `CoopMenu.lua` and checks if gamemode is "Coop". If so, loads `GamemodeInit.lua`.

- **`GamemodeInit.lua`**: Initializes all coop hooks and systems when coop mode starts. Coordinates initialization of camera, players, UI, loot, etc.

- **`HeroContext`** (`HeroContext.lua`): Core abstraction that virtualizes `CurrentRun.Hero` per-coroutine. Replaces `CurrentRun.Hero` with a metatable that returns the appropriate hero based on the current Lua coroutine. This allows game code designed for single-player to work with multiple heroes.

- **`CoopPlayers`** (`CoopPlayers.lua`): Manages the creation and state of player 2, including their unit, controller assignment, and synchronization.

- **`CoopCamera`** (`CoopCamera.lua`): Adjusts camera to keep both players in view.

- **`CoopControl`** (`CoopControl.lua`): Handles input routing to the correct player.

- **hooks/** directory: Contains hooks that modify game behavior for coop:
  - `ControlHooks.lua`: Input/control routing
  - `DamageHooks.lua`: Damage handling for multiple players
  - `EnemyAiHooks.lua`: AI targeting for multiple players
  - `LootHooks.lua`: Loot distribution between players
  - `UIHooks.lua`: UI adjustments for coop
  - `RunHooks.lua`: Run/save game modifications
  - `SaveHooks.lua`: Save system hooks
  - `WeaponHooks.lua`: Weapon behavior for multiple players
  - `VulnerabilityHooks.lua`: Status effects for multiple players

- **loot/** directory: Implements loot sharing/duplication logic between players.

### Key Architectural Patterns

**Hero Context Virtualization**: The mod's central innovation is `HeroContext`, which uses Lua coroutines to make `CurrentRun.Hero` context-dependent. Each coroutine "sees" a different hero, allowing existing single-player code to run per-player without modification.

**Hook System**: `HookUtils.lua` provides utilities to wrap/intercept existing game functions. Most hooks use `onPreFunction`, `onPostFunction`, and similar patterns to inject coop logic around original game functions.

**Symbol Resolution**: The C++ layer uses `GetSymbolAddress` to find game functions/objects by name at runtime, enabling function hooking without hardcoded addresses.

## Important File Conventions

- **Line endings**: See **CRITICAL** section above - CRLF line endings will crash the game!
- **C++ Standard**: C++20 is required
- **Precompiled header**: `pch.h` is used for C++ compilation

## Dependencies

- **EASTL-forge1.51**: Custom allocator-compatible STL replacement (in `libs/`)
- **lua-5.2.2**: Lua interpreter (in `libs/`)
- Built-in dependencies on Hades game DLLs (not in repo)
