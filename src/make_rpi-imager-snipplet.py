#!/usr/bin/env python3
import json
import zipfile
import hashlib
import os
import argparse
from datetime import date
import glob


if __name__ == "__main__":
    parser = argparse.ArgumentParser(add_help=True, description='Create a json snipplet from an image to be used with the make_rpi-imager_list.py and eventually published in a repo')
    parser.add_argument('workspace_suffix', nargs='?', default="default", type=str, help='Suffix of workspace folder')
    parser.add_argument('-u', '--rpi_imager_url', type=str, default="MISSING_URL", help='url to the uploaded image url')
    
    args = parser.parse_args()
    
    workspace_path = os.path.join(os.getcwd(), "workspace")
    if args.workspace_suffix != "" and args.workspace_suffix != "default":
        workspace_path += "-" + args.workspace_suffix
    
    name = os.environ["RPI_IMAGER_NAME"]
    description = os.environ["RPI_IMAGER_DESCRIPTION"]
    url = args.rpi_imager_url
    icon = os.environ["RPI_IMAGER_ICON"]
    release_date = date.today().strftime("%Y-%m-%d")
    zip_local = glob.glob(os.path.join(workspace_path,"*.zip"))[0]
    img_sha256_path = glob.glob(os.path.join(workspace_path,"*.img.sha256"))[0]
    img_sha256 = ""
    with open(img_sha256_path, 'r') as f:
        img_sha256 = f.read().split()[0]
        
    output_path = os.path.join(workspace_path, "rpi-imager-snipplet.json")
    
    json_out = {"name": name,
                "description": description,
                "url": url,
                "icon": icon,
                "release_date": release_date,
                }
    json_out["extract_size"] = None
    with zipfile.ZipFile(zip_local) as zipfile:
        json_out["extract_size"] = zipfile.filelist[0].file_size
    
    json_out["extract_sha256"] = None
    json_out["image_download_size"] = os.stat(zip_local).st_size
    json_out["image_download_sha256"] = img_sha256
    
    with open(zip_local,"rb") as f:
        json_out["image_download_sha256"] = hashlib.sha256(f.read()).hexdigest()
    
    with open(output_path, "w") as w:
        json.dump(json_out, w, indent=2)
    
    print("Done generating rpi-imager json snipplet")
