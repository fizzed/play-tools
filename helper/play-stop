#!/bin/bash

PID_DIR=`dirname $0`
PID_FILE="$PID_DIR/RUNNING_PID"

if [ -f $PID_FILE ]; then
  PID=`cat $PID_FILE`
  echo "pid file exists; killing process $PID..."
  kill $PID

  # wait up to 10 secs for process to die
  for i in {1..10}; do
    ps -p$PID 2>&1 >/dev/null
    status=$?
    if [ "$status" == "0" ]; then
      echo "process successfully died!"
      exit 0
    else
      echo "Waiting $i of 10 secs for process $PID to die..."
      sleep 1
    fi
  done

  echo "Unable to confirm process died (may want to manually check)"
  exit 1
else
  echo "pid file does not exist (app not running?) [$PID_FILE]"
fi
