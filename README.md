# singularity-calculator

A calculator app for the [Singularity Desktop Environment](https://github.com/singularityos-lab).

## Requirements

- [Meson](https://mesonbuild.com/) ≥ 1.0
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

## License

GPL-3.0-only - see [LICENSE](LICENSE).
