#!/usr/bin/env bash
#
# CIGRI garbage collector
# Must be ran as root

cd /tmp
su postgres -c "psql cigri3 -c \"update jobs set state='event' from campaigns where (jobs.state='submitted' or jobs.state='running') and campaigns.state='cancelled' and campaigns.id=jobs.campaign_id;\""
