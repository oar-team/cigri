Modules Description
===================

Cigri is divided in several independent modules. Each module has a
specific unique role. This section depicts the roles of the different
modules.

Runner
------

This module is dedicated to launching jobs on the clusters. It reads
the jobs to launch from the database table *jobs_to_launch* and
submits them to the API lib.

Almighty
--------

Almighty is the central component of cigri. It is a coordinator as it
chooses what other module to launch. 

Modules are launched in this order:

#. module 1
#. module 2 


JDL_parser
----------

The JDL parser module is used to parse and save when a new campaign is
submitted.
