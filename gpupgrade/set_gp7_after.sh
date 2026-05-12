source ./unset.sh

source /usr/local/greenplum-db-7.8.0/greenplum_path.sh
export COORDINATOR_DATA_DIRECTORY=/data/master/gpseg-1
export PGPORT=5432

export JAVA_HOME=/usr/local/jdk-11.0.2
export PXF_HOME=/usr/local/pxf-gp7
export PXF_BASE=/usr/local/pxf-gp7
export PXF_CONF=$PXF_BASE/conf
export PATH=$PATH:$PXF_BASE/bin

env | egrep "GP|PG|PXF|DATA_DIRECTORY|PYTHON|JAVA|R_HOME" | sort

##########################################
####### Database alias for Greenplum 7
###########################################
alias qq='psql -c " SELECT datname, now()-query_start as duration_time, usename, client_addr, wait_event, wait_event_type, pid, sess_id, rsgname from pg_stat_activity WHERE state not like '\''%idle%'\'' and sess_id > 0  and pid <> pg_backend_pid() ORDER BY state, duration_time desc, wait_event_type;"'   ##active session
alias qqit='psql  -c "SELECT datname, substring(backend_start::text,1,19) as backend_time, now()-query_start as duration_time, usename, client_addr, wait_event, wait_event_type, pid, sess_id, rsgname, substring(query,1,60) FROM pg_stat_activity as query_string WHERE state <> '\''idle'\'' and sess_id > 0  and pid <> pg_backend_pid() ORDER BY state, duration_time desc, wait_event_type;"'    ## active session with query
