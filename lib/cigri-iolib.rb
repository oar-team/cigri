require 'cigri-conflib'
require 'pp'

# This method saves a new campaign into the cigri database.
# It considers that the JDL has been checked before submitting and is 
# therefore correct.
def cigri_submit(dbh, json, user)
pp json
puts  "INSERT into campaigns VALUES (123, #{user}, IN_TREATMENT, #{json['type']}"
end
