Cigri Changelog
===============

version 3.2.3
-------------

Unreleased

- Fixed OAR_AUTO_RESUBMIT event that loses the resubmitted job
- Added a EVENTS_DELAY for OAR to record an event before Cigri considers an UNKWON_ERROR
- Fixed besteffort type not working for OAR3
- New script to help token renewal: gridtoken-renew.sh
- Fixed REMOTE_WAITING_TIMEOUT that could loose some jobs
- Added an exception handling when job submission fails to no jobs returned
- Resubmitted jobs when fixing events are resubmitted preferably on another cluster
- Added case for SEND_KILL_JOB (new in oar3?)

version 3.2.2
-------------

Released 2025-01-08

- Fixed a PostgreSQL connection issues (too many ressources used due to dirty unclosed connections)
- Fixed PostgreSQL connection issues into the Updator with forked children
- Reduced error probability for 'prepared statement "stmt_id" does not exist'
- Fixed NIKITA garbage with some remotewaiting jobs not killed

version 3.2.1
-------------

Released 2024-09-23

- Added DATABASE_SSL_MODE config variable ("require" by default)
- Added pagination for OAR3 API
- Fixed systemd startup script
- Fixed notifications
- Fixed OAR_AUTO_RESUBMIT events (resubmit id could be missed)
- Fixed gridstat -f
- Fixed gridstat -j <id>

version 3.2.0
-------------

Released 2024-09-04

- Updated to be able to run with latest ruby version (tested with ruby 3.1.2)
- Adapted to use rdbi in place of obsolete ruby-dbi DB interface
- Added OAR3 support
- Added JWT token auth support
- Finished experimental "temporal grouping" running option
- Misc fixes and enhancements
- More functional tests

version 3.1
-----------

Released 2024-06-12

- Production release (12 years of active services), but needs old ruby 2.x version to run

version 3.0
-----------

Released in 2013

 - Ruby version of CiGri

version 2.x
-----------
 - Perl version of Cigri
