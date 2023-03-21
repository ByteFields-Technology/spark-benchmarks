#executes concurrently multiple instances of the benchmark
export SLEEP=30
export VERBOSE=NO #YES
export VERBOSE=YES
#set -o functrace
#set -o xtrace


#export NODES="10.163.160.233 10.163.160.234 10.163.160.235 10.163.160.236 10.163.160.237 10.163.160.238 10.163.160.239"
export NODES=$(kubectl get nodes | awk '$2=="Ready" { print $1}' | tr '\n' ' ')
export MONIT_HOME=/root/bin
export RDEBUG="DEBUG=YES"

#TESTID=$1
export TESTHOME=$(dirname $0)
export PIDF=$TESTHOME/$(basename $0).pid

export AFFINITY=.aff
# gcr.io/mapr-252711/spark-2.4.4:202006251708C
export IMAGE=gcr.io\\/mapr-252711\\/spark-2.4.4:202006251708C

#NAMESPACE=internaltenant
export NAMESPACE=sampletenant
export SCALE=1
export BENCHMARK=DFSIO
export JAR=/benchmarks/spark-benchmarks-dfsio-0.11.0-SNAPSHOT-with-dependencies.jar
export PICASSONS=dataplatform

if [ "$DEBUG" == "YES" ]; then
  decho() { printf "STDERR: %s\n" "$*" >&2; printf "%s\n" "$*"; }
  export VERBOSE=YES
  set -o functrace
  set -o xtrace
else
  decho() { printf "%s\n" "$*";} 
fi


function install_jar {
        kubectl cp dfsio.jar cldb-0:/tmp  -n ${PICASSONS} 
        kubectl exec -it -n ${PICASSONS} cldb-0  -- bash -c "hadoop fs -copyFromLocal /tmp/dfsio.jar $JAR"
}
function check_env {

    echo "  #maprlogin
    #createticket"

    kubectl exec -it -n ${PICASSONS} cldb-0  -- bash -c "hadoop fs -rm -r -f /benchmarks/DFSIO*"
    kubectl exec -it -n ${PICASSONS} cldb-0  -- bash -c "hadoop fs -mkdir -p /benchmarks"
    kubectl exec -it -n ${PICASSONS} cldb-0  -- bash -c "hadoop fs  -chmod a+w /benchmarks"

    kubectl exec -it -n ${PICASSONS} cldb-0  -- bash -c "hadoop fs -ls $JAR" || install_jar

    kubectl exec -it -n ${PICASSONS} cldb-0  -- bash -c "hadoop fs -ls $JAR" || {
       printf '%s\n' "maprfs://$JAR  is not found"
       exit 1
    }
}

function decho {
    if [ "$VERBOSE" == "YES" ] ; then echo "$*"; fi
}

function cleanup {
    for i in tmp_${BENCHMARK}*
    do
        kubectl delete -f $i  --ignore-not-found
        rm -fr ${i}
    done
    kill_all_monit $NODES
    rm_monit_logs $NODES
}

function gen_test {
    rm -fr ${TESTDIR}
    mkdir ${TESTDIR}
    for ((i=1;i<=${SCALE};i++)) 
    do
        sed 's/fsio-'${TEST}'/fsio-'${TEST}'-'${i}'/' fsio-${TEST}${AFFINITY}.yaml  | \
        sed 's/\/benchmarks\/DFSIO/\/benchmarks\/DFSIO-'${i}'/' > \
        ${TESTDIR}/fsio-${TEST}-${i}.yaml
    done
}

function gen_test_from_ryba {
    rm -fr ${TESTDIR}
    mkdir ${TESTDIR}
    for ((i=1;i<=${SCALE};i++)) 
    do
        sed 's/fsio-'${TEST}'/fsio-'${TEST}'-'${i}'/' fsio-${TEST}${AFFINITY}.ryba  | \
        sed 's/\/benchmarks\/DFSIO/\/benchmarks\/DFSIO-'${i}'/' > \
        ${TESTDIR}/fsio-${TEST}-${i}.yaml

        sed -i 's/CORES/'$CORES'/1' ${TESTDIR}/fsio-${TEST}-${i}.yaml
        sed -i 's/INSTANCES/'$INSTANCES'/1' ${TESTDIR}/fsio-${TEST}-${i}.yaml
        sed -i 's/MEMORY/'$MEMORY'/1' ${TESTDIR}/fsio-${TEST}-${i}.yaml
        sed -i 's/NUMFILES/'$NUMFILES'/1' ${TESTDIR}/fsio-${TEST}-${i}.yaml
        sed -i 's/FILESZ/'$FILESZ'/1' ${TESTDIR}/fsio-${TEST}-${i}.yaml
        sed -i 's/NAMESPACE/'$NAMESPACE'/1' ${TESTDIR}/fsio-${TEST}-${i}.yaml
        sed -i 's/IMAGE/'$IMAGE'/1' ${TESTDIR}/fsio-${TEST}-${i}.yaml
   done
}


