#!/bin/bash

# EXTERNAL COMMUNICATION 
# this script still will connect to predefined external neighbor IP.

# config include
. ../config/config.ini

## INITIALIZE
[ ! -p $NAMED_PIPE_EXT ] && mkfifo $NAMED_PIPE_EXT || exec 3<> $NAMED_PIPE_EXT


main() {
 cat $NAMED_PIPE_EXT - | python3 wsdump.py  -r  ws://backbonix.com:8001 | while read line; do   
   echo ${line}| jq . > /dev/null;  
   if [ $? -eq 0 ]; then     
      line=$(echo -e ${line});
      cmd="./$MAINSHELL  '${line}' ";
      result=$(eval $cmd);
      # GET TO LOCAL PIPE 
      tag=$(echo ${result}| jq -r '.tag')
      # if tag is FFFFx0 then push to Local named pipe to broadcast it.  
      [ "$tag" == "FFFFx0" ] && echo $result > $NAMED_PIPE_BSH || echo $result > $NAMED_PIPE_EXT
      # LOGGING
      echo "$(date -u)|info|$line" >> $EXTERNAL_COMM_LOG
   else
      echo "$(date -u)|error|$line" >> $EXTERNAL_COMM_LOG
   fi; 
 done
}

main
