module main

import cli { Command, Flag }
import os

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
		description: 'Adds a new destination to the list'
		usage: 'jump add <name>'
		required_args: 1
		execute: add_func
	}

	add_cmd.add_flag(Flag{
		flag: .string
		name: 'path'
		abbrev: 'p'
		description: 'Path of directory that you want to open.'
	})

	mut to_cmd := Command{
		name: 'to'
		description: 'Takes you to a preset directory'
		usage: 'jump to <name>'
		required_args: 1
		execute: to_func
	}

	mut list_cmd := Command{
		name: 'list'
		description: 'Lists all current paths and routes'
		usage: 'jump list'
		execute: list_func
	}

	mut remove_cmd := Command{
		name: 'rm'
		description: 'Remove a specific jump from the list'
		usage: 'jump rm <name>'
		execute: remove_func
	}

	remove_cmd.add_flag(Flag{
		flag: .bool
		name: 'all'
		abbrev: 'a'
		description: 'Add this flag to remove all jumps'
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
	user_path := cmd.flags.get_string('path')!
	if user_path != '' {
		path = user_path
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
	os.execute('code .')
	println("Launching in vscode...")
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
	lines := os.read_lines('${dir_path}/jumps.txt')!
	mut result := map[string]string{}
	for line in lines {
		result[line.split(':')[0].trim_space()] = line.split(':')[1].trim_space()
	}
	return result
}

fn write_routes (routes map[string]string) ! {
	dir_path := os.dir(@FILE)
	mut content := ''
	for name, path in routes {
		content += '$name : $path\n'
	}
	os.write_file('${dir_path}/jumps.txt', content)!
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