# Simulink Agentic Toolkit recovery (2026-10-14)

The installed toolkit was intact at
`C:/Users/tyasukaw/.matlab/agentic-toolkits/simulink` (release 2026.09).
The active MATLAB R2026b session had the MCP toolbox on its path but had not
run `satk_initialize`. Thus MCP exposed model tool names while MATLAB could
not resolve their `.p` implementations.

Recovery used the installed toolkit's documented initialization:

```matlab
addpath('C:/Users/tyasukaw/.matlab/agentic-toolkits/simulink')
satk_initialize
```

Installation validation passed: eight tool entry points, package resolution,
MCP binary, and running connector. `library.settingsLookup()` returned
`found=false`, `enabled=false`, `gatePass=true` (standard blocks available).
An unsaved scratch model was read, edited via `model_edit`, read again and
checked via `model_check` (`healthy`), then closed without saving.

`setup_imu_monitor()` now calls `ensure_simulink_toolkit()`; project-local
`startup.m` calls this setup. The guard runs initialization only if the
required functions are absent. Installed toolbox files and the global Codex
configuration were not changed.
