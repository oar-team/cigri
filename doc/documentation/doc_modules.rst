Modules Description
===================

|soft| is divided in several independent modules. Each module has a
specific unique role. This section depicts the roles of the different
modules.

Columbo
-------

This modules investigates problems.

It can:

- Detect infinite resubmissions
- ...

Monitoring
----------

Updates the database with new info


Spritz
------

Sptitz (reference to David Spritz, the weather man) computes metrics
on jobs such as average duration, throughput, ... With these values it
is able to give a forecast of what should happen in the future.

Scheduler
---------

Decide what to execute and where.

Runner
------

This module is dedicated to launching jobs on the clusters. It reads
the jobs to launch from the database table *jobs_to_launch* and
submits them to the API lib.

Nikita
------

Deletes jobs that should be killed 

Almighty
--------

Almighty is the central component of |soft|. It is a coordinator as it
chooses what other module to launch. 

Modules are launched in this order:

#. module 1
#. module 2 

Collector
---------

Gathers data in a specific location.

JDL_parser
----------

The JDL parser module is used to parse and save when a new campaign is
submitted.
