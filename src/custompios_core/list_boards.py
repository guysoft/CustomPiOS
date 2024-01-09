#!/usr/bin/python3
from common import read_images

if __name__ == "__main__":
    images = read_images()["images"]
    print("Available board targest for --board are:")
    for key in sorted(images):
        if "description" in images[key].keys():
            print(f'{key} - {images[key]["description"]}')
        else:
            print(key)
