#!/bin/ksh
#-------------------------------------------------- 
# usage: mysqlbackup.sh full|incre|fullcompres
# purposes: 
#	 - backup online mysql databases
#	- option: full -> do a full then tar gzip
#	- option: incremental -> not implemented yet
#	- option: fullcompress -> do a full and compress in
#		 the same time
#
# requirements:
#	- databases should use innodb engine
#       - innobackupex from percona should be installed
#       - xbstream available
#
# HOW TO RESTORE AFTER full compress:
# requirements:
#	- qpress binary should be installed
#       - xbstream available
# we suppose the backup file is called  agabs-db002v.xbstream
# 1. UNPACK backup file:
#   directory /u01/mysql/recovery should exist
#   xbstream -x < agabs-db002v.xbstream -C /u01/mysql/recovery/ 
# 2. DECOMPRESS:
#   go to /u01/mysql/recovery
#   and launch this command:
#for bf in `find . -iname "*\.qp"`;do qpress -d $bf $(dirname $bf) && rm $bf;done
# 3.PREPARE THE BACKUP:
# innobackupex --apply-log /u01/mysql/recovery
# directoy recovery and replace the former datadir
#
#
# HOW TO RESTORE AFTER full backup:
# after untarring and unzipping the file
# 1. PREPARE THE BACKUP:
# innobackupex --apply-log /path/to/BACKUP-DIR
#
#
# authors version: georges.chaleunsinh@colt.net 20130807	
#-------------------------------------------------- 
set -x
debug=1
#SOCKET=/u01/mysql/tmp/mysql.sock
#DB=nl
PORT=3306
mk_dump=0
BASEDIR=/u01/mysql/backup
BACKUP_CMD=$*
PROGRAM=$0
STAMP=$(date +%Y%m%d_%H%M%S)
LOGREPOSIT=/tmp/BB/backup/$PORT
#LOGFILE=innobackupex$$.log
PATH=$PATH:/usr/sbin
DAYD=$(date +%a)
export PATH

[ ! -d $LOGREPOSIT ] && mkdir -p $LOGREPOSIT

if [ ! -d $BASEDIR ] ;then
  echo "Error: directory $BASEDIR not found" > $LOGREPOSIT/$LOGFILE
  exit
fi

function validate_cmd {
    if [[ $# -ne 1 ]]
    then
        echo "usage: ${PROGRAM} (full|incre|fullcompress) \n"
        exit 1
    fi

    case ${BACKUP_CMD} in
    full)
         echo "backup full"
         MODE=FULL; export MODE
    ;;
    incre)
        echo "backup incremental"
        MODE=INCRE; export MODE
    ;;
    fullcompress)
         echo "backup full compressed"
         MODE=COMPRESSF;export MODE
    ;;
    *)
        echo "not a valid option\n"
        exit 1
    ;;
    esac
}

function backup_full {
  set -x
  innobackupex $BASEDIR 2>&1 | tee -a $BASEDIR/$LOGFILE
  ret=$?
  echo " ret is $ret "
  result=`grep "innobackupex: Created backup directory" $BASEDIR/$LOGFILE`
  dir=`basename $(echo $result | awk '{ print $5 }')`
  cd $BASEDIR
  tar zcvf ${dir}.tar.gz $dir 
  if [ $? -eq 0 ];then
    ls $dir
    [ $? -eq 0 ] && rm -rf $dir 
  fi
  cd -
 
}

function backup_full_compress {
    #innobackupex --stream=xbstream --compress ${BASEDIR} > ${BASEDIR}/`hostname`${STAMP}.xbstream | tee -a $BASEDIR/$LOGFILE
    innobackupex --stream=xbstream --compress ${BASEDIR} > ${BASEDIR}/`hostname`${STAMP}.xbstream 2> $BASEDIR/$LOGFILE 

}


validate_cmd ${BACKUP_CMD}
LOGFILE=backup-${MODE}-${STAMP}.log
epoch_start=`perl -e "print time()"`
date_start=`date`


#[ $debug -eq 1 ] && echo "retval for local readonly $ro remote $rem_ro end"

find $BASEDIR -name "*.tar.gz" -mtime +1 | xargs rm -f
find $BASEDIR -name "*.xbstream" -mtime +1 | xargs rm -f
find $BASEDIR -name "*backup*\.log" -mtime +1 | xargs rm -f

# check if mk-parallel-dump is running, if yes ,mk-parallel-dump has priority

mk_dump=`ps -ef | grep -v grep | grep -c mk-parallel-dump`
# should start on writer, or when boths nodes have same role,or remote down and no mk_dump is running
if [[ $mk_dump -eq 0 ]];then
  #[ $debug -eq 1 ] && echo "ro=$ro, rem_ro=$rem_ro,mk_dump $mk_dump backup can begin ..."
  case $DAYD in
    Sat)
        [ "$MODE" = "FULL" ] && backup_full
        [ "$MODE" = "INCRE" ] && backup_incr
        [ "$MODE" = "COMPRESSF" ] && backup_full_compress

    ;;
    Sun)
        [ "$MODE" = "FULL" ] && backup_full
        [ "$MODE" = "INCRE" ] && backup_incr
        [ "$MODE" = "COMPRESSF" ] && backup_full_compress
    ;;
    Mon)
        [ "$MODE" = "FULL" ] && backup_full
        [ "$MODE" = "INCRE" ] && backup_incr
        [ "$MODE" = "COMPRESSF" ] && backup_full_compress
    ;;
    Tue)
        [ "$MODE" = "FULL" ] && backup_full
        [ "$MODE" = "INCRE" ] && backup_full
        [ "$MODE" = "COMPRESSF" ] && backup_full_compress
    ;;
    Wed)
        [ "$MODE" = "FULL" ] && backup_full
        [ "$MODE" = "INCRE" ] && backup_incr
        [ "$MODE" = "COMPRESSF" ] && backup_full_compress
    ;;
    Thu)
        [ "$MODE" = "FULL" ] && backup_full
        [ "$MODE" = "INCRE" ] && backup_incr
        [ "$MODE" = "COMPRESSF" ] && backup_full_compress
    ;;
    Fri)
        [ "$MODE" = "FULL" ] && backup_full
        [ "$MODE" = "INCRE" ] && backup_full
        [ "$MODE" = "COMPRESSF" ] && backup_full_compress
    ;;
  esac

  epoch_end=`perl -e "print time()"`
  date_end=`date`
  dif=$(($epoch_end - $epoch_start))


  #-------------------------------
  # finishing log
  #-------------------------------
  echo "\n BACKUP OPERATION BEGIN AT: $date_start " >> $BASEDIR/$LOGFILE
  echo "\n BACKUP OPERATION END AT: $date_end " >> $BASEDIR/$LOGFILE
  echo "\n DURATION OF OPERATION : $(($dif / 60 )) minutes " >> $BASEDIR/$LOGFILE


[ ! -d $LOGREPOSIT ] && mkdir -p $LOGREPOSIT
[ ! -f "$LOGREPOSIT/*log*" ] && rm ${LOGREPOSIT}/*log*
[ -f "$LOGREPOSIT/NODUMP" ] && rm ${LOGREPOSIT}/NODUMP
cp $BASEDIR/$LOGFILE $LOGREPOSIT/


fi
