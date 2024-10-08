Cigri Changelog
===============

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
