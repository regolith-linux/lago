project('lago',
  ['c','vala'],
  version: '0.1.0')

add_global_arguments('-DGETTEXT_PACKAGE="lago"',language: 'c')

gio_unix_2_0_dep = dependency('gio-unix-2.0')
json_glib_1_0_dep = dependency('json-glib-1.0')
gio_2_0_dep = dependency('gio-2.0')
glib_2_0_dep = dependency('glib-2.0')
gobject_2_0_dep = dependency('gobject-2.0')

subdir('src')
