require 'cigri-conflib'
require 'cigri-logger'
require 'cigri-utils'
require 'json'

CONF = Cigri.conf
LOGGER = Cigri::Logger.new('IOLIB', CONF.get('LOG_FILE'))

# This method saves a new campaign into the cigri database.
# It considers that the JDL has been checked before submitting and is 
# therefore correct.
#
# == Parameters
# - dbh: database handle
# - json: expended json corresponding to JDL
# - user: username in the daatabase
# 
def cigri_submit(dbh, json, user)
  dbh['AutoCommit'] = false
  begin
    LOGGER.debug('Saving campaign into database')
    query = 'INSERT into campaigns 
             (grid_user, state, type, name, submission_time, jdl)
             VALUES (?, \'in_treatment\', ?, ?, NOW(),  ?)'
    dbh.do(query, user, json['jobs_type'], json['name'], json.to_json)
    campaign_id = last_inserted_id(dbh, 'campaigns_id_seq')
    dbh.commit()
  rescue Exception => e
    LOGGER.error('Error ruing campaign submission: ' + e.message)
    dbh.rollback()
    raise e
  ensure
    dbh['AutoCommit'] = true
  end
end
