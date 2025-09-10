# Copilot Instructions for GlowColors SourceMod Plugin

## Repository Overview

This repository contains the **GlowColors** plugin for SourceMod, a scripting platform for Source engine games. The plugin allows players to customize their character glow colors with support for static colors, rainbow effects, and integration with zombie-themed game modes.

### Key Components
- **Main Plugin**: `addons/sourcemod/scripting/GlowColors.sp` (619 lines)
- **Native API**: `addons/sourcemod/scripting/include/glowcolors.inc` 
- **Configuration**: `addons/sourcemod/configs/GlowColors.cfg`
- **Translations**: `addons/sourcemod/translations/GlowColors.phrases.txt`

## Technical Environment

### Build System
- **Build Tool**: SourceKnight 0.2 (defined in `sourceknight.yaml`)
- **Compiler**: SourceMod compiler (spcomp) via SourceKnight
- **Target Platform**: SourceMod 1.11.0+ (project uses 1.11.0-git6934)
- **Output**: Compiled .smx files to `/addons/sourcemod/plugins`

### Dependencies
- **SourceMod**: 1.11.0-git6934 (base platform)
- **MultiColors**: Color formatting library (required)
- **ZombieReloaded**: Optional integration for zombie game modes

### Build Commands
```bash
# Install SourceKnight (if not available)
pip install sourceknight

# Build the plugin
sourceknight build

# The CI uses GitHub Actions with maxime1907/action-sourceknight@v1
```

## Project Architecture

### Plugin Structure
```
GlowColors Plugin
├── Command Handlers (sm_glowcolors, sm_mccmenu, sm_rainbow)
├── Menu System (color selection, rainbow effects)
├── Cookie System (persistent player preferences)
├── Event Handlers (spawn, team change, disconnect)
├── Native Functions (GlowColors_SetRainbow, GlowColors_RemoveRainbow)
└── Color Management (RGB, HEX parsing, rainbow algorithms)
```

### Key Global Variables
- `g_aGlowColor[MAXPLAYERS + 1][3]` - Player RGB color values
- `g_aRainbowFrequency[MAXPLAYERS + 1]` - Rainbow effect frequencies
- `g_bRainbowEnabled[MAXPLAYERS+1]` - Rainbow state tracking
- `g_GlowColorsMenu` - Main color selection menu
- `g_hClientCookie` - Player preference storage

## Code Style & Standards

### Naming Conventions
- **Global Variables**: Prefix with `g_` (e.g., `g_aGlowColor`)
- **Functions**: PascalCase (e.g., `ApplyGlowColor`)
- **Local Variables**: camelCase (e.g., `rainbowEnabled`)
- **Constants**: UPPER_CASE (e.g., `CHAT_PREFIX`)

### Required Pragmas
```sourcepawn
#pragma semicolon 1
#pragma newdecls required
```

### Indentation
- Use **4 spaces** for indentation (not tabs despite guidelines mentioning tabs)
- Follow existing project patterns for consistency

### Memory Management
- Always use `delete` for cleanup (never check for null first)
- Use `delete` for StringMap/ArrayList instead of `.Clear()` to prevent memory leaks
- Proper handle management for timers and events

## Development Guidelines

### When Modifying Code

1. **Color System Changes**
   - Colors are stored as RGB values (0-255 range)
   - HEX format support with regex validation
   - Brightness constraints via `sm_glowcolor_minbrightness` cvar

2. **Rainbow Effects**
   - Frequency range controlled by `sm_glowcolors_minrainbowfrequency` and `sm_glowcolors_maxrainbowfrequency`
   - Uses sine wave calculations in `OnPostThinkPost`
   - Proper cleanup required when disabling rainbow mode

3. **Menu System**
   - Dynamic menu generation from config file
   - Support for both predefined and custom colors
   - Proper menu handle management

4. **Event Integration**
   - Hook `player_spawn`, `player_team`, `player_disconnect`
   - ZombieReloaded integration for team-specific restrictions
   - Proper client validation before applying effects

### Testing Considerations

1. **Manual Testing**
   - Test color application on player spawn
   - Verify rainbow effects work correctly
   - Test menu navigation and custom color input
   - Validate HEX and RGB parsing

2. **Integration Testing**
   - Test with/without ZombieReloaded plugin
   - Verify native function calls from other plugins
   - Test cookie persistence across sessions

3. **Edge Cases**
   - Invalid color inputs (out of range, malformed HEX)
   - Player disconnection during rainbow effects
   - Late plugin loading scenarios

## Configuration Management

### Color Configuration (`GlowColors.cfg`)
- KeyValues format with color name and RGB values
- Example: `"Red" "255 0 0"`
- Add new predefined colors here for menu system

### ConVars
- `sm_glowcolor_minbrightness` - Minimum allowed brightness (0-255)
- `sm_glowcolors_timer` - Color reapplication interval
- `sm_glowcolors_minrainbowfrequency` - Minimum rainbow frequency
- `sm_glowcolors_maxrainbowfrequency` - Maximum rainbow frequency

## Native API Development

### Implementing Natives
```sourcepawn
// In include file
native void GlowColors_SetRainbow(int client, float frequency = 1.0);
native void GlowColors_RemoveRainbow(int client);

// In main plugin
CreateNative("GlowColors_SetRainbow", Native_SetRainbow);
CreateNative("GlowColors_RemoveRainbow", Native_RemoveRainbow);
```

### Documentation Standards
- Document all native functions with parameter descriptions
- Include error conditions and return values
- Use proper SharedPlugin declarations

## Common Patterns

### Client Validation
```sourcepawn
if (!client || !IsClientInGame(client) || IsFakeClient(client))
    return;
```

### Color Application
```sourcepawn
void ToolsSetEntityColor(int client, int red, int green, int blue)
{
    SetEntityRenderMode(client, RENDER_TRANSCOLOR);
    SetEntityRenderColor(client, red, green, blue);
}
```

### Cookie Management
```sourcepawn
// Always check if cookies are cached before reading/writing
if (AreClientCookiesCached(client)) {
    ReadClientCookies(client);
}
```

## Performance Considerations

- Rainbow effects use `OnPostThinkPost` hook - minimize calculations
- Cookie operations are asynchronous - handle accordingly
- Menu regeneration should be minimized during runtime
- Color validation regex should be compiled once at plugin start

## Integration Points

### ZombieReloaded Plugin
- Check `g_Plugin_ZR` boolean for availability
- Restrict color changes based on team/class in zombie modes
- Use translation system for restriction messages

### MultiColors Plugin
- Required dependency for chat message formatting
- Use `CPrintToChat` for colored console output
- Maintain consistent color scheme with chat prefix

## Troubleshooting

### Common Issues
1. **Colors not applying**: Check client validation and event hooks
2. **Rainbow not working**: Verify `OnPostThinkPost` hook and frequency values
3. **Menu not displaying**: Check config file loading and KeyValues parsing
4. **Cookies not saving**: Ensure proper client cookie validation

### Debug Approach
1. Add console output for state tracking
2. Verify event firing with temporary prints
3. Check regex compilation for color parsing
4. Validate client indices in all operations