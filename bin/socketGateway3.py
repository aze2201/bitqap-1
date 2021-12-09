#!/usr/bin/python
from websocket_server import WebsocketServer
import threading
import time
import json
import socket

import logging
import traceback
import requests

threads = []
clients = {}

#   {"command":"mine","appType":"wallet"} / {"command":"mine","appType":"miner","messageType":"direct"}
#   {"command":"notification","messageType":"direct"}
#   {"command":"checkbalance","ACCTNUM":"50416596951b715b7e8e658de7d9f751fb8b97ce4edf0891f269f64c8fa8e034","messageType":"direct"}
#   {"command":"listNewBlock","fromBlockID":70,"messageType":"direct"}
#   {"command":"provideBlocks","messageType":"direct","result": ["blk.pending","133.blk.solved","132.blk.solved","131.blk.solved"]}
#   {"command":"AddBlockFromNetwork","messageType":"direct","result": ["base64","base64"]}
#   {"command":"getTransactionMessageForSign","messageType":"direct","ACCTNUM":"50416596951b715b7e8e658de7d9f751fb8b97ce4edf0891f269f64c8fa8e034","RECEIVER":"b1bd54c941aef5e0096c46fd21d971b3a3cf5325226afb89c0a9d6845a491af6","AMOUNT":5,"FEE":3,"DATEEE":"202111121313"}
#   {"command":"pushSignedMessageToPending", "messageType": "direct", "result": ["50416596951b715b7e8e658de7d9f751fb8b97ce4edf0891f269f64c8fa8e034:b1bd54c941aef5e0096c46fd21d971b3a3cf5325226afb89c0a9d6845a491af6:5:3:202111121313","50416596951b715b7e8e658de7d9f751fb8b97ce4edf0891f269f64c8fa8e034:50416596951b715b7e8e658de7d9f751fb8b97ce4edf0891f269f64c8fa8e034:38:0:202111121313"]}
#   {"command":"validate"} // CLI


def getRoot():
    result=''
    locals=[]
    for i in clients:
        if clients[i]['address'][0]=='127.0.0.1':
            locals.append(i)
    return locals

# FIND local SH (main)
def WhereBashCoin(jsonData,serchKey,valueIs,printKeyValue):
    ## This function return client ID of bashCoin.sh connection. It can be done by secret
    ## WhereBashCoin(clients,'destinationSocketBashCoin',<yes>,'id')
    for i in clients:
        if serchKey in jsonData[i]:
            if jsonData[i][serchKey]==str(valueIs):
                return jsonData[i][printKeyValue]



def client_left(client, server):
    msg = {'message':"client left"}
    try:
        clients.pop(client['id'])
        ### BU LAZIMDI KI, PORTU DA ELAVE EDESEN. SILENDE LAZIM OLACAQ. 
        #allConnected.pop([selfIPaddress,client['address'][0]])
    except:
        print ("Error in removing client %s" % client['id'])
    for cl in clients.values():
        server.send_message(cl, str(msg))


# This list for build connected device list. Client Graph algo will find whether it can reach main network or not.
selfIPaddress = requests.get('https://checkip.amazonaws.com').text.strip()
allConnected=[]

def new_client(client, server):
    # connection list
    allConnected.append([selfIPaddress,client['address'][0]])
    #msg={"command":"updateInfo","peers":allConnected}
    msg={"command":"nothing","peers":allConnected}
    clients[client['id']] = client
    print ("Connected Example: "+str(clients))
    server.send_message(clients[client['id']], str(msg).replace("u'","'").replace("'","\""))

def new_client1(client, server):
    # connection list
    allConnected.append([selfIPaddress,client['address'][0]])
    msg={'command':'connectionUpdate','connections':allConnected}
    clients[client['id']] = client    
    #server.send_message(clients[WhereBashCoin(clients,'destinationSocketBashCoin','yes','id')], str(msg).replace("u'","'").replace("'","\""))
    print ("Connected Example: "+str(clients))


def msg_received(client, server, msg):
    # Handle messages routing between clients
    global destination
    if msg != "":
        try:
            msg=json.loads(str(msg).encode('utf-8'))
            ## this is inital for communication_pipe client
            if 'destinationSocketBashCoin' in msg:
                client['destinationSocketBashCoin']=msg['destinationSocketBashCoin']
            if client['id'] in getRoot():
            ################################# MESAGE FROM LOCALHOST  #################################
                if 'destinationSocket' in msg:
                    # this message comes from bashCoin.sh. Becasue SH script sets destinationSocket based on SocketID.
                    destination=msg['destinationSocket']
                else:
                    # Possible come from local SH
                    if msg['messageType']=='broadcast':
                        ## MAKE THIS BY SECRET FILE CODE
                        # python3 wsdump.py  -r --text '{"command":"nothing","appType":"nothing","destinationSocketBashCoin":"yes"}' ws://127.0.0.1:8001
                        for i in clients:
                            if clients[i]['id'] != WhereBashCoin(clients,'destinationSocketBashCoin','yes','id'):
                                # message will not go to SH
                                print ("001 TO -> "+str(clients[i]['id'])+"\n"+"MSG -> "+str(msg))
                                server.send_message(clients[i], str(msg).replace("u'","'").replace("'","\""))
                    else:
                        # messageType=direct and comes from Local (getRoot) means to SH
                        # put socketID to be able for get response by SH
                        destination=WhereBashCoin(clients,'destinationSocketBashCoin','yes','id')
                        msg.update({'socketID':client['id']})
                        cl = clients[destination]
                        print ("002 TO -> "+str(clients[destination]['id'])+"\n"+"MSG -> "+str(msg))
                        server.send_message(cl, str(msg).replace("u'","'").replace("'","\""))
            else:
            ################################### MESAGE FROM EXTERNAL ########################
                ## SECURITY: put command list from external to internal.
                if msg['command'] in ['help','AddBlockFromNetwork','provideBlocks','notification','nothing','listNewBlock','getTransactionMessageForSign','checkbalance','pushSignedMessageToPending','price']:
                    # socketID is message originator always
                    msg.update({'socketID':client['id']})
                    if msg['messageType']=='direct':
                        ## MAKE THIS BY SECRET FILE CODE
                        print ("003 TO -> "+str(WhereBashCoin(clients,'destinationSocketBashCoin','yes','id'))+"\n"+"MSG -> "+str(msg))
                        server.send_message(clients[WhereBashCoin(clients,'destinationSocketBashCoin','yes','id')], str(msg).replace("u'","'").replace("'","\""))
                    if msg['messageType']=='broadcast':
                        ## THIS IS DANGER. NEED TO CONTROL MESSAGE CONTENT not to Broadcast
                        for i in clients:
                            ## send to all except source
                            if clients[i]['id'] != msg['socketID']:
                                print ("004 TO -> "+str(clients[i]['id'])+"\n"+"MSG -> "+str(msg))
                                server.send_message(clients[i], str(msg).replace("u'","'").replace("'","\""))
        except Exception as e:
            logging.error(traceback.format_exc())
            print ("Problem "+str(msg)+", and PROBLEM is "+str(e))


server = WebsocketServer(host='0.0.0.0',port=8001,loglevel=logging.DEBUG)
#server = WebsocketServer(host='0.0.0.0',port=8001,key=certFile, cert="/root/peer2peer/cert/cert.pem",loglevel=logging.DEBUG)
server.set_fn_client_left(client_left)
server.set_fn_new_client(new_client)
server.set_fn_message_received(msg_received)
server.run_forever()
