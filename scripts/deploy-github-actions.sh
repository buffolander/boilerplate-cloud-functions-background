#!/usr/bin/env bash

# Text Color
TXGRN="\033[0;32m" # GREEN
TXNC="\033[0m"

getvar () {
  IFS='#'
  read -a cmtarr <<< "$line"
  var=`echo ${cmtarr[0]} | xargs`
}

echo
echo -e "${TXGRN}STEP${TXNC} Retrieve Secrets: gcloud secrets versions access"
echo

IFS='#'; read -a envarr <<< $ENVSTR
for varKey in ${envarr[@]}; do
	varValue=`gcloud secrets versions access latest \
    --secret $varKey \
    --format='get(payload.data)' | tr '_-' '/+' | base64 -d`
  runtimeVars+="$varKey: $varValue"$'\n'
  echo "$varKey synced"
done
echo $runtimeVars > env.yaml

IFS=' '; read -a functions <<< $FUNCTIONS
for function in ${functions[@]}; do
  processingDeploymentVars=0
  processingRuntimeVars=0
  functionName=$MICROSERVICE-ms-$function
  
  while read line; do
    if [[ $line == *"DEPLOYMENT_VARIABLES"* ]]; then
      processingDeploymentVars=1
    elif [[ $line == *"RUNTIME_VARIABLES"* ]]; then
      processingRuntimeVars=1
    elif [[ $line == "#"* || $line == "" ]]; then
      : # ignored; only comments
    elif [[ $processingDeploymentVars -eq 1 && $processingRuntimeVars -eq 0 ]]; then
      getvar
      export $var
    else
      : # ingored
    fi
  done < src/functions/$function/.env

  echo
  echo -e "${TXGRN}STEP${TXNC} Preparing Function: $functionName"
  echo runtime: $RUNTIME
  echo maxAllocatedMemory: $MEMORY
  echo executionTimeout: $TIMEOUT
  echo runtimeVariables: n/a
  echo vpcConnector: $VPC_CONNECTOR
  echo
  echo functionTrigger: $TRIGGER
  
  cp ./.gcloudignore ./src/functions/$function/.gcloudignore
  cp ./package.json ./src/functions/$function/package.json
  if [[ $TRIGGER == "firestore" ]]; then
    echo collection: $COLLECTION
    echo event: $EVENT
    echo
    echo -e "${TXGRN}STEP${TXNC} Deploy Function: gcloud functions deploy $functionName"
    echo
    gcloud functions deploy $functionName \
      --entry-point handler \
      --source src/functions/$function \
      --runtime $RUNTIME \
      --memory $MEMORY \
      --timeout $TIMEOUT \
      --env-vars-file env.yaml \
      --egress-settings all \
      --vpc-connector $VPC_CONNECTOR \
      --trigger-resource "projects/$PROJECT/databases/(default)/documents/$COLLECTION/{id}" \
      --trigger-event "providers/cloud.firestore/eventTypes/document.$EVENT"
  elif [[ $TRIGGER == "pubsub" ]]; then
    echo topic: $TOPIC
    echo
    echo -e "${TXGRN}STEP${TXNC} Deploy Function: gcloud functions deploy $functionName"
    echo
    gcloud functions deploy $functionName \
      --entry-point handler \
      --source src/functions/$function \
      --runtime $RUNTIME \
      --memory $MEMORY \
      --timeout $TIMEOUT \
      --env-vars-file env.yaml \
      --egress-settings all \
      --vpc-connector $VPC_CONNECTOR \
      --trigger-topic $TOPIC
  elif [[ $TRIGGER == "storage" ]]; then
    echo resource: $RESOURCE
    echo event: $EVENT
    echo
    echo -e "${TXGRN}STEP${TXNC} Deploy Function: gcloud functions deploy $functionName"
    echo
    gcloud functions deploy $functionName \
      --entry-point handler \
      --source src/functions/$function \
      --runtime $RUNTIME \
      --memory $MEMORY \
      --timeout $TIMEOUT \
      --env-vars-file env.yaml \
      --egress-settings all \
      --vpc-connector $VPC_CONNECTOR \
      --trigger-resource $RESOURCE \
      --trigger-event "google.storage.object.$EVENT"
  else
    : # ignore
  fi
  rm -rf ./src/functions/$function/.gcloudignore
  rm -rf ./src/functions/$function/package.json
done
exit 0
