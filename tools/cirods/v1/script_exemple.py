from cirods import *



# Get file from the collection testbash
        
Get_file_from_collection("/cigri/home/radhoane/testbash")

# Function Query return a list of file

#requete = "(([test2,=,1,d] AND [test2,n<,2,d]) AND [test2,n<,4,d]) OR ([test2,n<,10,d] AND [test2,n<,5,d])"
#List = Query(requete,"/cigri/home/radhoane/%","out")

#The list of file retunr by Query can be download by the function Get_file_From_list at the repertory "/home/radhoane/test"

#Get_file_From_list(List,"/home/radhoane/test")

# We can also donwload file with the outfile create by the function query.

#Get_file_From_file("out","/home/radhoane/test2")


