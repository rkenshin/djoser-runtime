#!/bin/sh
# --------------------------------------------------------------------------- 
# Djoser Runtime Control Script 
# 
# Copyright 2010 Yascie Inc. All Rights Reserved. 
# --------------------------------------------------------------------------- 
# version: 0.1
# build date: 20100406141135
#function that prints out usage syntax

DJOSERRUNTIME_VER=6.0.25.A-RELEASE
syntax () {
  echo "Usage:"
  echo "./tcruntime.sh cmd"
  echo "  cmd is one of start | run | stop | restart | status"
  echo "    start             - starts a tc Runtime instance as a daemon process"
  echo "    run               - starts a tc Runtime instance as a foreground process"
  echo "    stop [timeout]    - stops a running tc Runtime instance forces a termination"
  echo "                        of the process if it doesn't exit gracefully within"
  echo "                        timeout"
  echo "    restart [timeout] - restarts a running tc Runtime daemon process with a"
  echo "                        forced termination after timeout seconds"
  echo "    status            - reports the status of a tc Runtime instance"
  echo " "
  echo " "
}

#find out the absolute path of the script
setupdir () {
  PRG="$0"

  while [ -h "$PRG" ]; do
    ls=`ls -ld "$PRG"`
    link=`expr "$ls" : '.*-> \(.*\)$'`
    if expr "$link" : '/.*' > /dev/null; then
      PRG="$link"
    else
      PRG=`dirname "$PRG"`/"$link"
    fi
  done
  # Get standard environment variables
  PRGDIR=`dirname "$PRG"`

  #Absolute path
  PRGDIR=`cd "$PRGDIR" ; pwd`
}

getTOMCAT_VERSION () {
  # tomcat.version can contain just the version number (eg: 6.0.20.A)
  # or the full pathname (eg: /foo/bar/tomcat-6.0.20.A), so we need
  # to handle both. If TOMCAT_VER is already provided, just use that
  if [ -z "$TOMCAT_VER" ]; then
    if [ -r "$CATALINA_BASE/conf/tomcat.version" ]; then
      # read TOMCAT_VER2 < "$CATALINA_BASE/conf/tomcat.version"
      TOMCAT_VER2=`cat "$CATALINA_BASE/conf/tomcat.version"`
      if [ -d "$PRGDIR/tomcat-$TOMCAT_VER2" ]; then
        CATALINA_HOME=`cd $PRGDIR/tomcat-$TOMCAT_VER2 ; pwd`
        TOMCAT_VER="$TOMCAT_VER2"
      elif [ -d "$TOMCAT_VER2" ]; then
        CATALINA_HOME=`cd $TOMCAT_VER2 ; pwd`
        TOMCAT_VER=`echo $TOMCAT_VER2 | sed -e 's/^.*tomcat-//'`
      fi
    fi
    if [ -z "$TOMCAT_VER" ]; then
      TOMCAT_VER=`ls -d -r $PRGDIR/tomcat-* | head -1 | sed -e 's/^.*tomcat-//'`
    fi
  fi
}

setupCATALINA_HOME () {
  #Setup CATALINA_HOME to point to our binaries
  [ -z "$CATALINA_HOME" ] && CATALINA_HOME=`cd "$PRGDIR/tomcat-$TOMCAT_VER" ; pwd`
  if [ ! -r "$CATALINA_HOME" ]; then
    echo "ERROR CATALINA_HOME directory $CATALINA_HOME does not exist or is not readable."
    exit 1
  fi
}

setupINSTANCE_BASE () {
  # The directory where instances of tc Runtime will be created
  [ -z "$INSTANCE_BASE" ] && INSTANCE_BASE="$PRGDIR"
}

noop () {
  echo -n ""
}

setupCATALINA_BASE () {
  if [ -z "$INSTANCE_NAME" ]; then 
    echo "ERROR Missing instance name"
    syntax
    exit 1
  elif [ -z "$1" ]; then 
    echo "ERROR Missing command"
    syntax
    exit 1
  fi
    
  CATALINA_BASE=$INSTANCE_BASE/$INSTANCE_NAME  
  if [ -z "$INSTANCE_NAME" ]; then
    echo "ERROR First argument must be an instance name"
    syntax
    exit 1
  fi
  if [ "$2" = "create" ]; then
    if [ ! -x "$INSTANCE_BASE" ]; then
      echo "ERROR Instance directory not writeable (${INSTANCE_BASE})"
      exit 1 
    else
      return
    fi
  fi
  if [ ! -r "$CATALINA_BASE" ]; then
    echo "ERROR CATALINA_BASE directory $CATALINA_BASE does not exist or is not readable."
    exit 1
  fi
  if [ ! -d "$CATALINA_BASE" ]; then
    echo "ERROR CATALINA_BASE $CATALINA_BASE is not a directory."
    exit 1
  fi

}