function wait_4done {
    Status="xx"
    while [ "$Status" != "DONE" ] && [ "$Status" != "ERROR" ]; 
    do 
        sleep $SLEEP
        Status=$(kubectl get pods -n ${NAMESPACE} | awk 'BEGIN {STA="DONE"}  
            /fsio-'${TEST}'-/ && /-driver/ && $3 == "Error" { STA="ERROR"; exit} 
            /fsio-'${TEST}'-/ && /-driver/ && $3 != "Completed" { STA="RUNNING"; exit} 
            END {print STA}' )
        decho $Status | tee -a ${RESULTSDIR}/${TEST}.log
    done
}

function get_logs {
    for ((i=1;i<=${SCALE};i++)) 
    do
        kubectl logs fsio-${TEST}-${i}-driver -n ${NAMESPACE} | grep -A 8 'TestDFSIO -----' | tee -a ${RESULTSDIR}/${TESTNO}.log
    done
}

function update_monit() {
    for i in $* 
    do
        sshpass -p mapr scp -r $MONIT_HOME/* root@${i}:$MONIT_HOME/
    done

}
function start_monit() {
    for i in $* 
    do
        sshpass -p mapr ssh root@$i  "$RDEBUG SLEEP=$SLEEP $MONIT_HOME/monit.sh $TESTNO < /dev/null >> /tmp/monit.log 2>&1 & " 
    done

}

function stop_monit() {
    for i in $* 
    do
       sshpass -p mapr ssh root@$i 'kill -15 $(cat /tmp/'$TESTNO'.MONIT.PID)'
    done
}

function kill_all_monit() {
    for i in $* 
    do
       P=$(sshpass -p mapr ssh root@$i "ps -ef" | grep monit.sh | awk '{print $2}' | tr '\n' ' ' )
       echo "$P"
       sshpass -p mapr ssh root@$i "kill -9 $P"
    done
}

function rm_monit_logs() {
    for i in $* 
    do
        sshpass -p mapr ssh root@$i  "rm -f /tmp/*.{PID,log,bac}  /tmp/*.*_CID"
    done
}

function get_monit_logs() {
    for i in $* 
    do
        sshpass -p mapr ssh root@$i  "$RDEBUG $MONIT_HOME/monit-logs.sh $TESTNO >> /tmp/monit.log "
        sshpass -p mapr scp root@$i:/tmp/$TESTNO.log  ${RESULTSDIR}/$TESTNO.$i.log
    done
    echo "
    ### to review resource consumption do : 
    grep -n MFS  ${RESULTSDIR}/$TESTNO.*.log
    grep -n SPK  ${RESULTSDIR}/$TESTNO.*.log 
    ### to get average CPU% utilization do : 
    awk '{sum[\$3]+=\$4; cnt[\$3]++;} END { for (key in sum) { print key \" : \" sum[key]/cnt[key] }}' ${RESULTSDIR}/$TESTNO.*.log  | sort
    ### to get FSIO stats do:
    awk -F\":\" '/Date & time/{print \$2\":\"\$3\":\" \$4\":\" \$5} /:/ {print \$2 }' ${RESULTSDIR}/$TESTNO.log
    #cut -d\: -f2 <  ${RESULTSDIR}/$TESTNO.log 
    "
}

function show_monit() {
    for i in $*
    do
        sshpass -p mapr ssh root@$i  "hostname -I; ps -ef | grep monit.sh ; ls -l /tmp/monit.log " 
    done

}

function test_monit() {
    echo $NODES
    update_monit $NODES   
    rm_monit_logs $NODES
    start_monit $NODES
    sleep 10
    show_monit $NODES
    sleep 10
    show_monit $NODES
    sleep 10
    kill_all_monit $NODES
    get_monit_logs $NODES
}


export RESULTSDIR=/tmp/monit
export TESTNO=selftest

kill_all_monit $NODES
rm_monit_logs $NODES

export CORES=8
export MEMORY=64g
export INSTANCES=6
export MFS=2

export PREFIX=AFF-${i}
export NUMFILES=100
export FILESZ=20GB

    TEST=write
    TESTDIR=tmp_${BENCHMARK}_${TEST}_${SCALE}
    echo "### $(date) TESTNO=$TESTNO ; PREFIX=$PREFIX  ###"

    check_env
    cleanup

   test_monit 
   gen_test_from_ryba
exit

########   Run loop Changing Spark Worker paameters ######

for i in 01 02 03
do

export CORES=8
export MEMORY=64g
export INSTANCES=6
export MFS=2

export PREFIX=AFF-${i}

export NUMFILES=100
export FILESZ=20GB
#export RESULTSDIR=${TESTHOME}/RESULTS/mfs-0${MFS}-F${NUMFILES}x${FILESZ}
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
    TESTNO=${TEST}
    echo "### $(date) TESTNO=$TESTNO ; PREFIX=$PREFIX  ###"

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
    TESTNO=${TEST}
    echo "### $(date) TESTNO=$TESTNO ; PREFIX=$PREFIX  ###"

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
    TESTNO=${TEST}
    echo "### $(date) TESTNO=$TESTNO ; PREFIX=$PREFIX  ###"

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
    TESTNO=${TEST}
    echo "### $(date) TESTNO=$TESTNO ; PREFIX=$PREFIX  ###"

    gen_test_from_ryba
    kubectl delete -f ${TESTDIR}  --ignore-not-found
    kubectl create -f ${TESTDIR} --as user1 # runs concurrently ${SCALE} clients
    start_monit $NODES
    wait_4done
    kill_all_monit $NODES
    get_monit_logs $NODES
    get_logs

done

exit 

########  regular test run  ######

check_env
cleanup

TEST=write
TESTDIR=tmp_${BENCHMARK}_${TEST}_${SCALE}
gen_test
kubectl delete -f ${TESTDIR}  --ignore-not-found
kubectl create -f ${TESTDIR}  --as user1  # runs concurrently ${SCALE} clients
start_monit $NODES
wait_4done
stop_monit $NODES
get_monit_logs $NODES
get_logs

TEST=read
TESTDIR=tmp_${BENCHMARK}_${TEST}_${SCALE}
gen_test
kubectl delete -f ${TESTDIR}  --ignore-not-found
kubectl create -f ${TESTDIR} --as user1 # runs concurrently ${SCALE} clients
start_monit $NODES
wait_4done
stop_monit $NODES
get_monit_logs $NODES
get_logs

######

########   Run loop Changing Spark Worker paameters ######
check_env
cleanup

export CORES=2
export MEMORY=4g
 
for INSTANCES in 1 2 4 8 12 16 24 32
do
    echo "### TEST: CORES=$CORES ; INSTANCES=$INSTANCES ; MEMORY=$MEMORY ###"
    TEST=write
    TESTDIR=tmp_${BENCHMARK}_${TEST}_${SCALE}
    gen_test_from_ryba
    kubectl delete -f ${TESTDIR}  --ignore-not-found
    kubectl create -f ${TESTDIR}  --as user1  # runs concurrently ${SCALE} clients
    start_monit 
    wait_4done
    stop_monit 
    get_logs

    TEST=read
    TESTDIR=tmp_${BENCHMARK}_${TEST}_${SCALE}
    gen_test_from_ryba
    kubectl delete -f ${TESTDIR}  --ignore-not-found
    kubectl create -f ${TESTDIR} --as user1 # runs concurrently ${SCALE} clients
    start_monit 
    wait_4done
    stop_monit 
    get_logs
done
## 


########  Sclae to 10 Spark Drivers  ######

SCALE=10
check_env
cleanup

TEST=write
TESTDIR=tmp_${BENCHMARK}_${TEST}_${SCALE}
gen_test
kubectl delete -f ${TESTDIR}  --ignore-not-found
kubectl create -f ${TESTDIR}  --as user1  # runs concurrently ${SCALE} clients
start_monit 
wait_4done
stop_monit 
get_logs

TEST=read
TESTDIR=tmp_${BENCHMARK}_${TEST}_${SCALE}
gen_test
kubectl delete -f ${TESTDIR}  --ignore-not-found
kubectl create -f ${TESTDIR} --as user1 # runs concurrently ${SCALE} clients
start_monit 
wait_4done
stop_monit 

get_logs

######

#clean up


exit

# cleanup
for i in tmp_${BENCHMARK}*
do
    kubectl delete -f $i  --ignore-not-found
    rm -fr $i
done

function start_monit ( ) {
    for i in $* 
    do
    done

}

function stop_monit {

}

