# jump

This is a little Command Line Application which allows you to add anchor points at different folders and then jump to them.

Currently it is very much tailored to my needs ie it launches vscode when you jump to a folder, but that can be customized quite easily.

You also need to add the binary to your bash PATH. 

The commands are:
  jump add <name> - Add the current directory to the list with the name <name>
    -p <path>     - You can specify the path instead of using the current directory
  jump rm <name>  - Remove the jump with name <name>
    -a            - You can remove all existing jumps at once
  jump list       - Lists all current jumps
  jump to <name>  - launches the directory associated with name <name> in virtual studio code 
