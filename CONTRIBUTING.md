# Contributing to singularity-files

## Issues

Report bugs and request features in the
[Singularity Desktop tracker](https://github.com/singularityos-lab/singularity-desktop/issues/new/choose).

## Development setup

```bash
git clone https://github.com/singularityos-lab/singularity-files
cd singularity-files
meson setup build
ninja -C build
```

Run the engine tests:

```bash
meson test -C build --suite singularity-calculator
```

Arithmetic belongs in `src/engine.vala`, which must stay free of GTK and of
gettext so the test binary can link against GObject and libm alone. The window
maps engine states to translated text.

## Code style

- Language: **Vala** or **C/C++** only.
- Indentation: **4 spaces** no tabs, no trailing whitespace.
- Keep files focused: one primary class per `.vala` file, named after the class
  (e.g. `ScreenshotPortal` -> `screenshot.vala`). Redundant suffixes in the 
  filename (like `_portal` or `_manager`) should be avoided.

## License

By contributing you agree your code will be released under [GPL-3.0-only](LICENSE).


## Commit messages

Commits follow Conventional Commits:

```
<type>: <subject>
```

`<type>` is one of `feat`, `fix`, `chore`, `docs`, `build`, `ci`, `refactor`, `perf`, `style`, `test`, `revert`. Keep `<subject>` short, lowercase and in English. An optional scope is allowed: `<type>(<scope>): <subject>`.

When a commit closes an issue, use `<type>[closes #ID]: <issue title>`, for example:

```
fix[closes #2]: Discord doesn't open on Singularity desktop
```

Do not add co-author or attribution trailers.
