cfg_lago = configuration_data()
cfg_lago.set('DATADIR', join_paths(get_option('prefix'),get_option('datadir')))
cfg_lago.set('PKGDATADIR', join_paths(get_option('prefix'),get_option('datadir'),'lago'))
cfg_lago.set('GETTEXT_PACKAGE', 'lago')
cfg_lago.set('RELEASE_NAME', 'lago')
cfg_lago.set('PREFIX', get_option('prefix'))
cfg_lago.set('VERSION', '0.1.0')
cfg_lago.set('TESTSRCDIR', meson.source_root())

cfgfile_1 = configure_file(
	input: 'Config.vala.base',
	output: 'Config.vala',
	configuration: cfg_lago)

lago_deps = [gio_unix_2_0_dep]
lago_deps += [json_glib_1_0_dep]
lago_deps += [gio_2_0_dep]
lago_deps += [glib_2_0_dep]
lago_deps += [gobject_2_0_dep]
lago_sources = [cfgfile_1]
lago_sources += ['grelier.vala']
lago_sources += ['lago.vala']
lago_link_args = ['-rdynamic']

executable('lago',lago_sources,
    dependencies: lago_deps,
    link_args: lago_link_args,
    install: true)

