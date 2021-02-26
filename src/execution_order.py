#a='base(octopi,a(b,c(a2)),mm)'
import argparse
import os

def handle(module, state, out):
    out.write("# " + state + "_" + module + "\n")
    
    module_folders = [os.path.join(os.environ['DIST_PATH'], "modules", module),
                      os.path.join(os.environ['CUSTOM_PI_OS_PATH'], "modules", module)
        ]
    
    for module_folder in module_folders:
        if os.path.isdir(module_folder):
            script = os.path.join(module_folder, state + "_chroot_script")
            if os.path.isfile(script):
                out.write("execute_chroot_script '" + module_folder + "' '" + script + "'\n")
            else:
                print("WARNING: No file at - " + script)
            break
    return

def parse(a, callback):
    stack=[]
    token = ""
    
    for char in a:
        if char == "(":
            stack.append(token)
            if token != "":
                callback(token, "start")
            token = ""
        elif char == ")":
            parrent = stack.pop()
            if token != "":
                callback(token, "start")
                callback(token, "end")
                token = ""
            if parrent != "":
                callback(parrent, "end")
        elif char == ",":
            if token != "":
                callback(token, "start")
                callback(token, "end")
                token = ""
        else:
            token += char

    if token != "":
        callback(token, "start")
        callback(token, "end")
    if len(stack) > 0:
        raise Exception(str(stack))
    return

if __name__ == "__main__":
    parser = argparse.ArgumentParser(add_help=True, description='Parse and run CustomPiOS chroot modules')
    parser.add_argument('modules', type=str, help='A string showing how the modules should be called')
    parser.add_argument('output_script', type=str, help='path to output the chroot script master')
    args = parser.parse_args()
    
    if os.path.isfile(args.output_script):
        os.remove(args.output_script)
        
    with open(args.output_script, "w+") as f:
        f.write("#!/usr/bin/env bash\n")
        f.write("set -x\n")
        f.write("set -e\n")
        parse(args.modules.replace(" ", ""), lambda module, state: handle(module, state, f))
        
    os.chmod(args.output_script, 0o755)

