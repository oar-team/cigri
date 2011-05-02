.. -*- rst-mode -*-

Job Description Language (JDL)
==============================

To describe a campaign, we use a Job Description Language (JDL). The
JDL is based on JSON [#]_.

.. [#] See http://www.json.org/ for more information about JSON

The JDL has 2 main parts:

#. The global settings
#. The cluster settings

**Emphasized** values correspond to the default.

Attributes followed by a "*" are mandatory.

Global Settings
---------------

- name*: Name of the campaign
- clusters*: list of the clusters where the campaign should run. See
  `Cluster Settings`_
- param_file: path to the file containing all the parameters to run
  for the campaign
- nb_jobs: number of jobs
- jobs_type: 

  - **normal**: jobs using the param_file or nb_jobs
  - desktop_computing: jobs launched with always the same parameters

- Any field described in `Cluster Settings`_

.. NOTE::

  - If the job_type is not desktop_computing, then one of *param_file*
    or *nb_jobs* is mandatory
  - *nb_jobs* is just syntactic sugar equivalent with a *param_file*
    containing a number from 0 to nb_jobs on each line

Cluster Settings
----------------

Settings in this section can be defined in the global section to act
as value on all clusters.

- campaign_type: Values other than best-effort may require approval
  from platform admins

  - **best-effort**: jobs are executed day and night as best-effort
  - semi-best-effort: jobs are executed as best-effort during the day
    and as normal submissions during the night
  - nightly: jobs are only executed as normal submissions during the
    night
  - normal: jobs are executed as normal submissions during the day and
    the night

- walltime: maximum duration of the jobs

  - **Default** defined in |soft| configuration file

- exec_file*: script to execute
- exec_directory: path to a directory execution.

  - **Default**: $HOME

- resources: resources that are asked to the underlying batch
  scheduler (-l in OAR)
  
  - **Default**: /<resource_unit>=1. Resource_unit is defined per
    cluster and can therefore be different between 2 clusters. Users
    should answer this field.

- prologue: commands that are executed before each job
- epilogue: commands that are executed after each job
- output_gathering_method: method to use to gather results in a single
  place

  - **None**
  - iRods: files will be put in iRods at the end of the execution
  - collector: a collector will pass regularly to gather files
  - scp: a simple scp will be done on the output files after the
    completion

- output_file: file or directory to save
- output_destination: some server (not used with iRods) where output
  files will be gathered

- dimensional_grouping: allow to execute several jobs in parallel in a
  single submission if possible

  - true
  - **false**

- temporal_grouping: allow to execute several jobs one after the other
  in a single submission. The number of jobs is computed automatically
  by |soft|

  - **true**
  - false

- checkpointing_type:
  
  - **None**
  - BLCR
  - ...

.. NOTE::

  - *resources*: if several type of resources are asked, the default
    resources (nodes, cpus, cores, ...) **MUST BE** first. Example:
    "resources": "nodes=3+other_type_of_resource=2"
  - *dimensional_grouping*: enabling this feature will speedup
    execution, however, jobs must not write in common files
  - *dimensional_grouping*: should be activated for jobs requiring a
    small number of resources (typically, one core)
  - *temporal_grouping*: should be activated for short jobs (typically
    less than 5 minutes).
  - output_gathering_method is defined


Example of JDL
--------------

Here is an example of a JDL file described in JSON:

.. include:: ../../modules/jdl-parser/example.json
   :literal: 

.. Local Variables:
.. ispell-local-dictionary: "american"
.. mode: flyspell
.. End:
