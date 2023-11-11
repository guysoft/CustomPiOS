#!/usr/bin/env python3
import argparse
import yaml
import os
import urllib.request
import tempfile
import hashlib
import shutil
import re
PRECENT_PROGRESS_SIZE = 5

class ChecksumFailException(Exception):
    pass

IMAGES_CONFIG = os.path.join(os.path.dirname(__file__), "images.yml")
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

def read_images():
    if not os.path.isfile(IMAGES_CONFIG):
        raise Exception(f"Error: Remotes config file not found: {IMAGES_CONFIG}")
    with open(IMAGES_CONFIG,'r') as f:
        output = yaml.safe_load(f)
        return output

class DownloadProgress:
    last_precent: float = 0
    def show_progress(self, block_num, block_size, total_size):
        new_precent = round(block_num * block_size / total_size * 100, 1)
        if new_precent > self.last_precent + PRECENT_PROGRESS_SIZE:
            print(f"{new_precent}%", end="\r")
            self.last_precent = new_precent

def get_file_name(headers):
    return re.findall("filename=(\S+)", headers["Content-Disposition"])[0]

def get_sha256(filename):
    sha256_hash = hashlib.sha256()
    with open(filename,"rb") as f:
        for byte_block in iter(lambda: f.read(4096),b""):
            sha256_hash.update(byte_block)
        file_checksum = sha256_hash.hexdigest()
        return file_checksum
    return

def download_image_http(board: str, dest_folder: str, redownload: bool = False):
    url = board["url"]
    checksum = board["checksum"]

    with tempfile.TemporaryDirectory() as tmpdirname:
        print('created temporary directory', tmpdirname)
        temp_file_name = os.path.join(tmpdirname, "image.xz")
        temp_file_checksum = os.path.join(tmpdirname, "checksum.sha256")

        for r in range(RETRY):
            try:
                # Get sha and confirm its the right image
                download_progress = DownloadProgress()
                _, headers_checksum = urllib.request.urlretrieve(checksum, temp_file_checksum, download_progress.show_progress)
                file_name_checksum = get_file_name(headers_checksum)

                checksum_data = None
                with open(temp_file_checksum, 'r') as f:
                    checksum_data = f.read()

                checksum_data_parsed = [x.strip() for x in checksum_data.split()]
                online_checksum = checksum_data_parsed[0]
                file_name_from_checksum = checksum_data_parsed[1]
                dest_file_name = os.path.join(dest_folder, file_name_from_checksum)
                print(f"Downloading {dest_file_name}")

                if os.path.isfile(dest_file_name):
                    file_checksum = get_sha256(dest_file_name)
                    if file_checksum == online_checksum:
                        # We got file and checksum is right
                        return
                # Get the file
                download_progress = DownloadProgress()
                _, headers = urllib.request.urlretrieve(url, temp_file_name, download_progress.show_progress)
            
                file_name = get_file_name(headers)                        
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
            else:
                print(f"Success: {temp_file_name}")
                break
    return

if __name__ == "__main__":
    parser = argparse.ArgumentParser(add_help=True, description='Download images based on BASE_BOARD and BASE_O')
    parser.add_argument('WORKSPACE_SUFFIX', nargs='?', default="default", help="The workspace folder suffix used folder")
    parser.add_argument('-s', '--sha256', action='store_true', help='Create a sha256 hash for the .img file in .sha256')
    args = parser.parse_args()
    
    images = read_images()

    base_board = os.environ.get("BASE_BOARD", None)
    base_image_path = os.environ.get("BASE_IMAGE_PATH", None)

    if base_board is not None and base_board in images["images"]:
        if images["images"][base_board]["type"] == "http":
            download_image_http(images["images"][base_board], base_image_path)
        elif images["images"][base_board]["type"] == "torrent":
            print("Error: Torrent not implemented")
            exit(1)
        else:
            print("Error: Unsupported image download type")
            exit(1)
    
    print("Done")