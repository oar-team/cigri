.. -*- rst-mode -*-

Client tools
============

This chapter describes the client tools available to the users for interacting with the grid. Most of the CLI tools (gridsub, gristat, gridevents, gridnotify,...) have a minimal help that is printed with the -h option.

gridsub
-------

The gridsub command is used for submitting new job campaigns or adding jobs to a running campaign.

gridstat
--------

The gridstat command is used to get informations about the campaigns and the jobs. It may also be used to fetch some output files from the clusters.

gridnotify
----------

This command must be used by users to setup their notification preferences.

gridevents
----------

This command is used to manage the events. It allows listing of the events on a given campaign and fixing. When used to fix events, it may be asked to trig an automatic re-submission.

griddel
-------

This command allows campaign deletion, suspend and resume.

gridclusters
------------

May show useful informations about the clusters: their names, their stress status and usage. It may display colored bargraphs of the current usage of the grid.


.. Local Variables:
.. ispell-local-dictionary: "american"
.. mode: flyspell
.. End:
