#!/bin/bash

CONFIG_FILE=`realpath conf/deploy.conf`

if [ ! -f $CONFIG_FILE ]; then
  echo "Config file $CONFIG_FILE does not exist; required for deploy"
  exit 1
fi

# defaults
skip_compile=0

echo "Loading config file $CONFIG_FILE"
source "$CONFIG_FILE"

SOURCE_DIR=target/staged
DEPLOYED_AT=`date --utc +%Y%m%d-%H%M%S`

# compile play app into staged distribution
if [ $skip_compile -eq 0 ]; then
  echo "Compiling and staging play application"
  play clean && play stage
  if [ ! $? -eq 0 ]; then
    echo "play staged failed; skipping deploy"
    exit 1
  fi
  echo "Compiling and staging was a success"
fi

# VERY IMPORTANT- must escape $? since it'll end up being 0 rather than the var name
echo "Prepping remote script #1 that will be run on remote host..."
SCRIPT_TO_RUN=/tmp/deploy-on-remote.sh
cat <<EOF > $SCRIPT_TO_RUN
 # make new deploy dir
 mkdir "$deploy_dir/play-$DEPLOYED_AT"
 if [ ! \$? -eq 0 ]; then
   echo "mkdir on remote host failed; skipping deploy"
   exit 1
 fi

 # is there a play-current directory?
 if [ -d $deploy_dir/play-current ]; then
   echo "Copying jars from $deploy_dir/play-current to $deploy_dir/play-$DEPLOYED_AT..."
   cp -R $deploy_dir/play-current/* $deploy_dir/play-$DEPLOYED_AT/
 else
   echo "Dir $deploy_dir/play-current does not exist (first deploy perhaps?)..."
 fi

 # switch symlink play-current to play-version
 rm -f "$deploy_dir/play-current"
 ln -s "$deploy_dir/play-$DEPLOYED_AT" "$deploy_dir/play-current"
 echo "Symlink created $deploy_dir/play-current -> $deploy_dir/play-$DEPLOYED_AT"
EOF

ssh -i $deploy_pem $deploy_user@$deploy_host '/bin/bash' < $SCRIPT_TO_RUN

if [ ! $? -eq 0 ]; then
  echo "at least one remote command failed in remote step 1!"
  exit 1
fi


# time to rsync staged jars (include deletes of jars that don't match source)
rsync --progress -avrt -d --delete -e "ssh -i $deploy_pem" $SOURCE_DIR/ $deploy_user@$deploy_host:$deploy_dir/play-$DEPLOYED_AT/
if [ ! $? -eq 0 ]; then
  echo "rsync failed!"
  exit 1
fi

echo "Successfully deployed new application build!"

# let user decide if remote app should be restarted?
read -p "Restart play application on remote host (y/n)? " choice
case "$choice" in 
  y|Y ) echo "Awesome, will restart play app..." ;;
  n|N )
    echo "All finished (remember you'll need to manually restart play app)"
    exit 0 ;;
  * ) echo "invalid answer! (won't restart app)"; exit 0 ;;
esac



SCRIPT_TO_RUN=/tmp/deploy-on-remote.sh
cat <<EOF > $SCRIPT_TO_RUN
 STDOUT_FILE=$deploy_dir/logs/stdout.log

 $deploy_dir/play-stop.sh
 if [ ! \$? -eq 0 ]; then
   echo "unable to stop app; skipping restart"
   exit 1
 fi

 $deploy_dir/play-start.sh
EOF

ssh -i $deploy_pem $deploy_user@$deploy_host '/bin/bash' < $SCRIPT_TO_RUN

if [ ! $? -eq 0 ]; then
  exit 1
fi

echo "Play app appears to have started correctly!"