isrunning() {
  #returns 0 if the process is running
  #returns 1 if the process is not running
  if [ -f $CATALINA_PID ];
    then
        PID=`cat $CATALINA_PID`
        #the process file exists, make sure the process is not running
        LINES=`ps -p $PID`
        PIDRET=$?
        if [ $PIDRET -eq 0 ]; 
        then
            export PID
            return 0;
        fi
        rm -f $CATALINA_PID
    fi
    return 1
}
instance_start() {
    isrunning
    if [ $? -eq 0 ]; then
      echo "ERROR Instance is already running as PID=$PID"
      exit 1
    fi
    $SCRIPT_TO_RUN start
    sleep 2
    isrunning
    exit $?
}

instance_run() {
    isrunning
    if [ $? -eq 0 ]; then
      echo "ERROR Instance is already running as PID=$PID"
      exit 1
    fi
    # catalina.sh won't create a PID file when using the run command
    if [ ! -f $CATALINA_PID ]; then
      echo $$ > $CATALINA_PID
    fi
    exec $SCRIPT_TO_RUN run
}

instance_stop() {
    if [ -z "$3" ]; then
      WAIT_FOR_SHUTDOWN=5
    else
      WAIT_FOR_SHUTDOWN=$3
    fi
    
    isrunning
    if [ $? -eq 0 ]; then
        #tomcat process is running 
        echo "Instance is running as PID=$PID, shutting down..."
        kill $PID
    else
        echo "Instance is not running. No action taken"
        return 1
    fi
    isrunning
    if [ $? -eq 0 ]; then
        #process still exists 
        echo "Instance is running PID=$PID, sleeping $WAIT_FOR_SHUTDOWN seconds waiting for termination"
        sleep $WAIT_FOR_SHUTDOWN
    fi
    isrunning
    if [ $? -eq 0 ]; 
    then
        echo "Instance is still running PID=$PID, forcing a shutdown"
        kill -9 $PID
    else
        echo "Instance shut down gracefully"
    fi
    if [ -f $CATALINA_PID ]; then
        rm -f $CATALINA_PID
    fi
}

instance_restart() {
    instance_stop
    if [ $? -eq 0 ]; then
        instance_start
    fi
    exit $?

}

instance_status() {
    isrunning
    if [ $? -eq 0 ]; then
      echo "STATUS Instance is RUNNING as PID=$PID"
    else
      echo "STATUS Instance is NOT RUNNING"
    fi
    exit 0
}


#Strip a trailing slash
INSTANCE_NAME="djoser"
INSTANCE_NAME=`echo $INSTANCE_NAME | sed 's/\/$//g'`

# MAIN SCRIPT EXECUTION
setupdir $@
setupINSTANCE_BASE $@
setupCATALINA_BASE $@
getTOMCAT_VERSION $@

setupCATALINA_HOME $@


echo "INFO Script directory:   $PRGDIR"
echo "INFO Binary dir:         ${CATALINA_HOME}"
echo "INFO Runtime version:    ${TOMCAT_VER}"
echo "INFO Script version:     ${DJOSERRUNTIME_VER}"


CATALINA_PID="$CATALINA_BASE/logs/djserver.pid"
SCRIPT_TO_RUN="$CATALINA_HOME/bin/catalina.sh"
[ -z "$LOGGING_MANAGER" ] && LOGGING_MANAGER="-Djava.util.logging.manager=com.springsource.tcserver.serviceability.logging.TcServerLogManager" 
[ -z "$LOGGING_CONFIG" ] && LOGGING_CONFIG="-Djava.util.logging.config.file=$CATALINA_BASE/conf/logging.properties"

export CATALINA_HOME
export CATALINA_BASE
export CATALINA_PID
export SCRIPT_TO_RUN
export LOGGING_CONFIG
export LOGGING_MANAGER
export INSTANCE_NAME

#execute the correct function
instance_$1 $@