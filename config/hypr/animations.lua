-- =============================================================================
-- Animations & Curves
-- =============================================================================

-- Curves & Springs
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

-- dragon-island motion language (docs/design/15-movimiento.png); the same curves live in Theme.qml for QML.
-- speed is in tenths of a second: emergente 340 ms, estandar 240 ms, salida 160 ms, orbita 620 ms
hl.curve("emergente", { type = "bezier", points = { {0.2, 0.9},  {0.1, 1.08} } })   -- islands, panels, Nook opening (slight overshoot)
hl.curve("estandar",  { type = "bezier", points = { {0.3, 0},    {0, 1}      } })   -- state changes, hover, toggles
hl.curve("salida",    { type = "bezier", points = { {0.4, 0},    {1, 1}      } })   -- everything that closes or disappears
hl.curve("orbita",    { type = "bezier", points = { {0.16, 1.2}, {0.3, 1}    } })   -- launcher planets, Alt+Tab

-- Animation tree
-- "windows" (move / resize) keeps the "easy" spring: it feels better than a bezier when dragging or retiling.
hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 3.4,  bezier = "emergente",    style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.6,  bezier = "salida",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 2.4,  bezier = "estandar" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 3.4,  bezier = "emergente",    style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.6,  bezier = "salida",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 2.4,  bezier = "estandar",     style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 2.4,  bezier = "estandar",     style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 2.4,  bezier = "estandar",     style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })
