# Changelog

All notable changes to DCS-WORLD-EVENTS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - 2026-02-06

### Added
- Radio menu system with F10 integration
  - "WorldEvents > Spawn Event" menu option for triggering events
  - "WorldEvents > Event Status" menu option for checking event status
- Group-based radio access control system
  - Access control via `WE.RadioUsers` configuration table
  - Support for universal access ("ALL") or name-based matching
  - Group name matching with plain text search (no pattern matching)
- Modular event handling system
  - New `event.lua` module for all event handling logic
  - Support for multiple event types (S_EVENT_PLAYER_ENTER_UNIT, S_EVENT_BIRTH, S_EVENT_PLAYER_LEAVE_UNIT)
  - Automatic radio menu management on player join/leave/respawn
  - Proper DCS event handler format with cleanup support
- Dynamic menu assignment
  - Per-group radio menus for better organization
  - Automatic menu creation/removal on player reslotting
  - Fallback global menu support when group detection fails

### Changed
- Namespace standardization from mixed ME/WE to consistent WE namespace
- CTLD functions ported to WE namespace for compatibility
- Build system separated into `build.ps1` (combine files) and `extract.ps1` (split files)
- Radio access control moved from player name to aircraft group name matching
- Event handling logic separated from radio functions for better modularity
- Enhanced logging system for debugging access control and event detection

### Fixed
- String pattern matching issue with special characters in user strings (e.g., "[Patreon]")
- Event handler format corrected for proper DCS API compatibility
- Radio menu persistence issues during player reslotting
- Access control logic to use plain text matching instead of Lua patterns

### Technical Details
- Files added: `includes/event.lua`, `includes/radio_functions.lua` 
- Files modified: `includes/config.lua`, `includes/init.lua`, `includes/_compiler_registry.txt`
- Event system now properly handles player spawn/respawn/reslot scenarios
- Radio menus dynamically created per group with access validation
- Debug logging enhanced for troubleshooting access control decisions
