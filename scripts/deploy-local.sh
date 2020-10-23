#!/usr/bin/env bash

echo
echo -e "${TXGRN}STEP${TXNC} Authenticate Service Account: gcloud auth activate-service-account"
echo
gcloud auth activate-service-account $SERVICE_ACCT_EMAIL \
  --key-file $SERVICE_ACCT_KEYFILE_PATH \
  --project $PROJECT

for function in ${functions[@]}; do
  processingDeploymentVars=0
  processingRuntimeVars=0
  functionName=$STAGE-$MICROSERVICE-ms-$function
  
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
    elif [[ $processingRuntimeVars -eq 1 && $STAGE == 'dev' ]]; then
      getvar
      envarr+=($var)
    else
      : # ingored
    fi
  done < src/functions/$function/.env

  echo
  echo -e "${TXGRN}STEP${TXNC} Preparing Function: $functionName"
  echo runtime: $RUNTIME
  echo maxAllocatedMemory: $MEMORY
  echo executionTimeout: $TIMEOUT
  echo runtimeVariables: $(IFS=$','; echo "${envarr[*]}")
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
      --set-env-vars $(IFS=$','; echo "${envarr[*]}") \
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
      --set-env-vars $(IFS=$','; echo "${envarr[*]}") \
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
      --set-env-vars $(IFS=$','; echo "${envarr[*]}") \
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
