.. -*- rst-mode -*-

REST API
========

Cigri offers a REST API accessible through HTTP.

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


.. Local Variables:
.. ispell-local-dictionary: "american"
.. mode: flyspell
.. End:
