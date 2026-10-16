# LcaDesignSystem

Lazy Coding Agent **design system** for Lazarus: theme tokens and palette components stream on `.lfm` forms.

## Palette (`LCA Design`)

| Component | Purpose |
|-----------|---------|
| `TLcaThemedPageTabBar` | Themed tab strip for `TPageControl` with `ShowTabs = False` |
| `TLcaThemedButton` | Primary / cancel / destructive / ghost roles; custom paint on Windows |
| `TLcaThemedComboBox` | Rounded field + chevron (Windows), owner-draw list; set `Height`/`ItemHeight` in the form |
| `TLcaNavRailButton` | Navigation rail cell with optional caption |
| `TLcaSurfacePanel` | Card surface with optional accent border |
| `TLcaMarkdownView` | Markdown subset preview (TurboPower IPro) |
| `TLcaTerminalPanel` | Embedded PTY terminal (requires TerminalEmulator packages) |

Theme API lives in **`LcaTheme`** (`TThemeKind`, `ThemePalette`, `ApplyThemedForm`, etc.).

## Install (Windows)

From the repo root:

```bat
scripts\install-lca-lazarus.bat
```

(Or `powershell -ExecutionPolicy Bypass -File scripts\install-lca-lazarus.ps1` from the repo root.)

## Install (Linux / macOS)

```bash
chmod +x scripts/install-lca-lazarus.sh
./scripts/install-lca-lazarus.sh
```

### Options

- **`--link-only`** — Register and compile runtime packages for `lazbuild` only (no IDE palette install).
- **`--skip-terminal`** — Skip `TerminalFramework` / `ViewLCL` (terminal component will not build).

Requires:

- Lazarus + `lazbuild` on `PATH` (or `LAZBUILD` / `$env:LAZBUILD`)
- Git submodule `third_party/TerminalEmulator` (unless `--skip-terminal`)
- IDE packages: **TurboPowerIPro**, **SynEdit** (app project; markdown uses IPro)

The install script links the **runtime** package for `lazbuild`, installs **`LcaDesignSystemDesign`** into the IDE, and runs **`lazbuild --build-ide`** (close Lazarus first). Only the lightweight design package is linked into `lazarus.exe`; terminal and TurboPower stay in the runtime package used by projects.

After it finishes, start Lazarus, open the **Component** palette, and select the **LCA Design** page.

### IDE hangs on startup

If Lazarus windows appear but the UI never finishes loading (e.g. undrawn toolbar buttons):

```bat
scripts\recover-lazarus-ide.bat
```

(Linux/macOS: `./scripts/recover-lazarus-ide.sh`.) That removes LCA entries from `staticpackages.inc` and rebuilds the IDE. Then run **`install-lca-lazarus`** again with Lazarus closed.

If it still hangs with **Coding Agent Chat** restored on the desktop, set that IDE window not visible in `environmentoptions.xml` (from the **lazaruscodingagent** plugin), rebuild the IDE once, then retry.

## Package

- **`LcaDesignSystem.lpk`** — **RunTimeOnly** (app + `lazbuild`; all component units)
- **`LcaDesignSystemDesign.lpk`** — **DesignTime** (`LcaDesignReg` only; **LCA Design** palette). Compile-time **`OtherUnitFiles=src`** is required so `LcaDesignReg` resolves; **`UsageOptions` / `UnitPath`** must stay **`$(PkgOutDir)` only** (do not publish `src` to the IDE — types come from the linked runtime package). After changing either `.lpk`, close Lazarus and re-run **`scripts/install-lca-lazarus`**.

If the IDE warns that the runtime unit path contains `...\LcaDesignSystem\src`, reinstall the design package with Lazarus closed so only `lib\$(TargetCPU)-$(TargetOS)` is used at run/build time.
