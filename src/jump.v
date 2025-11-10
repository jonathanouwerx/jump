module main

import cli { Command, Flag }
import os
import toml

import v.vmod

fn main() {
	dir_path := os.dir(@FILE)
	manifest := vmod.from_file('$dir_path/../v.mod') or { panic(err) }

	mut cmd := Command{
		name: manifest.name
		description: manifest.description
		version: manifest.version
	}
	mut add_cmd := Command{
		name: 'add'
		description: 'Add a new jump destination to the TOML configuration'
		usage: 'jump add <name> [--path=<directory>]'
		required_args: 1
		execute: add_func
	}

	add_cmd.add_flag(Flag{
		flag: .string
		name: 'path'
		abbrev: 'p'
		description: 'Path to the directory to jump to (defaults to current directory)'
	})

	mut to_cmd := Command{
		name: 'to'
		description: 'Jump to a saved destination and optionally open it in an editor'
		usage: 'jump to <name> [--editor=<command>|-e]'
		required_args: 1
		execute: to_func
	}

	to_cmd.add_flag(Flag{
		flag: .string
		name: 'editor'
		abbrev: 'e'
		description: 'Editor command to use (overrides config.toml). Use -e without value to skip opening editor.'
		required: false
	})

	mut list_cmd := Command{
		name: 'list'
		description: 'List all configured jump destinations from jumps.toml'
		usage: 'jump list'
		execute: list_func
	}

	mut remove_cmd := Command{
		name: 'rm'
		description: 'Remove a jump destination from the configuration'
		usage: 'jump rm <name> [--all|-a]'
		execute: remove_func
	}

	remove_cmd.add_flag(Flag{
		flag: .bool
		name: 'all'
		abbrev: 'a'
		description: 'Remove all jump destinations from the configuration'
	})

	cmd.add_command(to_cmd)
	cmd.add_command(list_cmd)
	cmd.add_command(add_cmd)
	cmd.add_command(remove_cmd)
	cmd.setup()
	cmd.parse(os.args)
}

fn add_func(cmd Command) ! {
	name := cmd.args[0]
	mut path := os.abs_path('')

	// Parse --path flag manually
	for i, arg in os.args {
		if arg == '--path' && i + 1 < os.args.len {
			path = os.args[i + 1]
			break
		} else if arg.starts_with('--path=') {
			path = arg.split('=')[1]
			break
		}
	}

	add_route(name, path)!
}

fn to_func(cmd Command) ! {
	name := cmd.args[0]
	path := get_route(name)!
	if path == '' {
		println("There is no jump associated to that name!")
		return
	}
	os.chdir(path)!

	config := get_config()!

	// Parse editor flag manually from os.args
	mut editor_flag := ''
	for i, arg in os.args {
		if arg == '--editor' && i + 1 < os.args.len {
			editor_flag = os.args[i + 1]
			break
		} else if arg.starts_with('--editor=') {
			editor_flag = arg.split('=')[1]
			break
		} else if arg == '-e' {
			// Check if there's a value after -e
			if i + 1 < os.args.len && !os.args[i + 1].starts_with('-') {
				editor_flag = os.args[i + 1]
			} else {
				// -e without value means don't open editor
				editor_flag = 'none'
			}
			break
		}
	}

	// Determine which editor to use
	mut editor_cmd := config.default_editor
	if editor_flag != '' {
		editor_cmd = editor_flag
	}

	// Determine if we should open in editor
	mut should_open_editor := config.open_in_editor
	if editor_flag == 'none' {
		should_open_editor = false
	} else if editor_flag != '' {
		should_open_editor = true
	}

	if should_open_editor && editor_cmd != 'none' {
		os.execute('${editor_cmd} .')
		println("Launching in ${editor_cmd}...")
	} else {
		println("Jumped to directory: ${path}")
	}
}

fn list_func(cmd Command) ! {
	routes := get_routes()!
	if routes.len > 0 {
		println("Here are all the jumps that you have created:\n")
		for name, path in routes {
			println("\t$name -- '$path'")
		}
		println("")
	} else {
		println("You have not created any jumps yet. This can be done by typing 'jump add <name>' and it will now reference the current directory")
	}
	
}

fn remove_func(cmd Command) ! {
	all := cmd.flags.get_bool('all')!
	if all {
		write_routes(map[string]string{})!
	} else if name := cmd.args[0] {
		delete_route(name)!
	} else {
		println("Please either attach the '--all' flag or add a name as the first argument of the 'rm' command.")
	}
	list_func(cmd)!
}

fn get_route (name string) !string {
	routes := get_routes()!
	return routes[name]
}

fn get_routes () !map[string]string {
	dir_path := os.dir(@FILE)
	doc := toml.parse_file('${dir_path}/jumps.toml') or {
		// Return empty map if file doesn't exist
		return map[string]string{}
	}

	mut result := map[string]string{}
	toml_map := doc.to_any().as_map()
	for key, value in toml_map {
		result[key] = value.string()
	}
	return result
}

fn write_routes (routes map[string]string) ! {
	dir_path := os.dir(@FILE)
	mut content := ''
	for name, path in routes {
		content += '${name} = "${path}"\n'
	}
	os.write_file('${dir_path}/jumps.toml', content)!
}

fn add_route (name string, path string) ! {
	// TODO check if path is valid
	mut routes := get_routes()!
	routes[name] = path
	write_routes(routes)!
}	

fn delete_route (name string) ! {
	mut routes := get_routes()!
	routes.delete(name)
	write_routes(routes)!
}

struct Config {
mut:
	default_editor string
	open_in_editor bool
}

fn get_config() !Config {
	dir_path := os.dir(@FILE)
	doc := toml.parse_file('${dir_path}/config.toml') or {
		// Return default config if file doesn't exist
		return Config{
			default_editor: 'cursor'
			open_in_editor: true
		}
	}

	config := Config{
		default_editor: doc.value('default_editor').default_to('cursor').string()
		open_in_editor: doc.value('open_in_editor').default_to(true).bool()
	}
	return config
}

fn write_config(config Config) ! {
	dir_path := os.dir(@FILE)
	content := 'default_editor = "${config.default_editor}"\nopen_in_editor = ${config.open_in_editor}\n'
	os.write_file('${dir_path}/config.toml', content)!
}