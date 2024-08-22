.. -*- rst-mode -*-

=====================
 Admin Documentation
=====================

.. include:: doc_header.rst

:Dedication: For developers and experimenters.

.. section-numbering::
.. contents:: Table of Contents

-------------------------------------------------------------------------------

Installing Cigri
=================

Use the makefile and restart apache:

sudo make install-cigri-server install-cigri-api setup-api install-cigri-user
sudo systemctl restart apache2.service

Setting up OAR API for CiGri
============================

With OAR3, simply install the OAR API. The authentication process is very simple using JWT.

Setting up CIGRI
================

- Set up cigri.conf
- Set up cigri API
- Set up the database
- Insert clusters of the grid
- Map user names if necessary (users_mapping table)

JWT auth
========

With clusters using JWT token authentication, you have to set up an admin token: the admin token is a simple token for the "oar" user on the cluster, which has more privileges than a regular user. Here are the steps to set up this token:

- On the OAR cluster's frontend, sign on as root and do `sudo su - oar`, then `oarsub -T` (you get a token string for the "oar" user)
- On the Cigri's frontend, sign on as root and do `gridtoken -i <id> -t <TOKEN>` with `<id>` replaced by the cigri id of the cluster a,d `<TOKEN>` replaced by the previously generated token string.

Example:
```
bzizou@dahu-oar3:~$ sudo su - oar
oar@dahu-oar3:~$ oarsub -T
OAR_API_TOKEN=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyIjoib2FyIiwiZXhwIjoxNzI0OTI3MDEwLCJkYXRlIjoiMjAyNC0wOC0yMiAxMDoyMzozMCJ9.aB8vGURiOjSBjOqyka8Ee_TigoOYXXXXXXXXXXXXXXXXXXX

root@cigri-dev:~# gridtoken -i 10 -t eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyIjoib2FyIiwiZXhwIjoxNzI0OTI3MDEwLCJkYXRlIjoiMjAyNC0wOC0yMiAxMDoyMzozMCJ9.aB8vGURiOjSBjOqyka8Ee_TigoOYXXXXXXXXXXXXXXXXXXX
New token registered.
root@cigri-dev:~# gridtoken -l
You have the following tokens:
 - Cluster #10 : eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyIjoib2FyIiwiZXhwIjoxNzI0OTI3MDEwLCJkYXRlIjoiMjAyNC0wOC0yMiAxMDoyMzozMCJ9.aB8vGURiOjSBjOqyka8Ee_TigoOYXXXXXXXXXXXXXXXXXXX
root@cigri-dev:~# 
```

Then, each users that want to use this cluster also have to set up a token for themselves to be able to submit jobs.

Starting up CIGRI
=================

su - cigri -c "/usr/local/share/cigri/modules/almighty.rb"

Troubleshooting
===============

Testing job submission through cigri code
-----------------------------------------

You can test job submission as root with the command line tool "grid_test_cluster".

For example, create a file containing a ruby hash definition of a job:::

  root@cigri3-test:~# cat testjob 
  {"resources"=>"resource_id=1,walltime=3600", "command"=>"sleep 300", "property"=>"", "project"=>"admin"}

Then, submit it with the test tool:::

  root@cigri3-test:~# grid_test_cluster -c gofree -u bzizou -f testjob 
  Id: 1517940
  State: Waiting

Testing job submission on a OAR api from the cigri host
-------------------------------------------------------

At least, for cigri to work, you should be able to submit a job over the OAR API of a cluster. To isolate problems, you may have to check if the problem is cigri related or not. You can use curl to test a job submission on a OAR cluster, so that if it fails, you'll know that it is not a Cigri problem. Here is an example::

  root@cigri3-test:~# curl -i -X POST https://froggy/oarapi/jobs.json -H'Content-Type: application/json' -H'X-REMOTE-IDENT: bzizou' -d '{"resource":"/nodes=1,walltime=00:10:00", "script_path":"\"sleep 600\""}' --cert /etc/cigri/ssl/cigri.crt --key /etc/cigri/ssl/cigri.key  --insecure

.. Local Variables:
.. ispell-local-dictionary: "american"
.. mode: flyspell
.. End:
