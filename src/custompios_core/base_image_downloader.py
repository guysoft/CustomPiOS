#!/usr/bin/env python3
import argparse
import yaml
import os
import urllib.request
import tempfile
import hashlib
import shutil
import re
import urllib.parse
from enum import Enum, auto
from typing import Dict, Any, Optional, cast, Tuple
from common import get_image_config, read_images
PRECENT_PROGRESS_SIZE = 5

class ChecksumType(Enum):
    URL = auto() # a url for the checksum file
    STRING = auto() # A string in the format "checksum filename"

class ChecksumFailException(Exception):
    pass

RETRY = 3

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


def download_webpage(url: str) -> Optional[str]:
    try:
        with urllib.request.urlopen(url) as response:
            # Decode the response to a string
            webpage = response.read().decode('utf-8')
            return webpage
    except Exception as e:
        print(str(e))
        return None

def get_location_header(url: str) -> str:
    try:
        with urllib.request.urlopen(url) as response:
            response_url = response.url

            if response_url is None:
                raise Exception("Location header is None, can't determine latest rpi image")
            return response_url
    except Exception as e:
        print(str(e))
        print("Error: Failed to determine latest rpi image")
        raise e
        
        
class DownloadProgress:
    last_precent: float = 0
    def show_progress(self, block_num, block_size, total_size):
        new_precent = round(block_num * block_size / total_size * 100, 1)
        if new_precent > self.last_precent + PRECENT_PROGRESS_SIZE:
            print(f"{new_precent}%", end="\r")
            self.last_precent = new_precent

def get_file_name(headers, url):
    if "Content-Disposition" in headers.keys():
        return re.findall("filename=(\S+)", headers["Content-Disposition"])[0]
    return url.split('/')[-1]

def get_sha256(filename):
    sha256_hash = hashlib.sha256()
    with open(filename,"rb") as f:
        for byte_block in iter(lambda: f.read(4096),b""):
            sha256_hash.update(byte_block)
        file_checksum = sha256_hash.hexdigest()
        return file_checksum
    return

def download_image_http(board: Dict[str, Any], dest_folder: str):
    url = board["url"]
    checksum = board["checksum"]
    download_http(url, checksum, dest_folder)

def download_http(url: str, checksum_argument: str, dest_folder: str, checksum_type: ChecksumType = ChecksumType.URL):
    with tempfile.TemporaryDirectory() as tmpdirname:
        print('created temporary directory', tmpdirname)
        temp_file_name = os.path.join(tmpdirname, "image.xz")
        temp_file_checksum = os.path.join(tmpdirname, "checksum.sha256")

        for r in range(RETRY):
            try:
                # Get sha and confirm its the right image
                download_progress = DownloadProgress()

                # We need to get the checksum as one of ChecksumType enum, the result goes in to online_checksum
                online_checksum = None
                if checksum_type == ChecksumType.URL:
                    _, headers_checksum = urllib.request.urlretrieve(checksum_argument, temp_file_checksum, download_progress.show_progress)
                    file_name_checksum = get_file_name(headers_checksum, checksum_argument)

                    checksum_data = None
                    with open(temp_file_checksum, 'r') as f:
                        checksum_data = f.read()

                    checksum_data_parsed = [x.strip() for x in checksum_data.split()]
                    
                elif checksum_type == ChecksumType.STRING:
                    checksum_data_parsed = checksum_argument.split(" ")
                else:
                    print("Error: provided a non-existant checksum type")
                    exit(1)
                online_checksum = checksum_data_parsed[0]
                file_name_from_checksum = checksum_data_parsed[1]
                dest_file_name = os.path.join(dest_folder, file_name_from_checksum)
                print(f"Downloading {dest_file_name} from {url}")

                if os.path.isfile(dest_file_name):
                    file_checksum = get_sha256(dest_file_name)
                    if file_checksum == online_checksum:
                        print("We got base image file and checksum is right")
                        return
                # Get the file
                download_progress = DownloadProgress()
                _, headers = urllib.request.urlretrieve(url, temp_file_name, download_progress.show_progress)
            
                file_name = get_file_name(headers, url)
                file_checksum = get_sha256(temp_file_name)
                if file_checksum != online_checksum:
                    print(f'Failed. Attempt # {r + 1}, checksum missmatch: {file_checksum} expected: {online_checksum}')
                    continue
                ensure_dir(os.path.dirname(dest_file_name))
                shutil.move(temp_file_name, dest_file_name)

            except Exception as e:
                if r < 2:
                    print(f'Failed. Attempt # {r + 1}, got: {e}')
                else:
                    print('Error encoutered at {RETRY} attempt')
                    print(e)
                    exit(1)
            else:
                print(f"Success: {temp_file_name}")
                break
    return


def download_image_rpi(board: Dict[str, Any], dest_folder: str):
    port = board.get("port", "lite_armhf")
    os_name = f"raspios"
    distribution = board.get("distribution", "bookworm")
    version_file = board.get("version_file", "latest")
    version_folder = board.get("version_folder", "latest")

    latest_url = f"https://downloads.raspberrypi.org/{os_name}_{port}_latest"

    download_url = f"https://downloads.raspberrypi.org/{os_name}_{port}/images/{os_name}_{port}-{version_folder}/{version_file}-{os_name}-{distribution}-{port}.img.xz"
    if version_file == "latest" or version_folder == "latest":
        download_url = get_location_header(latest_url)
    
    checksum_url = f"{download_url}.sha256"
    download_http(download_url, checksum_url, dest_folder)
    return

def get_checksum_libre_computer(os_name: str, os_version: str, file_name: str) -> Optional[str]:
    checksum_url = f"https://distro.libre.computer/ci/{os_name}/{os_version}/SHA256SUMS"
    checksum_files_data = download_webpage(checksum_url)
    for line in checksum_files_data.splitlines():
        checksum, name = line.split(maxsplit=1)
        print(name)
        if name == file_name:
            return f"{checksum} {file_name}"
    return None


def download_image_libre_computer(board: Dict[str, Any], dest_folder: str):
    # URL example: https://distro.libre.computer/ci/raspbian/12/2023-10-10-raspbian-bookworm-arm64%2Baml-s905x-cc.img.xz
    # URL example: https://distro.libre.computer/ci/debian/12/debian-12-base-arm64%2Baml-s905x-cc.img.xz
    port = board.get("port", "base")
    arch = board.get("arch", "arm64+aml")
    distribution = board.get("distribution", "bookworm")
    os_name = board.get("os_name", "debian")
    os_version = board.get("os_version", "12")
    board = "s905x-cc"

    # download_url = f"https://downloads.raspberrypi.org/{os_name}_{port}/images/{os_name}_{port}-{version_folder}/{version_file}-{os_name}-{distribution}-{port}.img.xz"
    file_name = None
    if os_name == "debian":
        file_name = f"{os_name}-{os_version}-{port}-{arch}-{board}.img.xz"
        download_url = f"https://distro.libre.computer/ci/{os_name}/{os_version}/{urllib.parse.quote(file_name)}"
    elif os_name == "raspbian":
        download_url = f"https://distro.libre.computer/ci/{os_name}/{os_version}/{urllib.parse.quote(file_name)}"
    checksum = get_checksum_libre_computer(os_name, os_version, file_name)
    if checksum is None:
        print(f"Error: Can't find the correct checksum for {file_name}")
        exit(1)
    
    download_http(download_url, checksum, dest_folder, ChecksumType.STRING)
    return

if __name__ == "__main__":
    parser = argparse.ArgumentParser(add_help=True, description='Download images based on BASE_BOARD and BASE_O')
    parser.add_argument('WORKSPACE_SUFFIX', nargs='?', default="default", help="The workspace folder suffix used folder")
    parser.add_argument('-s', '--sha256', action='store_true', help='Create a sha256 hash for the .img file in .sha256')
    args = parser.parse_args()
    
    images = read_images()

    base_board = os.environ.get("BASE_BOARD", None)
    base_image_path = os.environ.get("BASE_IMAGE_PATH", None)

    if base_image_path is None:
        print(f'Error: did not find image config file')
        exit(1)
    cast(str, base_image_path)

    image_config = get_image_config()
    if image_config is not None:
        if image_config["type"] == "http":
            print(f"Downloading image for {base_board}")
            download_image_http(image_config, base_image_path)
            download_image_http(image_config, base_image_path)
        elif image_config["type"] == "rpi":
            print(f"Downloading Raspberry Pi image for {base_board}")
            download_image_rpi(image_config, base_image_path)
        elif image_config["type"] == "libre.computer":
            print(f"Downloading image for {base_board}")
            download_image_libre_computer(image_config, base_image_path)
        elif image_config["type"] == "torrent":
            print("Error: Torrent not implemented")
            exit(1)
        else:
            print(f'Error: Unsupported image download type: {image_config["type"]}')
            exit(1)
    else:
        print(f"Error: Image config not found for: {base_board}")
        exit(1)

    
    print("Done")
