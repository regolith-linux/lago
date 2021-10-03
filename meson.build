project('lago',
  ['c','vala'],
  version: '0.1.0')

add_global_arguments('-DGETTEXT_PACKAGE="lago"',language: 'c')

gio_unix_2_0_dep = dependency('gio-unix-2.0')
json_glib_1_0_dep = dependency('json-glib-1.0')
gio_2_0_dep = dependency('gio-2.0')
glib_2_0_dep = dependency('glib-2.0')
gobject_2_0_dep = dependency('gobject-2.0')

meson.add_install_script(join_paths(meson.current_source_dir(),'meson_scripts','install_data.sh'),join_paths(get_option('prefix'),get_option('datadir'),'lago'),join_paths(meson.current_source_dir(),'data/local','','*'))

meson.add_install_script(join_paths(meson.current_source_dir(),'meson_scripts','install_data.sh'),join_paths(get_option('prefix'),get_option('datadir'),'doc','lago'),join_paths(meson.current_source_dir(),'doc','','*'))

subdir('src')
