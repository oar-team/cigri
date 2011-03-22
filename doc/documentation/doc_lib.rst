Libraries Description
=====================

Different libraries may be used by |soft| components. 

iolib
-----

Library handling all interractions with the |soft| database. It
provides a connection method that gives a database handle, and many
useful queries.

clusterlib
----------

Generic library handling communications with the batch schedulers. By
default, it communicates with the OAR 2.5 API, but it should be able
to communicate with other APIs as well.

Methods offered by this library include the querying of the batch
scheduler to obtain info about resources and jobs. The library also
provides methods to submit jobs to the batchs.

apilib
------

Library handling the |soft| API that serves REST queries.
