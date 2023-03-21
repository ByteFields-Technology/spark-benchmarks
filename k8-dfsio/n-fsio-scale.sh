

export TESTHOME=$(dirname $0)
source $TESTHOME/fsio.env


export CORES=8
export MEMORY=64g
export INSTANCES=6
export MFS=1



# monitoring
export RESULTSDIR=/tmp/monit
export BENCMARK=fsio

kill_all_monit $NODES
rm_monit_logs $NODES

########   Run loop Changing Spark Worker paameters ######

for i in 01 02 03
do

export PREFIX=AFF-${i}
export NUMFILES=100
export FILESZ=20GB

export RESULTSDIR=${TESTHOME}/RESULTS/${PREFIX}-F${NUMFILES}x${FILESZ}

echo "
###  CONFIG ###
###  CORES=$CORES
###  INSTANCES=$INSTANCES
###  MEMORY=$MEMORY
###  NUMFILES=$NUMFILES
###  FILESZ=$FILESZ
###  MFS=$MFS
###  RESULTSDIR=$RESULTSDIR
###  "

    mkdir -p $RESULTSDIR

    TEST=write
    TESTDIR=tmp_${BENCHMARK}_${TEST}_${SCALE}
    TEST_ID=${BENCMARK}-${TEST}
    echo "### $(date) TEST_ID=$TEST_ID ; PREFIX=$PREFIX  ###"

    check_env
    cleanup

    gen_test_from_ryba
    kubectl delete -f ${TESTDIR}  --ignore-not-found
    kubectl create -f ${TESTDIR}  --as user1  # runs concurrently ${SCALE} clients
    start_monit $NODES
    wait_4done
    kill_all_monit $NODES
    get_monit_logs $NODES
    get_logs

    TEST=read
    TESTDIR=tmp_${BENCHMARK}_${TEST}_${SCALE}
    TEST_ID=${BENCMARK}-${TEST}
    echo "### $(date) TEST_ID=$TEST_ID ; PREFIX=$PREFIX  ###"

    gen_test_from_ryba
    kubectl delete -f ${TESTDIR}  --ignore-not-found
    kubectl create -f ${TESTDIR} --as user1 # runs concurrently ${SCALE} clients
    start_monit $NODES
    wait_4done
    kill_all_monit $NODES
    get_monit_logs $NODES
    get_logs

## 
export NUMFILES=20
export FILESZ=100GB
export RESULTSDIR=${TESTHOME}/RESULTS/${PREFIX}-F${NUMFILES}x${FILESZ}
echo "
###  CONFIG ###
###  CORES=$CORES
###  INSTANCES=$INSTANCES
###  MEMORY=$MEMORY
###  NUMFILES=$NUMFILES
###  FILESZ=$FILESZ
###  MFS=$MFS
###  RESULTSDIR=$RESULTSDIR
###  "

mkdir -p $RESULTSDIR
    TEST=write
    TESTDIR=tmp_${BENCHMARK}_${TEST}_${SCALE}
    TEST_ID=${BENCMARK}-${TEST}
    echo "### $(date) TEST_ID=$TEST_ID ; PREFIX=$PREFIX  ###"

    check_env
    cleanup

    gen_test_from_ryba
    kubectl delete -f ${TESTDIR}  --ignore-not-found
    kubectl create -f ${TESTDIR}  --as user1  # runs concurrently ${SCALE} clients
    start_monit $NODES
    wait_4done
    kill_all_monit $NODES
    get_monit_logs $NODES
    get_logs

    TEST=read
    TESTDIR=tmp_${BENCHMARK}_${TEST}_${SCALE}
    TEST_ID=${BENCMARK}-${TEST}
    echo "### $(date) TEST_ID=$TEST_ID ; PREFIX=$PREFIX  ###"

    gen_test_from_ryba
    kubectl delete -f ${TESTDIR}  --ignore-not-found
    kubectl create -f ${TESTDIR} --as user1 # runs concurrently ${SCALE} clients
    start_monit $NODES
    wait_4done
    kill_all_monit $NODES
    get_monit_logs $NODES
    get_logs

done

