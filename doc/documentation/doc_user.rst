.. -*- rst-mode -*-

====================
 User Documentation
====================

.. include:: doc_header.rst

:Dedication: For users.

.. section-numbering::
.. contents:: Table of Contents

-------------------------------------------------------------------------------

Cigri Tour
===========

General Presentation
--------------------

Cigri is a campaign management tool. It is design to run on top of
multiple clusters each managed by a batch scheduler.

Campaigns
---------

A campaign is a set of jobs that have to be executed. In our context,
we consider that all the jobs in a campaign are similar. In other
terms, all the jobs of a campaign use the same executable with
different parameters. It can be the same program executed repetitively
with different parameters. A typical Monte-Carlo campaign using a seed
for its random generator could be schematized by: ::

  for i in 0..1 000 000
    program.exe i
  end

Cigri Features
---------------

Cigri includes many features including but not limited to:

- Multiple campaigns management
- Multiple users
- Different campaigns types
- Automatic resubmission

TODO

Campaigns types
---------------

Cigri distinguishes 4 different types of campaigns:

- **Normal** campaigns: with this type of campaigns, Cigri submits
  jobs to the batch schedulers. Normal campaigns are the best for the
  users because the jobs are assured to have the requested
  time. However, because the first role of Cigri is to use idle
  resources with minimum impact on the other users, this type of
  campaign will most likely require an authorization from the admins.

- **Best-effort** campaigns: this type of campaigns submits jobs in a
  best-effort mode to the batch scheduler. This means that when
  resources are needed by a non best-effort job, the campaign job will
  be killed and will have to be resubmitted later. This type of
  campaign can take advantage of idle resources while not disturbing
  the platform. However, due to the likeliness that jobs may be
  killed, it is better is jobs are small or checkpointable.

- **Semi-best-effort** campaigns: the semi-best-effort campaign is a
  mix of the two previous policies. During the day, jobs are submitted
  in a best-effort mode and during the night, normal submissions are
  used. This ensures that jobs execution progresses during the night.

- **Nightly** campaigns: for some kind of jobs (long and parallel ones
  for example) trying to execute jobs is a best-effort mode has no
  purpose as they will get killed most of the time. Resources would
  just be wasted. Therefore, for this kind of jobs, it is better only
  to use normal submissions during the night in order to let resources
  to the other users of the platform during the day. 

.. include:: doc_jdl.rst

.. include:: doc_api.rst

.. include:: ../../CHANGELOG

.. Local Variables:
.. ispell-local-dictionary: "american"
.. mode: flyspell
.. End:
