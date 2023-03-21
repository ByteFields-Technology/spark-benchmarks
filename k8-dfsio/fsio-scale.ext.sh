#executes concurrently multiple instances of the benchmark
export SLEEP=30
export VERBOSE=NO #YES
export VERBOSE=YES
#set -o functrace
#set -o xtrace


#export NODES="10.163.160.233 10.163.160.234 10.163.160.235 10.163.160.236 10.163.160.237 10.163.160.238 10.163.160.239"
export NODES=$(kubectl get nodes | awk '$2=="Ready" { print $1}' | tr '\n' ' ')
export MONIT_HOME=/root/bin
export MAPR="10.163.160.241 10.163.160.242 10.163.160.243"
#export RDEBUG="DEBUG=YES"

#TESTID=$1
export TESTHOME=$(dirname $0)
export PIDF=$TESTHOME/$(basename $0).pid

# gcr.io/mapr-252711/spark-2.4.4:202006251708C
export IMAGE=gcr.io\\/mapr-252711\\/spark-2.4.4:202006251708C

#NAMESPACE=internaltenant
export NAMESPACE=user1
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
        kubectl cp dfsio.jar -n user1   tenantcli-0:/tmp 
        kubectl exec -it -n user1   tenantcli-0  -- bash -c "hadoop fs -copyFromLocal /tmp/dfsio.jar $JAR"
        kubectl exec -it -n user1   tenantcli-0  -- bash -c "hadoop fs -chmod a+r $JAR"
}
function check_env {

    echo "  #maprlogin
    #createticket"

    kubectl exec -it -n user1   tenantcli-0  -- bash -c "hadoop fs -rm -r -f /benchmarks/DFSIO*"
    kubectl exec -it -n user1   tenantcli-0  -- bash -c "hadoop fs -mkdir -p /benchmarks"
    kubectl exec -it -n user1   tenantcli-0  -- bash -c "hadoop fs  -chmod a+w /benchmarks"

    kubectl exec -it -n user1   tenantcli-0  -- bash -c "hadoop fs -ls $JAR" || install_jar

    kubectl exec -it -n user1   tenantcli-0  -- bash -c "hadoop fs -ls $JAR" || {
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


function gen_test_from_ryba {
    rm -fr ${TESTDIR}
    mkdir ${TESTDIR}
    TEST_YAML=${TESTDIR}/fsio-${TEST}.yaml

    sed 's/fsio-'${TEST}'/fsio-'${TEST}'/' fsio-${TEST}.ext.ryba  > ${TEST_YAML}

    sed -i 's/CORES/'$CORES'/1' ${TEST_YAML}
    sed -i 's/INSTANCES/'$INSTANCES'/1' ${TEST_YAML}
    sed -i 's/MEMORY/'$MEMORY'/1' ${TEST_YAML}
    sed -i 's/NUMFILES/'$NUMFILES'/1' ${TEST_YAML}
    sed -i 's/FILESZ/'$FILESZ'/1' ${TEST_YAML}
    sed -i 's/NAMESPACE/'$NAMESPACE'/1' ${TEST_YAML}
    sed -i 's/IMAGE/'$IMAGE'/1' ${TEST_YAML}
   
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

        kubectl logs fsio-${TEST}-driver -n ${NAMESPACE} | grep -A 8 'TestDFSIO -----' | tee -a ${RESULTSDIR}/${TEST_ID}.log
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
        sshpass -p mapr ssh root@$i  "$RDEBUG SLEEP=$SLEEP $MONIT_HOME/monit.sh $TEST_ID < /dev/null >> /tmp/monit.log 2>&1 & " 
    done

}

function start_monit_mfs() {
    for i in $* 
    do
      sshpass -p mapr ssh root@$i  "$RDEBUG SLEEP=$SLEEP TEST_ID=$TEST_ID $MONIT_HOME/monit_mfs.sh  start " 
    done
}
function stop_monit_mfs() {
    for i in $* 
    do
      sshpass -p mapr ssh root@$i  "$RDEBUG SLEEP=$SLEEP TEST_ID=$TEST_ID $MONIT_HOME/monit_mfs.sh  stop " 
    done
}
function get_monit_logs_mfs() {
    for i in $* 
    do
       sshpass -p mapr ssh root@$i  "$RDEBUG SLEEP=$SLEEP TEST_ID=$TEST_ID $MONIT_HOME/monit_mfs.sh  log " > ${RESULTSDIR}/$TEST_ID.$i.log
    done
}
function kill_all_monit_mfs() {
    for i in $* 
    do
        sshpass -p mapr ssh root@$i "pkill pidstat"
        sshpass -p mapr ssh root@$i   "rm -fr /tmp/$TEST_ID.* "
    done
}

function show_monit_mfs() {
    for i in $* 
    do
      sshpass -p mapr ssh root@$i  "ps -ef | grep pidstat ; $RDEBUG SLEEP=$SLEEP TEST_ID=$TEST_ID $MONIT_HOME/monit_mfs.sh  logname ; cat  /tmp/$TEST_ID.{log,dat}" 
    done
}

function test_monit_fs() {
    export SLEEP=1
    export TEST_ID=selftest
    export RDEBUG="DEBUG=YES"
    export RESULTSDIR=/tmp/

    echo MAPR=$MAPR
    show_monit_mfs $MAPR

    kill_all_monit_mfs $MAPR
    update_monit $MAPR   
    start_monit_mfs $MAPR
    sleep 10
    show_monit_mfs $MAPR
    sleep 10
    show_monit_mfs $MAPR
    sleep 10
    stop_monit_mfs $MAPR
    get_monit_logs_mfs $MAPR
}

function stop_monit() {
    for i in $*
    do
       sshpass -p mapr ssh root@$i 'kill -15 $(cat /tmp/'$TEST_ID'.MONIT.PID)'
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
        sshpass -p mapr ssh root@$i  "$RDEBUG $MONIT_HOME/monit-logs.sh $TEST_ID >> /tmp/monit.log "
        sshpass -p mapr scp root@$i:/tmp/$TEST_ID.log  ${RESULTSDIR}/$TEST_ID.$i.log
    done
    echo "
    ### to review resource consumption do : 
    grep -n MFS  ${RESULTSDIR}/$TEST_ID.*.log
    grep -n SPK  ${RESULTSDIR}/$TEST_ID.*.log 
    ### to get average CPU% utilization do : 
    awk '{sum[\$3]+=\$4; cnt[\$3]++;} END { for (key in sum) { print key \" : \" sum[key]/cnt[key] }}' ${RESULTSDIR}/$TEST_ID.*.log  | sort
    ### to get FSIO stats do:
    awk -F\":\" '/Date & time/{print \$2\":\"\$3\":\" \$4\":\" \$5} /:/ {print \$2 }' ${RESULTSDIR}/$TEST_ID.log
    #cut -d\: -f2 <  ${RESULTSDIR}/$TEST_ID.log 
    "
}

function show_monit() {
    for i in $*
    do
        sshpass -p mapr ssh root@$i  "hostname -I; ps -ef | grep monit.sh ; ls -l /tmp/monit.log " 
    done

}

function test_monit() {
    export SLEEP=1
    export TEST_ID=selftest
    export RDEBUG="DEBUG=YES"
    export RESULTSDIR=/tmp/

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

# set -o functrace; set -o xtrace; test_monit; exit
# set -o functrace; set -o xtrace; test_monit_fs; exit

export CORES=8
export MEMORY=64g
export INSTANCES=6
export MFS=MAPR

export BENCMARK=fsio
export RESULTS_PATH=${TESTHOME}/RESULTS/Shoebox/MAPR-heap13
#export RESULTS_PATH=${TESTHOME}/RESULTS/Shoebox/MAPR-2

########   Run loop Changing Spark Worker paameters ######

for i in 01 02 03
do

export PREFIX=AFF-${i}
export NUMFILES=100
export FILESZ=20GB

export RESULTSDIR=${RESULTS_PATH}/${PREFIX}-F${NUMFILES}x${FILESZ}

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
    TESTDIR=tmp_${BENCHMARK}_${TEST}
    TEST_ID=${BENCMARK}-${TEST}
    echo "### $(date) TEST_ID=$TEST_ID ; PREFIX=$PREFIX  ###"

    check_env
    cleanup

    gen_test_from_ryba

    kubectl delete -f ${TESTDIR}  --ignore-not-found
    kubectl create -f ${TESTDIR}  #--as user1  # runs concurrently ${SCALE} clients
    start_monit $NODES
    start_monit_mfs $MAPR
    wait_4done
    kill_all_monit $NODES
    stop_monit_mfs $MAPR
    get_monit_logs $NODES
    get_monit_logs_mfs $MAPR
    get_logs

    TEST=read
    TESTDIR=tmp_${BENCHMARK}_${TEST}
    TEST_ID=${BENCMARK}-${TEST}
    echo "### $(date) TEST_ID=$TEST_ID ; PREFIX=$PREFIX  ###"

    gen_test_from_ryba
    kubectl delete -f ${TESTDIR}  --ignore-not-found
    kubectl create -f ${TESTDIR} --as user1 # runs concurrently ${SCALE} clients
    start_monit_mfs $MAPR
    start_monit $NODES
    wait_4done
    stop_monit_mfs $MAPR
    kill_all_monit $NODES
    get_monit_logs $NODES
    get_monit_logs_mfs $MAPR
    get_logs

## 
export NUMFILES=20
export FILESZ=100GB
export RESULTSDIR=${RESULTS_PATH}/${PREFIX}-F${NUMFILES}x${FILESZ}
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
    TESTDIR=tmp_${BENCHMARK}_${TEST}
    TEST_ID=${BENCMARK}-${TEST}
    echo "### $(date) TEST_ID=$TEST_ID ; PREFIX=$PREFIX  ###"

    check_env
    cleanup

    gen_test_from_ryba
    kubectl delete -f ${TESTDIR}  --ignore-not-found
    kubectl create -f ${TESTDIR}  --as user1  # runs concurrently ${SCALE} clients
    start_monit_mfs $MAPR
    start_monit $NODES
    wait_4done
    stop_monit_mfs $MAPR
    kill_all_monit $NODES
    get_monit_logs_mfs $MAPR
    get_monit_logs $NODES
    get_logs

    TEST=read
    TESTDIR=tmp_${BENCHMARK}_${TEST}
    TEST_ID=${BENCMARK}-${TEST}
    echo "### $(date) TEST_ID=$TEST_ID ; PREFIX=$PREFIX  ###"

    gen_test_from_ryba
    kubectl delete -f ${TESTDIR}  --ignore-not-found
    kubectl create -f ${TESTDIR} --as user1 # runs concurrently ${SCALE} clients
    start_monit_mfs $MAPR
    start_monit $NODES
    wait_4done
    kill_all_monit $NODES
    stop_monit_mfs $MAPR
    get_monit_logs_mfs $MAPR
    get_monit_logs $NODES
    get_logs

done

 
# USAGE : TNO=AFF-01-F20x100GB; getres_mfs
# 
export NODES=$(kubectl get nodes | awk '$2=="Ready" { print $1}' | tr '\n' ' ')
export MONIT_HOME=/root/bin
export MAPR="10.163.160.241 10.163.160.242 10.163.160.243"

function mkhostlist() {
    for i in $*
    do
        printf " "$PREFIX.$i.log" "
    done
    printf "\n"
}

function showvars() {
    for i in $*
    do
       printenv | grep $i
    done
}

function checkvars() {
    [ -z "$MAPR" ] && { echo " $i is not defined" ; exit ; } 
    [ -z "$NODES" ] && { echo " $i is not defined" ; exit ; } 
    [ -z "$TNO" ] && { echo " $i is not defined" ; exit ; } 
}

function getres_mfs() { 
    : ${TNO:=$1}

    PREFIX="${TNO}/fsio-write"
    PICASSO_LOGS=$( mkhostlist $NODES)
    MAPR_LOGS=$( mkhostlist $MAPR)
     
    showvars MAPR NODES PREFIX PICASSO_LOGS MAPR_LOGS TNO 

    echo "#####  WRITE  $TNO    ######"
    grep -n MFS  ${PICASSO_LOGS}
    grep -n SPK  ${PICASSO_LOGS}
    ###  PICASSO average CPU% utilization do :
    awk '{sum[$3]+=$4; cnt[$3]++;} END { for (key in sum) { print key " : " sum[key]/cnt[key] }}' ${PICASSO_LOGS}  | sort
    awk '{sum[$3]+=$4; cnt[$3]++;} END { for (key in sum) { print key " : " sum[key]/cnt[key] }}' ${PICASSO_LOGS}  | sort | cut -d: -f2    
    ###  MAPR average CPU% utilization do :
    grep Average ${MAPR_LOGS}
    awk '$1=="Average:" && $10=="mfs" {SUM+=$8; CNT++; print $8;} END { print "TOTAL MAPR CPU : " SUM }' ${MAPR_LOGS}  
    # FSIO   
    awk -F":" '/Date & time/{print $2":"$3":" $4":" $5} /:/ {print $2 }' ${PREFIX}.log
read 
    PREFIX="${TNO}/fsio-read"
    PICASSO_LOGS=$( mkhostlist $NODES)
    MAPR_LOGS=$( mkhostlist $MAPR)
    
    echo "#####  READ  $TNO    ######"
    grep -n MFS  ${PICASSO_LOGS}
    grep -n SPK  ${PICASSO_LOGS}
    ###  PICASSO average CPU% utilization do :
    awk '{sum[$3]+=$4; cnt[$3]++;} END { for (key in sum) { print key " : " sum[key]/cnt[key] }}' ${PICASSO_LOGS}  | sort
    awk '{sum[$3]+=$4; cnt[$3]++;} END { for (key in sum) { print key " : " sum[key]/cnt[key] }}' ${PICASSO_LOGS}  | sort | cut -d: -f2    
    ###  MAPR average CPU% utilization do :
    grep Average ${MAPR_LOGS}
    awk '$1=="Average:" && $10=="mfs" {SUM+=$8; CNT++; print $8;} END { print "TOTAL MAPR CPU : " SUM }' ${MAPR_LOGS}  
    # FSIO   
    awk -F":" '/Date & time/{print $2":"$3":" $4":" $5} /:/ {print $2 }' ${PREFIX}.log
}
