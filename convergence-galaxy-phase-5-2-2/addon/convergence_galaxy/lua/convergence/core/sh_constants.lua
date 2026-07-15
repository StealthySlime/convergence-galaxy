Convergence.Constants = Convergence.Constants or {}

local Constants = Convergence.Constants

Constants.LOG_LEVELS = {
    DEBUG = 10,
    INFO = 20,
    WARN = 30,
    ERROR = 40,
    AUDIT = 50
}

Constants.STABILITY_MIN = 0
Constants.STABILITY_MAX = 100

Constants.ERROR = {
    INVALID_ARGUMENT = "invalid_argument",
    UNKNOWN_PLANET = "unknown_planet",
    PLANET_LOCKED = "planet_locked",
    DATABASE_ERROR = "database_error",
    PERMISSION_DENIED = "permission_denied",
    MODULE_DEPENDENCY_MISSING = "module_dependency_missing",
    MODULE_INITIALIZATION_FAILED = "module_initialization_failed"
}
