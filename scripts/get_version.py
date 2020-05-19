
import sys


def main():
    if sys.argv[0] == 'hi':
        print('Salaam')
        print ("exec main..")
        sys.stderr.write('execution ok\n')
        sys.exit(0)
    return "execution ok"

if __name__ == '__main__':
    main()





