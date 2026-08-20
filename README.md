# singularity-calculator

A calculator app for the [Singularity Desktop Environment](https://github.com/singularityos-lab).

## Requirements

- [Meson](https://mesonbuild.com/) ≥ 0.59
- [Vala](https://vala.dev/) compiler
- [Vetro](https://github.com/singularityos-lab/vetro/) compiler
- GTK4
- libgee-0.8
- [libsingularity](https://github.com/singularityos-lab/libsingularity)

## Build & Install

```sh
meson setup build
meson compile -C build
meson install -C build
```

The project resolves `libsingularity` through a Meson subproject fallback, so
it is normally configured from the [singularity-desktop](https://github.com/singularityos-lab/singularity-desktop)
tree rather than on its own.

## Tests

`CalculatorEngine` (`src/engine.vala`) holds every bit of arithmetic and
depends on nothing but GObject and libm, so it is covered by a headless test
binary:

```sh
meson test -C build --suite singularity-calculator
```

## License

GPL-3.0-only - see [LICENSE](LICENSE).
