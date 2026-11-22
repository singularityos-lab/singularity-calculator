project('singularity-calculator', ['vala', 'c'],
  version: '0.1.0',
  meson_version: '>= 0.59.0'
)

i18n = import('i18n')
add_project_arguments('-DGETTEXT_PACKAGE="singularity-calculator"', language: 'c')
subdir('po')

gnome = import('gnome')

gtk_dep            = dependency('gtk4')
gee_dep            = dependency('gee-0.8')

libsingularity_dep = dependency('singularity-1.0', 
  fallback: ['libsingularity', 'libsingularity_dep']
)

if not meson.is_subproject() and libsingularity_dep.type_name() == 'internal'
  libsingularity_vapi_dir = join_paths(meson.project_build_root(), 'subprojects', 'libsingularity')
  add_project_arguments(['--vapidir=' + libsingularity_vapi_dir], language: 'vala')
endif
math_dep           = meson.get_compiler('c').find_library('m')

# Compile .vetro to .ui in the ui/ subdirectory
subdir('ui')

resources = gnome.compile_resources(
  'singularity-calculator-resources',
  'resources/dev.sinty.calculator.gresource.xml',
  source_dir: [meson.current_source_dir(), meson.current_build_dir()],
  dependencies: [main_ui, files('resources/style.css')]
)

executable('singularity-calculator',
  ['src/engine.vala', 'src/expression.vala', 'src/window.vala', 'src/main.vala', 'src/units.vala', 'src/agent_intents.vala', resources],
  dependencies: [gtk_dep, gee_dep, libsingularity_dep, math_dep],
  install: true
)

# CalculatorEngine is deliberately GTK-free so the arithmetic can be covered
# without a display: the test binary needs nothing but GObject and libm.
calculator_engine_test = executable('calculator-engine-test',
  sources: ['src/engine.vala', 'src/expression.vala', 'tests/engine_test.vala'],
  dependencies: [dependency('gobject-2.0'), math_dep],
)
test('calculator-engine', calculator_engine_test)

service_conf = configuration_data()
service_conf.set('bindir', get_option('prefix') / get_option('bindir'))
configure_file(
  input: 'data/dev.sinty.calculator.service.in',
  output: 'dev.sinty.calculator.service',
  configuration: service_conf,
  install_dir: get_option('datadir') / 'dbus-1' / 'services'
)
install_data('data/dev.sinty.calculator.search-provider.ini',
  rename: 'dev.sinty.calculator.ini',
  install_dir: get_option('datadir') / 'singularity' / 'search-providers'
)

install_data('data/dev.sinty.calculator.desktop',
  install_dir: get_option('datadir') / 'applications'
)

install_data('data/dev.sinty.calculator.json',
  install_dir: get_option('datadir') / 'singularity' / 'app-settings'
)

install_data('data/icons/dev.sinty.calculator.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps'
)

iride = find_program('iride', required: get_option('iride'))
if iride.found()
  custom_target('iride-icon',
    input: 'data/icons/iride/iride.json',
    output: 'dev.sinty.calculator.iride',
    depend_files: files(
      'data/icons/iride/layers/000.svg',
      'data/icons/iride/layers/001.svg',
      'data/icons/iride/layers/002.svg',
      'data/icons/iride/layers/003.svg',
      'data/icons/iride/layers/004.svg',
      'data/icons/iride/layers/005.svg',
      'data/icons/iride/layers/006.svg',
      'data/icons/iride/layers/007.svg',
      'data/icons/iride/layers/008.svg',
      'data/icons/iride/layers/009.svg',
      'data/icons/iride/layers/010.svg',
      'data/icons/iride/layers/011.svg',
      'data/icons/iride/layers/012.svg',
      'data/icons/iride/layers/013.svg',
      'data/icons/iride/layers/014.svg',
      'data/icons/iride/layers/015.svg',
      'data/icons/iride/layers/016.svg',
      'data/icons/iride/layers/017.svg',
      'data/icons/iride/layers/018.svg',
      'data/icons/iride/layers/019.svg',
      'data/icons/iride/layers/020.svg',
      'data/icons/iride/layers/021.svg',
      'data/icons/iride/layers/022.svg',
      'data/icons/iride/layers/023.svg',
      'data/icons/iride/layers/024.svg',
      'data/icons/iride/layers/025.svg',
      'data/icons/iride/layers/026.svg',
      'data/icons/iride/layers/027.svg',
      'data/icons/iride/layers/028.svg',
      'data/icons/iride/layers/029.svg',
      'data/icons/iride/layers/030.svg',
      'data/icons/iride/layers/031.svg',
      'data/icons/iride/layers/032.svg',
      'data/icons/iride/layers/033.svg',
      'data/icons/iride/layers/034.svg',
      'data/icons/iride/layers/035.svg',
      'data/icons/iride/layers/036.svg',
      'data/icons/iride/layers/037.svg',
      'data/icons/iride/layers/038.svg',
      'data/icons/iride/layers/039.svg',
      'data/icons/iride/layers/040.svg',
      'data/icons/iride/layers/041.svg',
      'data/icons/iride/layers/042.svg',
      'data/icons/iride/layers/043.svg',
      'data/icons/iride/layers/044.svg',
      'data/icons/iride/layers/045.svg',
      'data/icons/iride/layers/046.svg',
      'data/icons/iride/layers/due.svg',
      'data/icons/iride/layers/sette.svg',
    ),
    command: [iride, 'build', meson.current_source_dir() / 'data' / 'icons' / 'iride', '@OUTPUT@'],
    install: true,
    install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps'
  )
endif
