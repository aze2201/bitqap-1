#!/bin/bash

. ../config/config.ini

## init
cd $BLOCKPATH

## COMMAND GET
jsonMessage=$1
jsonMessage=$(echo "$jsonMessage"| sed "s/'/\"/g")
command=$(echo "${jsonMessage}"  | jq -r '.command')
appType=$(echo "${jsonMessage}"  | jq -r '.appType')
fromSocket=$(echo ${jsonMessage}  | jq -r '.socketID')

## Functions ##################################################

[ ! -f $BLOCKPATH/blk.pending ] && touch $BLOCKPATH/blk.pending


. $ROOTDIR/bin/functBlockFromNetwork.sh
. $ROOTDIR/bin/functTransactionFromNetwork.sh
. $ROOTDIR/bin/functMapFunc2Code.sh
. $ROOTDIR/bin/notification.sh


ppassword() {
        ## this function created global Password variable to put OpenSSL command line.
        ## it can be change in socket development

                ##  NEED TO CHACK IF PASSWORD REQUIRED ###
        unset Password
        prompt="Enter Password:"
        while IFS= read -p "$prompt" -r -s -n 1 char
        do
                if [[ $char == $'\0' ]]
                then
                        break
                fi
        prompt='*'
        Password+="$char"
        done
        openssl rsa -noout -in $privateKeyFile -passin "pass:${Password}"
        if [ $? -ne 0 ];then
                echo "Private Key password is wrong. Please check again"
                exit 1
        fi
}


findBlocks() {
        CURRENTBLOCK=`ls -1 *.blk | tail -1`

        # If there is no current block in the current directory then exit
        [[ -z $CURRENTBLOCK ]] && echo "No blockchain in current folder!  Try using ./bashcoin minegenesis to start a new blockchain." && exit 1

        # Get the current block's number
        CURRENTBLOCKNUM=`echo $CURRENTBLOCK | sed 's/.blk//g'`

        # If the genesis block is the only block then break out of the findBlocks function before we look for previous blocks
        if [[ $CURRENTBLOCK == "1.blk" ]] ; then
                return
        fi

        PREVIOUSBLOCKNUM=`echo $CURRENTBLOCKNUM-1 | bc`
        PREVIOUSBLOCK=`echo $PREVIOUSBLOCKNUM.blk.solved`
        NEXTBLOCKNUM=`echo $CURRENTBLOCKNUM+1 | bc`
        NEXTBLOCK=`echo $NEXTBLOCKNUM.blk`

        PREVHASH=`md5sum $PREVIOUSBLOCK | cut -d" " -f1`
}

checkSyntax () {
        # Checks to see if difficulty was setup properly
        if [ $DIFF -lt 1 ] || [ $DIFF -gt 32 ]
                then
                echo "Please set difficulty to 1 through 32"
                exit 1
        fi
        #echo "Previous Block:                                               "$PREVIOUSBLOCK
        #echo "Current Block:                                "$CURRENTBLOCK
        SESSION_MESSAGE="{"\"command\"":"\"checkSyntax\"",\"status\":0,\""PREVIOUSBLOCK\"":\""$PREVIOUSBLOCK\"","CURRENTBLOCK":"\"$CURRENTBLOCK\""}"        
        #SESSION_MESSAGE=$SESSION_MESSAGE\'
        #printf 'visit:%s\n' "$site"
        #echo $SESSION_MESSAGE
}

setup () {
        # Build the difficulty zeros based on DIFF variable
        while [ $DIFFPLUS != $DIFF ] ; do
                DIFFZEROS=$(echo $DIFFZEROS"0")
                let "DIFFPLUS += 1"
        done
 }



chooseHihFeeTransactions() {
        transactionsFile=$1
        tempFolder="$tempRootFolder/$RANDOM"
        mkdir $tempFolder
        cat $transactionsFile | grep "TX*"| head -$topHighFeeTransactions| sort -nr -t ':' -k5 | while read highFeeTransactions; do
                ## take relatedtransaction for own balance change
                sender=$(echo ${highFeeTransactions}| awk -v FS=':' '{print $2}')
                reciever=$(echo ${highFeeTransactions}| awk -v FS=':' '{print $3}')
                transactionsTime=$(echo ${highFeeTransactions}| awk -v FS=':' '{print $6}')
                echo $highFeeTransactions
                # this is balance change, no need to take fee from that. fee already in send-reciever transacrtion.
                cat $transactionsFile| grep 'ˆTX'| awk -v transactionsTime=$transactionsTime -v sender=$sender -v reciever=$reciever -v FS=':' '{if ($2==sender && $3==reciever && $6==transactionsTime) print}'
        done | sort  -t ":" -k1,1 -u

}


