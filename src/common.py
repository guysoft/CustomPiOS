""" Common functions between CustomPiOS python scripts"""
from typing import Dict, Any, Optional, cast
import yaml
import os

IMAGES_CONFIG = os.path.join(os.path.dirname(__file__), "images.yml")

def read_images():
    if not os.path.isfile(IMAGES_CONFIG):
        raise Exception(f"Error: Remotes config file not found: {IMAGES_CONFIG}")
    with open(IMAGES_CONFIG,'r') as f:
        output = yaml.safe_load(f)
        return output

def get_image_config() -> Optional[Dict["str", Any]]:
    images = read_images()

    base_board = os.environ.get("BASE_BOARD", None)
    base_image_path = os.environ.get("BASE_IMAGE_PATH", None)

    if base_board is not None and base_board in images["images"]:
        return images["images"][base_board]
    return None
