#!/bin/bash
# Setup Production Project (initial active services: Green)
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Parks Production Environment in project ${GUID}-parks-prod"

# Code to set up the parks production project. It will need a StatefulSet MongoDB, and two applications each (Blue/Green) for NationalParks, MLBParks and Parksmap.
# The Green services/routes need to be active initially to guarantee a successful grading pipeline run.

sleep 120

oc project ${GUID}-parks-prod
# Grant the correct permissions to pull images from the development project
oc policy add-role-to-group system:image-puller system:serviceaccounts:${GUID}-parks-prod -n ${GUID}-parks-dev
# Grant the correct permissions to the Jenkins service account
oc policy add-role-to-user edit system:serviceaccount:${GUID}-jenkins:jenkins -n ${GUID}-parks-prod
oc policy add-role-to-user admin system:serviceaccount:gpte-jenkins:jenkins -n ${GUID}-parks-prod

# create headless MongoDB service
oc create -f ./Infrastructure/templates/mongodb_internal.yaml -n ${GUID}-parks-prod
# create regular MongoDB service
oc create -f ./Infrastructure/templates/mongodb.yaml -n ${GUID}-parks-prod
# create the stateful cluster of MongoDBs
oc create -f ./Infrastructure/templates/mongo_statefulset.yaml -n ${GUID}-parks-prod
# allows parksmap app to look for routes
oc policy add-role-to-user view --serviceaccount=default -n ${GUID}-parks-prod

sleep 10
while : ; do
    oc get pod -n ${GUID}-parks-prod | grep -v deploy | grep "1/1"
    echo "Checking if MongoDB is Ready..."
    if [ $? == "1" ] 
      then 
      echo "Wait 10 seconds..."
        sleep 10
      else 
        break 
    fi
done
oc patch dc/mlbparks-blue  --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${GUID}-parks-prod
oc patch dc/mlbparks-green --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${GUID}-parks-prod

oc set triggers dc/mlbparks-blue  --remove-all -n ${GUID}-parks-prod
oc set triggers dc/mlbparks-green --remove-all -n ${GUID}-parks-prod

echo "Create Configmap MLBpark"
oc create configmap mlbparks-config --from-literal="APPNAME=MLB Parks (Green)" \
    --from-literal="DB_HOST=mongodb" \
    --from-literal="DB_PORT=27017" \
    --from-literal="DB_USERNAME=mongodb" \
    --from-literal="DB_PASSWORD=mongodb" \
    --from-literal="DB_NAME=parks" \
    --from-literal="DB_REPLICASET=rs0" \
    -n ${GUID}-parks-prod

oc set env dc/mlbparks-green --from=configmap/mlbparks-config -n ${GUID}-parks-prod

oc expose dc/mlbparks-green --port 8080 -n ${GUID}-parks-prod

oc expose svc/mlbparks-green --name mlbparks -n ${GUID}-parks-prod


echo "Setting up Nationalparks blue"
oc new-app ${GUID}-parks-dev/nationalparks:latest --name=nationalparks-blue  --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod

echo "Setting up Nationalparks green"
oc new-app ${GUID}-parks-dev/nationalparks:latest --name=nationalparks-green --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod

oc patch dc/nationalparks-blue  --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${GUID}-parks-prod
oc patch dc/nationalparks-green --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${GUID}-parks-prod

oc set triggers dc/nationalparks-blue  --remove-all -n ${GUID}-parks-prod
oc set triggers dc/nationalparks-green --remove-all -n ${GUID}-parks-prod

echo "Create config map national park"
oc create configmap nationalparks-config --from-literal="APPNAME=National Parks (Green)" \
    --from-literal="DB_HOST=mongodb" \
    --from-literal="DB_PORT=27017" \
    --from-literal="DB_USERNAME=mongodb" \
    --from-literal="DB_PASSWORD=mongodb" \
    --from-literal="DB_NAME=parks" \
    --from-literal="DB_REPLICASET=rs0" \
    -n ${GUID}-parks-prod

oc set env dc/nationalparks-green --from=configmap/nationalparks-config -n ${GUID}-parks-prod

oc expose dc/nationalparks-green --port 8080 -n ${GUID}-parks-prod

oc expose svc/nationalparks-green --name nationalparks -n ${GUID}-parks-prod


echo "Setting up Parksmap blue"
oc new-app ${GUID}-parks-dev/parksmap:latest --name=parksmap-blue  --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
echo "Setting up Parksmap green"
oc new-app ${GUID}-parks-dev/parksmap:latest --name=parksmap-green --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod

oc patch dc/parksmap-blue  --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${GUID}-parks-prod
oc patch dc/parksmap-green --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${GUID}-parks-prod

oc set triggers dc/parksmap-blue  --remove-all -n ${GUID}-parks-prod
oc set triggers dc/parksmap-green --remove-all -n ${GUID}-parks-prod

echo "Create config map Parksmap"
oc create configmap parksmap-config --from-literal="APPNAME=ParksMap (Green)" -n ${GUID}-parks-prod

oc set env dc/parksmap-green --from=configmap/parksmap-config -n ${GUID}-parks-prod

oc expose dc/parksmap-green --port 8080 -n ${GUID}-parks-prod

oc expose svc/parksmap-green --name parksmap -n ${GUID}-parks-prod