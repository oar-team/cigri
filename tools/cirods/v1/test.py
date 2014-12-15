import sys
from cirods import *


if __name__ == "__main__":

    try:
        Jsonfile =sys.argv[1]
    except:
            print "error argument"
            exit(2)
    print "extraction en cours "
    Add_Meta_From_JsonList(Jsonfile)

