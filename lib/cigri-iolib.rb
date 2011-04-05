require 'cigri-conflib'
require 'cigri-logger'
require 'json'
require 'pp'

# This method saves a new campaign into the cigri database.
# It considers that the JDL has been checked before submitting and is 
# therefore correct.
def cigri_submit(dbh, json, user)
  dbh['AutoCommit'] = false
  pp json
  query = 'INSERT into campaigns (grid_user, 
                                  state, 
                                  type, 
                                  name, 
                                  submission_time, 
                                  jdl)
           VALUES (?, \'in_treatment\', ?, ?, NOW(),  ?)'
  begin
    dbh.do(query, user, json['jobs_type'], json['name'], json.to_json)
  rescue Exception => e
    puts e
    dbh.rollback()
    raise e
  ensure
    dbh['AutoCommit'] = true
  end
end
