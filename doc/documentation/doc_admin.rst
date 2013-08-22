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

Use the makefile.

TODO

Setting up OAR API for CiGri
============================

- Create an ssl configuration
TODO
- Disable ident by default, and activate it only for <Location /oarapi> if necessary
TODO
- Create a client certificate 
TODO

Setting up CIGRI
================

- Set up cigri.conf
TODO
- Set up cigri API
TODO
- Set up the database
TODO
- Insert clusters of the grid
TODO
- Map user names if necessary (users_mapping table)
TODO
- Start cigri

Troubleshooting
===============

You can test job submission as root with the command line tool "grid_test_cluster".

For example, create a file containing a ruby hash definition of a job:::

  root@cigri3-test:~# cat testjob 
  {"resources"=>"resource_id=1,walltime=3600", "command"=>"sleep 300", "property"=>"", "project"=>"admin"}

Then, submit it with the test tool:::

  root@cigri3-test:~# grid_test_cluster -c gofree -u bzizou -f testjob 
  Id: 1517940
  State: Waiting

.. Local Variables:
.. ispell-local-dictionary: "american"
.. mode: flyspell
.. End:
