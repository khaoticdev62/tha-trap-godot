class_name AppConfig
extends RefCounted
## Central, read-only application constants. No behaviour lives here.

const GAME_TITLE: String = "THA T.R.A.P."
const GAME_TAGLINE: String = "Learn. Defend. Level Up."
const VERSION: String = "0.1.0"

## Bump when the on-disk save envelope or payload layout changes, and add a
## matching step in SaveMigrations.
const SAVE_SCHEMA_VERSION: int = 1
const SAVE_SLOT_COUNT: int = 3
const SAVE_BACKUP_COUNT: int = 2
const SAVE_DIR: String = "user://saves"
## Files larger than this are rejected before being read (malformed-data guard).
const MAX_SAVE_BYTES: int = 4 * 1024 * 1024

const LOG_DIR: String = "user://logs"
const LOG_FILE: String = "trap.log"
const LOG_MAX_BYTES: int = 512 * 1024

const PROFILE_NAME_MAX_LENGTH: int = 24
const DEFAULT_PROFILE_NAME: String = "Rookie"
const TEXT_SCALE_MIN: float = 0.75
const TEXT_SCALE_MAX: float = 2.0