validateTransactionsForMine() {
        ## ADD EACH TRANSCATION ACCOUNT CHECK (historical )
        tempFolder="$tempRootFolder/$RANDOM"
        mkdir $tempFolder
        res=$(cat blk.pending | grep "TX*")
        cat blk.pending | grep "TX*"| while read transactions; do
                if [ ${#transactions} -eq 0 ]; then break; fi
                echo ${transactions}| awk -v FS=':' '{print $1":"$2":"$3":"$4":"$5":"$6}' > $tempFolder/transactions.msg
                echo ${transactions}| awk -v FS=':' '{print $7}'| base64 -d > $tempFolder/transactions.pub
                echo ${transactions}| awk -v FS=':' '{print $8}'| base64 -d > $tempFolder/transactions.sig
                openssl dgst -verify $tempFolder/transactions.pub -keyform PEM -sha256 -signature $tempFolder/transactions.sig -binary $tempFolder/transactions.msg > /dev/null
                if [ $? -eq 0 ]; then
                        echo $transactions >> $tempFolder/currentValidTransactions.tmp
                fi
        done
        # if file exist with non zero size, add them to next blk file to mine
        if [[ -s $tempFolder/currentValidTransactions.tmp ]] ; then
                chooseHihFeeTransactions $tempFolder/currentValidTransactions.tmp
        fi

}

buildWIPBlock () {
        DATE=$(date -u)
        # Actually sign should be sent by Wallet or Mine App. Because they keep private key
        #SIGN=$1
        printf "`cat $CURRENTBLOCK`\n"    >  $CURRENTBLOCK.wip
        printf "HEADERS:\n"               >> $CURRENTBLOCK.wip
        printf "BLOCKID:$CURRENTBLOCK.solved\n" >> $CURRENTBLOCK.wip
        printf "Version:$version\n"      >> $CURRENTBLOCK.wip
        printf "Difficulty:$DIFF\n"      >> $CURRENTBLOCK.wip
        printf "DateTime:$DATE\n"        >> $CURRENTBLOCK.wip
        echo  >> $CURRENTBLOCK.wip
        echo  >> $CURRENTBLOCK.wip
        ## this is valid transactions
        validateTransactionsForMine >> $CURRENTBLOCK.wip
        ## build transaction for reward (need to add sign also)
        SENDER=$(cat ${publicKeyFile}| sha256sum | cut -d" " -f1)
        dateTime=$(date "+%Y%m%d%H%M%S")
        HASH_TRANSACTION=$(echo REWARD:${SENDER}:${REWARD_COIN}:0:${dateTime}| sha256sum| cut -d" " -f1)
        SIGN=$(echo TX$HASH_TRANSACTION:REWARD:${SENDER}:${REWARD_COIN}:0:${dateTime} | openssl dgst -sign ${privateKeyFile} -keyform PEM -sha256 -passin pass:$Password| base64 | tr '\n' ' ' | sed 's/ //g')
        SENDER_PUBKEY=$(cat ${publicKeyFile}| base64 |tr '\n' ' '| sed 's/ //g'  )
        echo TX$HASH_TRANSACTION:REWARD:${SENDER}:${REWARD_COIN}:0:${dateTime}:$SENDER_PUBKEY:$SIGN >> $CURRENTBLOCK.wip
        ## add block sign to block
        echo >> $CURRENTBLOCK.wip
        echo >> $CURRENTBLOCK.wip
        echo "## SIGNATURE: #################################################################################" >> $CURRENTBLOCK.wip
        echo "BlockSignPublicKey: $SENDER_PUBKEY" >> $CURRENTBLOCK.wip
        echo "BlockSignSIGNATURE: $(cat $CURRENTBLOCK.wip| openssl dgst -sign ${privateKeyFile} -keyform PEM -sha256 -passin pass:$Password| base64 | tr '\n' ' ' | sed 's/ //g')" >> $CURRENTBLOCK.wip
        #echo "buildWIPBlock ....."
}


mine () {
        commandCode=$(mapFunction2Code ${FUNCNAME[0]} code)
        errorCode=$(mapERRORFunction2Code ${FUNCNAME[0]})
        ## ADD CONTROL. THIS MESSAGE SHOULD COME FROM INTERNAL IP ADDRESS. (MINER GUI)
        ## THIS MESSAGE IS BROADCAST
        fromSocket=$(echo ${jsonMessage}  | jq -r '.socketID')
        # start mining, check to see if the hash starts with the winning number of zeros and if it does complete the loop
        while [ $ZEROS != $DIFFZEROS ]
        do
                        # increase the nonce by one
                        let "NONCE += 1"
                        # do the hashing
                        HASH=$(printf "`cat $CURRENTBLOCK.wip`\n\n## Nonce: #################################################################################\n$NONCE\n" | md5sum)
                        HASH=$(echo $HASH | cut -d" " -f1)
                        # print the hash to the screen because it looks cool
                        #echo $HASH
                        # cut the leading zeros off the hash
                        ZEROS=$(echo $HASH | cut -c1-$DIFF)
        done

        # THIS IS IMPORTANT STEP
        if [ -f $CURRENTBLOCK.solved ]; then 
                # if file exist already, it means already someone mined and added as a file.
                # return ERROR and exit. Let cliend send again mine command to mine next block.
                echo "{\"command\":\"mine\",\"commandCode\":\"$errorCode\",\"appType\":\"$appType\",\"messageType\":\"direct\",\"status\":\"2\", \"timeUTC\":\"$(date -u  +"%Y%m%d%H%M%S")\",\"message\":\"$CURRENTBLOCK is already added by someone in the network\"}"
                # destroy tmp BLOCK file with included transactions
                rm -f $CURRENTBLOCK.wip
                exit 1

        fi 
        printf "`cat $CURRENTBLOCK.wip`\n\n## Nonce: #################################################################################\n$NONCE\n" > $CURRENTBLOCK.solved

        if [ $? -eq 0 ]; then
                ## if mined successfully then remomove transaction from pending which are already in block
                [[ -s blk.pending ]] && cat $CURRENTBLOCK.solved | grep TX| while read lines; do
                        txID=$(echo ${lines}| awk -v FS=':' '{print $1}')
                        sed -i "/$txID/d" blk.pending 
                done
        fi


        # Setup the next block.  Add previous hash first
        printf "## Previous Block Hash: ###################################################################\n" >> $NEXTBLOCK
        printf "$HASH\n\n" >> $NEXTBLOCK


        NEXT_BASE64=$(cat ${NEXTBLOCK}| base64 |tr '\n' ' ' | sed 's/ //g')
        CURRENTBLOCK_BASE64=$(cat ${CURRENTBLOCK}.solved | base64 |tr '\n' ' ' | sed "s/ //g")
        #echo "{\"command\":\"notification\",\"commandCode\":\"302\",\"appType\":\"$appType\",\"messageType\":\"broadcast\",\"status\":\"0\", \"result\":[\"$CURRENTBLOCK_BASE64\",\"$NEXT_BASE64\"]}"
        # send askBlockContent 
        echo "{\"command\":\"notification\",\"host\":\"$(hostname)\",\"commandCode\":\"301\",\"messageType\":\"broadcast\",\"status\":\"0\", \"result\":[\"${CURRENTBLOCK}.solved\",\"${NEXTBLOCK}\"]}"

        rm -f $CURRENTBLOCK.wip
        rm -f $CURRENTBLOCK
}

mineGenesis () {
        commandCode=$(mapFunction2Code ${FUNCNAME[0]} code)
        errorCode=$(mapERRORFunction2Code ${FUNCNAME[0]})
        # first check to see if there is a blockchain already, if so exit so we don't overwrite
        [[ -f 1.blk.solved ]] && echo "A mined Genesis block already exists in this folder!" && exit 1

        # start mining, check to see if the hash starts with the winning number of zeros and if it does complete the loop
  while [ $ZEROS != $DIFFZEROS ]
  do
                                                                        # increase the nonce by one
          let "NONCE += 1"
                                                                        # do the hashing
          HASH=$(printf -- "`cat $1`\n\n## Nonce: #################################################################################\n$NONCE\n" | md5sum)
                                                                        HASH=$(echo $HASH | cut -d" " -f1)
                                                                        # print the hash to the screen because it looks cool
          echo $HASH
                                                                        # cut the leading zeros off the hash
          ZEROS=$(echo $HASH | cut -c1-$DIFF)
  done

        #echo "Success!"
        #echo "Nonce:    " $NONCE
        #echo "Hash:     " $HASH

        printf -- "`cat $1`\n\n## Nonce: #################################################################################\n$NONCE\n" > 1.blk.solved
        #printf "$HASH\n" > 1.blk.hash

  # Setup the next block.  Add previous hash first
        printf "## Previous Block Hash: ###################################################################\n" >> 2.blk
        printf "$HASH\n\n" >> 2.blk
}




checkAccountBal () {
        commandCode=$(mapFunction2Code ${FUNCNAME[0]} code)
        errorCode=$(mapFunction2Code ${FUNCNAME[0]})
        errorCode=$(mapERRORFunction2Code ${FUNCNAME[0]})
        fromSocket=$(echo ${jsonMessage}  | jq -r '.socketID')
        ACCTNUM=$(echo ${jsonMessage}  | jq -r '.ACCTNUM')
        #ACCTNUM=$1
        #return_row=$2
        # Get the value of the last change transaction (the last time a user sent money back to themselves) if it exists
        for i in `ls *blk* -1 | grep -v exipred| sort -nr`; do
                        LASTCHANGEBLK=`grep -l -m 1 .*:$ACCTNUM:$ACCTNUM:.* $i`
                        [[ $LASTCHANGEBLK ]] && break
        done

        # If there was a change transaction get the value, if not print "Account has never spent money."
        [[ $LASTCHANGEBLK ]] && LASTCHANGE=`grep $ACCTNUM:$ACCTNUM $LASTCHANGEBLK | tail -1` || 
        #echo "{\"command\":\"checkbalance\",\"status\":\"2\",\"destinationSocket\":\"$fromSocket\",\"result\":{\"publicKeyHASH256\":\"$ACCTNUM\",\"message\":\"Account has never spent BashCoin.\"}}"

        # If account has never spent money then set LASTCHANGE to zero, if it has, separate out the tx number and value of that transaction
        [[ $LASTCHANGE ]] && LASTCHANGETX=`echo $LASTCHANGE | cut -d":" -f 1 | sed 's/TX//'` && LASTCHANGE=`echo $LASTCHANGE | cut -d":" -f 4` || LASTCHANGE=0

        # Print the value of the last change transaction (the value of the users account before any other received transactions)
        #echo Last Change = $LASTCHANGE
        #echo Last Change Transaction Number = $LASTCHANGETX

        # Get all of the receiving transactions after last change in the last change block and add them together
        if [[ $LASTCHANGEBLK ]]
                        then
                                        RECAFTERCHANGE=`sed "1,/TX$LASTCHANGETX/d" $LASTCHANGEBLK | grep .*:.*:$ACCTNUM:.* | cut -d":" -f4 | paste -sd+ | bc`
                                        [[ $RECAFTERCHANGE ]] || RECAFTERCHANGE=0
                                        #echo "Received after last change tx (same blk) = $RECAFTERCHANGE"
                        else
                                        LASTCHANGEBLK=1.blk.solved
                                        RECAFTERCHANGE=`grep .*:.*:$ACCTNUM:.* $LASTCHANGEBLK | cut -d":" -f4 | paste -sd+ | bc`
            [[ $RECAFTERCHANGE ]] || RECAFTERCHANGE=0
            #echo "Received after last change tx (same blk)(genesis) = $RECAFTERCHANGE"
        fi
        #echo $LASTCHANGEBLK
        # Get all the receiving transactions after last change block and add them together
        SUM=0
        if [[ $LASTCHANGEBLK == 1.blk.solved ]]
                        then
      for i in `ls -1 *.blk*| sort -n`; do
        [[ `grep .*:.*:$ACCTNUM:.* $i` ]] && SUM=$SUM+`grep .*:.*[^$ACCTNUM]*:$ACCTNUM:.* $i | cut -d":" -f4 | paste -sd+ | bc` || SUM=$SUM+0
      done
                        else
                                        for i in `ls -1 *blk*| grep -v expired| sort -n | sed "1,/$LASTCHANGEBLK/d"`; do
        [[ `grep .*:.*:$ACCTNUM:.* $i` ]] && SUM=$SUM+`grep .*:.*[^$ACCTNUM]*:$ACCTNUM:.* $i | cut -d":" -f4 | paste -sd+ | bc` || SUM=$SUM+0
      done
        fi
        SUM=`echo $SUM | bc`
        [[ $SUM ]] || SUM=0
        #echo "Received after last change tx (remaining blk's)= $SUM"

        # Add last change value and received money since then
        TOTAL=`echo $LASTCHANGE+$RECAFTERCHANGE+$SUM`
        TOTAL=`echo $LASTCHANGE+$RECAFTERCHANGE+$SUM | bc`
        #echo "Current Balance for $ACCTNUM:     $TOTAL"
        #echo "{\'command\':'getBalance\',\'publicKeyHASH256\':\'$ACCTNUM\',\'status\':\'0\',\'balance\':\'$TOTAL\',\'description\':\'none\'}"
        echo "{\"command\":\"checkbalance\",\"commandCode\":\"$commandCode\",\"messageType\":\"direct\" , \"status\":\"0\",\"destinationSocket\":$fromSocket,\"result\":{\"publicKeyHASH256\":\"$ACCTNUM\",\"balance\":\"$TOTAL\"}}"
}





validate() {
        fromSocket=$(echo ${jsonMessage}  | jq -r '.socketID'|sed "s/\"//g")
        errorCode=$(mapERRORFunction2Code ${FUNCNAME[0]})
        # Check that there are blocks to validate
        NUMSOLVEDFILES=`ls -1 *.solved | wc -l`
        (( $NUMSOLVEDFILES < 1 )) && echo "Blockchain must be greater than 1 block to validate" && exit 1

        for i in `ls -1 *solved| sort -n| tail -n +2`; do
                        h=`ls -1 | grep solved$ | sort -n| grep -B 1 $i | head -1`
                        j=`ls -1 | egrep "solved$|blk$" | sort -n| grep -A 1 $i | head -2| grep -v $i | tail -1`
                        PREVHASH=`md5sum $h | cut -d" " -f1`
                        CALCHASH=`sed "2c$PREVHASH" $i | md5sum | cut -d" " -f1`
                        REPORTEDHASH=`sed -n '2p' $j` 
                        [[ $CALCHASH != $REPORTEDHASH ]] && 
                        echo "{ \"command\":\"validate\", \"status\":2,\"destinationSocket\":$fromSocket,\"message\":\"Hash mismatch!  $i has changed!  Do not trust any block after and including $i\"}" &&
                        exit 1
                        #echo "Hash mismatch!  $i has changed!  Do not trust any block after and including $i"
                        #echo "Hashes match! $i is a good block."
        done
        #echo "{ \"command\":\"validate\", \"status\":0,\"destinationSocket\":\"$fromSocket\",\"message\":\"Good blocks\"}"
}

terminateMessaging() {
        echo Nothing > /dev/null
}


case "$command" in
        mine)
                        #ppassword
                        validate
                        findBlocks
                        checkSyntax
                        setup
                        buildWIPBlock
                        mine
                        exit 0
                        ;;
        minegenesis|minegen)
                        #shift
                        [[ -z $@ ]] && echo "Usage: ./bashCoin minegenesis <filename>" && echo "This command mines the first block (any file you like)." && exit 1
                        echo "Setup function is working now"
			setup
			echo "mine Generis block function is working now"
                        mineGenesis $1
                        ;;
        send)
                        #ppassword
                        shift
                        [[ -z $@ ]] && echo "Usage: ./bashCoin send <amount> <toAddress> <fromAddress>" && exit 1
                        findBlocks
                        send $@
                        exit 0
                        ;;
        checkbalance|checkbal|bal)
                        #shift
                        [[ -z $@ ]] && echo "Usage: ./bashCoin bal <address>" && exit 1
                        checkAccountBal $1
                        exit 0
                        ;;
        findblocks)
                        findBlocks
                        ;;
        validateblockchain|validate|val)
                        validate
                        exit 0
                        ;;
        listNewBlock)
                        listNewBlock $@
                        exit 0
                        ;;
        getTransactionMessageForSign)
                        shift
                        getTransactionMessageForSign $@
                        exit 0
                        ;;
        provideBlockContent)
                        provideBlockContent $@
                        exit 0
                        ;;
        AddNewBlockFromNode)
                        AddNewBlockFromNode $@
                        validate
                        exit 0
                        ;;
        askBlockContent)
                        askBlockContent $@
                        exit 0
                        ;;
        pushSignedMessageToPending)
                        pushSignedMessageToPending $@
                        ;;
        updateNetworkInfo)
                        updateNetworkInfo $@
                        ;;
        nothing)        
                        ## this is dummy for troubleshooting. Never mind
                        exit 0
                        ;;
        notification)
                        notification $@
                        #echo $jsonMessage
                        exit 0
                        ;;
        terminateMessaging)
                        terminateMessaging
                        exit 0
                        ;;
        help)
                        #echo $"Usage: $0 {mine|send|checkbalance(bal)|minegenesis(minegen)}"
                        echo "{\"command\":\"help\",\"description\":\"get more detail from https://bitqap.github.io/info\",\"messageType\":\"direct\"}"
                        exit 1
                        ;;
        *)
                        echo "{\"command\":\"doNothing\",\"description\":\"get more detail from https://bitqap.github.io/info\",\"messageType\":\"direct\"}"
                        ;;
esac


exit 0