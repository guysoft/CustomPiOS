import os
import yaml
from pathlib import Path
from typing import Tuple, Optional
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

def get_remote_module(module) -> Tuple[bool, Optional[str]]:
    """ Gets the remote module and saves it to cache. Returns True if found, else false"""
    print(f'INFO: Module "{module}", looking for remote module and downloading')
    modules_remotes = read_remotes()
    print(modules_remotes.keys())
    
    if "modules" not in modules_remotes.keys() and module not in modules_remotes["modules"].keys():
        return False, None
    
    ensure_dir(REMOTES_DIR)
    
    if "remotes" not in modules_remotes.keys() or module not in modules_remotes["modules"].keys():
        return False, None
    
    module_config = modules_remotes["modules"][module]
    
    remote_for_module = module_config["remote"]
    remote_config = modules_remotes["remotes"][remote_for_module]
    
    if remote_config.get("type", "git") == "git":
        if "repo" not in remote_config.keys():
            print(f'Error: repo field not set for remote: "{remote_for_module}" used by remote module "{module}"')
            return False, None
        
        if "tag" not in remote_config.keys():
            print(f'Error: repo tag field not set for remote: "{remote_for_module}" used by remote module "{module}"')
            return False, None
            
        repo_url = remote_config["repo"]
        branch = remote_config["tag"]
        
        # credentials = base64.b64encode(f"{GHE_TOKEN}:".encode("latin-1")).decode("latin-1")
        # TODO: Handle update of remote
        remote_to_path = os.path.join(REMOTES_DIR, remote_for_module)
        if not os.path.exists(remote_to_path):
            git.Repo.clone_from(
                url=repo_url,
                single_branch=True,
                depth=1,
                to_path=f"{remote_to_path}",
                branch=branch,
            )
            
        if "path" not in module_config.keys():
            print(f"Error: repo tag field not set for remote: {remote_for_module} used by remote module {module}")
            return False, None
        module_path = os.path.join(remote_to_path, module_config["path"])
        return True, module_path

    else:
        print(f"Error: unsupported type {remotes[module]['type']} for module {module}")
        return False, None
    return False, None
