.. -*- rst-mode -*-

REST API
========

Cigri offers a REST API accessible through HTTP.

URLs
----

=========== ======================================= ==========================================================
HTTPrequest URL                                     Purpose
=========== ======================================= ==========================================================
GET         /                                       List the available links
GET         /campaigns                              List of all running campaigns
GET         /campaigns/<campaign_id>                Get details on a specific campaign
GET         /campaigns/<campaign_id>/jobs           List all jobs of a specific campaign
GET         /campaigns/<campaign_id>/jobs/<job_id>  Get details of a specific job of a specific campaign
GET         /clusters                               List all clusters available in Cigri
GET         /clusters/<cluster_id>                  Get details on a specific cluster
POST        /campaigns                              Submit a new campaign
PUT         /campaigns/<campaign_id>                Update a campaign (status, name)
DELETE      /campaigns/<campaign_id>                Delete a campaign
=========== ======================================= ==========================================================

Accessing the API
-----------------

Getting the links available on the server::

  $ curl http://api-host:port
  {"links":[{"href":"/","rel":"self"},{"href":"/campaigns","title":"campaigns","rel":"campaigns"},{"href":"/clusters","title":"clusters","rel":"clusters"}]}

When posting a campaign, the JSON containing the ID of the submitted campaign is returned::

  $ curl -X POST http://api-host:port/campaigns -d '{"name":"n", "nb_jobs":0,"clusters":{"fukushima":{"exec_file":""}}}'
  {"id":"585","links":[{"href":"/campaigns/585","rel":"self"},{"href":"/campaigns","rel":"parent"}]}

Return codes
------------

Each action done through the API will return a code in the HTTP header. The list of the codes is described here:

==== ======================= ====================================================
Code HTTPrequest             Meaning
==== ======================= ====================================================
200  GET                     Request successful: everything went well :)
201  POST                    Resource created: the campaign has been submitted
202  PUT                     Accepted: modifications done
400  POST, PUT               Bad request: see the body of the answer for details
403  POST, PUT, DELETE       Forbidden: see response for details
404  GET, POST, PUT, DELETE  Page not found: the URL does not exist
==== ======================= ====================================================

Exemples::

  $ curl -i http://api-host:port
    HTTP/1.1 200 OK 
  $ curl -i -X DELETE http://api-host:port/campaigns/1
    HTTP/1.1 403 Forbidden 
  $ curl -i -X POST http://api-host:port/campaigns -d '{"name":"n", "nb_jobs":2,"clusters":{"cluster1":{"exec_file":"toto.sh"}}}'
    HTTP/1.1 201 Created 

API options
-----------

Some options can be passed in the URL:

- **pretty**: Will display the answered JSON in a more readable format (but larger). Only not giving the option or putting it to false will disable it::

  $ curl http://api-host:port?pretty => pretty print on
  $ curl http://api-host:port?pretty=true => pretty print on
  $ curl http://api-host:port?pretty=whatever => pretty print on
  $ curl http://api-host:port => pretty print off
  $ curl http://api-host:port?pretty=false => pretty print off


- **action={delete,update}**: Instead of using a DELETE or a PUT request, you can use a POST request with action. The action can be passed in the URL directly or in the POST values::

  $ curl -X POST http://api-host:port/campaigns/1 -d "action=delete"
    => $ curl -X DELETE http://api-host:port/campaigns/1

  $ curl -X POST http://api-host:port/campaigns/1?action=update -d "name=TOTO; state=paused"
    => curl -X PUT http://api-host:port/campaigns/569 -d "name=TOTO"

.. Local Variables:
.. ispell-local-dictionary: "american"
.. mode: flyspell
.. End:
