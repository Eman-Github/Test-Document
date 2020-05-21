
import sys


def main():
    print('Salaam')
    arg1, arg2, s3 = sys.argv[1], sys.argv[2], sys.argv[3]

    print('Inputs : ', s1, s2, s3)

    import requests
    url = s1

    response = requests.get(url,)
    print("response = ", response)

if __name__ == '__main__':
    main()





