mapFunction2Code () {
        ######################################################################################################
        #                       2021.11.22
        # This function designed to return function code.
        # this function will be used on Notification. in "notification" command bashCoin.sh don't do anything.
        # because of command bashCoin return command itself on result. 
        # But code will help us to execute some action.
        funcName=$1
        type=$2
        case "$funcName" in 
                mine|100)
                                code=100
                                name=mine
                                ;;
                mineGenesis|101)
                                code=101
                                name=mineGenesis
                                ;;
                checkAccountBal|200)
                                code=200
                                name=checkAccountBal
                                ;;
                getTransactionMessageForSign|201)
                                code=201
                                name=getTransactionMessageForSign
                                ;;
                pushSignedMessageToPending|202)
                                code=202
                                name=pushSignedMessageToPending
                                ;;
                listNewBlock|300)
                                code=300
                                name=listNewBlock
                                ;;
                provideBlockContent|301)
                                code=301
                                name=provideBlockContent
                                ;;
                AddNewBlockFromNode|302)
                                code=302
                                name=AddNewBlockFromNode
                                ;;
                askBlockContent|303)
                                code=303
                                name=askBlockContent
                                ;;
                updateNetworkInfo|401)
                                code=401
                                name=updateNetworkInfo
                                ;;
                terminateMessaging|001)
                                code=001
                                name=terminateMessaging
                                ;;
                help)
                                code=002
                                name=help
                                ;;
                *)
                                code=000
                                ;;
        esac
        
        if [ "$type" == "code" ]; then
          echo $code
        fi

        if [ "$type" == "func" ]; then
          echo $name
        fi
}


mapERRORFunction2Code () {
        funcName=$1
        type=$2
        case "$funcName" in 
                mine)
                                code=500
                                name=mine
                                ;;
                mineGenesis)
                                code=501
                                name=mineGenesis
                                ;;
                checkAccountBal)
                                code=510
                                name=checkAccountBal
                                ;;
                getTransactionMessageForSign)
                                code=511
                                name=getTransactionMessageForSign
                                ;;
                pushSignedMessageToPending)
                                code=512
                                name=pushSignedMessageToPending
                                ;;
                AddNewBlockFromNode)
                                code=520
                                name=AddNewBlockFromNode
                                ;;
                listNewBlock)
                                code=521
                                name=listNewBlock
                                ;;
                provideBlockContent)
                                code=522
                                name=provideBlockContent
                                ;;
                validateNetworkBlockHash)
                                code=523
                                name=validateNetworkBlockHash
                                ;;
                askBlockContent)
                                code=524
                                name=askBlockContent
                                ;;
                updateNetworkInfo)
                                code=401
                                name=updateNetworkInfo
                                ;;
                *)
                                code=000
                                ;;
                esac
        echo $code
}