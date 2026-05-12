source ./unset.sh

source /usr/local/greenplum-db/greenplum_path.sh
source /usr/local/greenplum-cc/gpcc_path.sh
source /data/gpkrutil/gpkrutil_path.sh
export MASTER_DATA_DIRECTORY=/data/master/gpseg.MtA_VLhleLE.-1.old
export PGDATABASE=gpkrtpch
export PGPORT=5432

export JAVA_HOME=/usr/local/jdk-11.0.2
export PXF_BASE=/usr/local/pxf-gp6
export PXF_CONF=$PXF_BASE/conf
export PATH=$PATH:$PXF_BASE/bin

env | egrep "GP|PG|PXF|DATA_DIRECTORY|PYTHON|JAVA" | sort

##########################################
####### Database alias for Greenplum 6
###########################################

###########################
####### DB session
###########################
alias qq='psql -c " SELECT datname, now()-query_start as duration_time, usename, client_addr, waiting, pid, sess_id, rsgname from pg_stat_activity WHERE state not like '\''%idle%'\'' ORDER BY waiting, duration_time desc;"'   ##active session
alias qqit='psql  -c "SELECT datname, substring(backend_start::text,1,19) as backend_time, now()-query_start as duration_time, usename, client_addr, waiting, waiting_reason, pid, sess_id, rsgname, substring(query,1,60) FROM pg_stat_activity as query_string WHERE state <> '\''idle'\'' ORDER BY waiting, duration_time desc;"'    ## active session with query
