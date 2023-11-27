#!/usr/bin/python3
#a='base(octopi,a(b,c(a2)),mm)'
import argparse
import os
import subprocess
from get_remote_modules import get_remote_module
from typing import TextIO, List, Tuple, Dict, Any

def run_command(command: List[str], **kwargs: Dict[str, Any]):
    is_timeout = False
    p = subprocess.Popen(command, shell=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, **kwargs)
    try:
        stdout, stderr = p.communicate(timeout=5)
    except subprocess.TimeoutExpired as e:
        p.kill()
        stdout,stderr = p.communicate()
        is_timeout = True
    try:
        stdout = stdout.decode("utf-8")
    except UnicodeDecodeError as e:
        print("Error: can't decode stdout")
        print(e)
        print(stdout)
        stdout = ""

    try:
        stderr = stderr.decode("utf-8")
    except UnicodeDecodeError as e:
        print("Error: can't decode stderr")
        print(stderr)
        print(e)
        stderr = ""

    return stdout, stderr, is_timeout

    
def write_modules_scripts(module: str, state: str, module_folder: str, out: TextIO):
    out.write("# " + state + "_" + module + "\n")
    script = os.path.join(module_folder, state + "_chroot_script")
    if os.path.isfile(script):
        out.write("execute_chroot_script '" + module_folder + "' '" + script + "'\n")
    else:
        print("WARNING: No file at - " + script)
    
    return

def parse(a: str) -> List[Tuple[str,str]]:
    stack=[]
    return_value = []
    token = ""
    
    for char in a:
        if char == "(":
            stack.append(token)
            if token != "":
                return_value.append((token, "start"))
            token = ""
        elif char == ")":
            parent = stack.pop()
            if token != "":
                return_value.append((token, "start"))
                return_value.append((token, "end"))
                token = ""
            if parent != "":
                return_value.append((parent, "end"))
        elif char == ",":
            if token != "":
                return_value.append((token, "start"))
                return_value.append((token, "end"))
                token = ""
        else:
            token += char

    if token != "":
        return_value.append((token, "start"))
        return_value.append((token, "end"))
    if len(stack) > 0:
        raise Exception(str(stack))
    return return_value

def handle_meta_modules(modules: List[Tuple[str,str]]) -> Tuple[List[Tuple[str,str]],Dict[str,str]]:
    return_value = []
    modules_to_modules_folder = {}
    for module, state in modules:
        module_folders = [
            os.path.join(os.environ['DIST_PATH'], "modules", module),
            os.path.join(os.environ['CUSTOM_PI_OS_PATH'], "modules", module)
        ]
        # In case this is a meta module, order counts
        if state == "start":
            return_value.append((module, state))
        found_local = False
        found_remote = False
        for module_folder in module_folders:
            if os.path.isdir(module_folder):
                found_local = True
                modules_to_modules_folder[module] = module_folder
                break
            
        if not found_local:
            # TODO: Handle update
            found_remote, module_folder = get_remote_module(module)
            modules_to_modules_folder[module] = module_folder
            
            
        if not found_local and not found_remote:
            print(f"Error: Module {module} does not exist and is not in remote modules list")
            exit(1)

        meta_module_path = os.path.join(module_folder, "meta")
        if os.path.isfile(meta_module_path):
            # Meta module detected
            print(f"Running: {meta_module_path}")
            print(f"ENV: {os.environ['BASE_BOARD']}")
            submodules, meta_module_errors, is_timeout = run_command(meta_module_path)
            submodules = submodules.strip()
            print(f"Adding in modules: {submodules}")
            if meta_module_errors != "" or is_timeout:
                print(meta_module_errors)
                print(f"Got error processing meta module at: {meta_module_path}")
                exit(1)
            if submodules != "":
                print(f"Got sub modules: {submodules}")

                for sub_module in submodules.split(","):
                    sub_module = sub_module.strip()
                    return_value_sub, modules_to_modules_folder_sub = handle_meta_modules([(sub_module, state)])
                    return_value += return_value_sub
                    modules_to_modules_folder.update(modules_to_modules_folder_sub)
        # In case this is a meta module, order counts
        if state == "end":
            return_value.append((module, state))

    return return_value, modules_to_modules_folder


if __name__ == "__main__":
    parser = argparse.ArgumentParser(add_help=True, description='Parse and run CustomPiOS chroot modules')
    parser.add_argument('modules', type=str, help='A string showing how the modules should be called')
    parser.add_argument('output_script', type=str, help='path to output the chroot script master')
    parser.add_argument('modules_after_path', nargs='?', default=None, type=str, help='path to output the chroot script master')
    parser.add_argument('remote_and_meta_config_path', nargs='?', default=None, type=str, help='path to output the config script of remote modules and submodules')
    args = parser.parse_args()
    
    if os.path.isfile(args.output_script):
        os.remove(args.output_script)
        
    with open(args.output_script, "w+") as f:
        f.write("#!/usr/bin/env bash\n")
        f.write("set -x\n")
        f.write("set -e\n")
        initial_execution_order = parse(args.modules.replace(" ", ""))
        f.write(f"# Defined execution order: {initial_execution_order}\n")
        modules_execution_order, modules_to_modules_folder = handle_meta_modules(initial_execution_order)
        f.write(f"# With meta modules order: {modules_execution_order}\n")
        
        for module, state in modules_execution_order:
            module_folder = modules_to_modules_folder[module]
            write_modules_scripts(module, state, module_folder, f)

        # List all new modules add them in, then remove existing ones
        list_new_modules = []
        for module, state in modules_execution_order:
            if module not in list_new_modules:
                list_new_modules.append(module)
        for module, state in initial_execution_order:
            if module in list_new_modules:
                list_new_modules.remove(module)
        
    # TODO2: load configs from yaml
    if args.modules_after_path is not None:
        with open(args.modules_after_path, "w") as w:
            w.write(",".join(list_new_modules))

    with open(args.remote_and_meta_config_path, "w") as f:
        for module in list_new_modules:
            module_folder = modules_to_modules_folder[module]
            module_config_path = os.path.join(module_folder, "config")
            if os.path.isfile(module_config_path):
                f.write(f"source {module_config_path}\n")

    os.chmod(args.output_script, 0o755)

