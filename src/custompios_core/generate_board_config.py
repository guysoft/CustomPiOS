#!/usr/bin/python3
import os
import yaml
from pathlib import Path
from typing import Tuple, Optional, Dict, Any, cast
import git
from git import RemoteProgress
from common import get_image_config
import argparse
import sys

if __name__ == "__main__":
    parser = argparse.ArgumentParser(add_help=True, description='Create an export shell script to use the yaml-configured variables')
    parser.add_argument('output_script', type=str, help='path to output the chroot script master')
    args = parser.parse_args()
    image_config = get_image_config()
    if image_config is None:
        print("Error: Could not get image config")
        sys.exit(1)
    cast(Dict[str,Any], image_config)
    if not "env" in image_config.keys():
        print("Warning: no env in image config")
        exit()
    env = image_config["env"]
    with open(args.output_script, "w+") as w:
        for key in env.keys():
            w.write(f'export {key}="{env[key]}"\n')
        
