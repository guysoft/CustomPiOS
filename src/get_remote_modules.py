import os
import yaml
from pathlib import Path
from typing import Typle, Optional
import git
from git import RemoteProgress
            
# TODO add env var to set this
REMOTES_DIR = os.path.join(os.path.dirname(__file__), "remotes")
REMOTE_CONFIG = os.path.join(os.path.dirname(__file__), "modules_remote.yml")


class CloneProgress(RemoteProgress):
    def update(self, op_code, cur_count, max_count=None, message=''):
        if message:
            print(message)


def ensure_dir(d, chmod=0o777):
    """
    Ensures a folder exists.
    Returns True if the folder already exists
    """
    if not os.path.exists(d):
        os.makedirs(d, chmod)
        os.chmod(d, chmod)
        return False
    return True


def read_remotes():
    if not os.path.isfile(REMOTE_CONFIG):
        raise Exception(f"Error: Remotes config file not found: {REMOTE_CONFIG}")
    with open(REMOTE_CONFIG,'r') as f:
        output = yaml.safe_load(f)
        return output

def get_remote_module(module) -> Tuple[found, Optional[str]]:
    """ Gets the remote module and saves it to cache. Returns True if found, else false"""
    print(f"INFO: Module {module}, looking for remote module and downloading")
    remotes = read_remotes()
    print(remotes.keys())
    if module not in remotes.keys():
        return False, None
    
    ensure_dir(REMOTES_DIR)
    
    if remotes[module]["type"] == "git":
        # TODO: make it so the module folder is taken in to accound and the start script is generated from there
        # CONSIDER TODO: How to manager update from git pull
        repo_url = remotes[module]["repo"]
        branch = remotes[module]["tag"]
        # credentials = base64.b64encode(f"{GHE_TOKEN}:".encode("latin-1")).decode("latin-1")
        git.Repo.clone_from(
            url=repo_url,
            single_branch=True,
            depth=1,
            to_path=f"{os.path.join(REMOTES_DIR, module)}",
            branch=branch,
        )
    else:
        print(f"Error: unsupported type {remotes[module]['type']} for module {module}")


    module_path = os.path.join(REMOTES_DIR, module, remotes[module]["path"])
    return True, module_path
