import argparse

def get_choices():
    return ['rock', 'paper', 'scissors']

def main():
    parser = argparse.ArgumentParser(add_help=True, description='Build mulitple images for multiple devices')
    parser.add_argument('--list', "-l", choices=get_choices(), type=str, nargs='+')
    args = parser.parse_args()
    print(args.list)
    print("Done")
    return

if __name__ == "__main__":
    main()