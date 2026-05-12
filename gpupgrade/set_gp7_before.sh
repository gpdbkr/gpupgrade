source ./unset.sh

### Modify while upgrading. 
source /usr/local/greenplum-db-7.8.0/greenplum_path.sh
export COORDINATOR_DATA_DIRECTORY=/data/master/gpseg.6dut3amendo.-1
export PGPORT=50432

###
export JAVA_HOME=/usr/local/jdk-11.0.2
export PXF_HOME=/usr/local/pxf-gp7
export PXF_BASE=/usr/local/pxf-gp7
export PXF_CONF=$PXF_BASE/conf
export PATH=$PATH:$PXF_BASE/bin

env | egrep "GP|PG|PXF|DATA_DIRECTORY|PYTHON|JAVA" | sort
