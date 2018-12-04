#!/bin/bash
# Setup Development Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Parks Development Environment in project ${GUID}-parks-dev"

# Code to set up the parks development project.

sleep 60

oc project ${GUID}-parks-dev
# Grant the correct permissions to the Jenkins service account
oc policy add-role-to-user edit system:serviceaccount:${GUID}-jenkins:jenkins -n ${GUID}-parks-dev
oc policy add-role-to-user admin system:serviceaccount:gpte-jenkins:jenkins -n ${GUID}-parks-dev
#----- Commands for MLBParks app -----
oc new-build --binary=true --name="mlbparks" jboss-eap70-openshift:1.6 -n ${GUID}-parks-dev
oc new-app ${GUID}-parks-dev/mlbparks:0.0-0 --name=mlbparks --allow-missing-imagestream-tags=true -l type=parksmap-backend -n ${GUID}-parks-dev
# Create a MongoDB configMap 
oc create configmap mlbparks-config \
 --from-literal=DB_HOST=mongodb \
 --from-literal=DB_PORT=27017 \
 --from-literal=DB_USERNAME=mongodb \
 --from-literal=DB_PASSWORD=mongodb \
 --from-literal=DB_NAME=parks \
 --from-literal=DB_REPLICASET=rs0 \
 --from-literal=APPNAME="MLB Parks (Dev)" \
 -n ${GUID}-parks-dev
oc set env --from=configmap/mlbparks-config dc/mlbparks -n ${GUID}-parks-dev
oc set triggers dc/mlbparks --remove-all -n ${GUID}-parks-dev
# expose the deployment config and service
oc expose dc/mlbparks --port 8080 -n ${GUID}-parks-dev
oc expose svc/mlbparks -n ${GUID}-parks-dev
# Readiness and liveness probes
oc set probe dc/mlbparks --readiness --get-url=http://:8080/ws/healthz/ --failure-threshold=3 --initial-delay-seconds=60 --timeout-seconds=1 -n ${GUID}-parks-dev
oc set probe dc/mlbparks --liveness --failure-threshold=3 --initial-delay-seconds=60 -- echo ok --timeout-seconds=1 -n ${GUID}-parks-dev

#----- Commands for NationalParks app -----#
oc new-build --binary=true --name="nationalparks" redhat-openjdk18-openshift:1.2 -n ${GUID}-parks-dev
oc new-app ${GUID}-parks-dev/nationalparks:0.0-0 --name=nationalparks --allow-missing-imagestream-tags=true -l type=parksmap-backend -n ${GUID}-parks-dev
# Create a MongoDB configMap
oc create configmap nationalparks-config \
 --from-literal=DB_HOST=mongodb \
 --from-literal=DB_PORT=27017 \
 --from-literal=DB_USERNAME=mongodb \
 --from-literal=DB_PASSWORD=mongodb \
 --from-literal=DB_NAME=parks \
 --from-literal=DB_REPLICASET=rs0 \
 --from-literal=APPNAME="National Parks (Dev)" \
 -n ${GUID}-parks-dev
oc set env --from=configmap/nationalparks-config dc/nationalparks -n ${GUID}-parks-dev
#
oc set triggers dc/nationalparks --remove-all -n ${GUID}-parks-dev
oc expose dc/nationalparks --port 8080 -n ${GUID}-parks-dev
oc expose svc/nationalparks -n ${GUID}-parks-dev
# readiness and liveness probes
oc set probe dc/nationalparks --readiness --get-url=http://:8080/ws/healthz/ --failure-threshold=3 --initial-delay-seconds=60 -n ${GUID}-parks-dev
oc set probe dc/nationalparks --liveness --failure-threshold=3 --initial-delay-seconds=60 -- echo ok -n ${GUID}-parks-dev

#----- Commands for Parksmap app -----#
oc new-build --binary=true --name="parksmap" redhat-openjdk18-openshift:1.2 -n ${GUID}-parks-dev
oc new-app ${GUID}-parks-dev/parksmap:0.0-0 --name=parksmap --allow-missing-imagestream-tags=true -n ${GUID}-parks-dev
# Create a MongoDB configMap
oc create configmap parksmap-config \
 --from-literal=DB_HOST=mongodb \
 --from-literal=DB_PORT=27017 \
 --from-literal=DB_USERNAME=mongodb \
 --from-literal=DB_PASSWORD=mongodb \
 --from-literal=DB_NAME=parks \
 --from-literal=DB_REPLICASET=rs0 \
 --from-literal=APPNAME="ParksMap (Dev)" \
 -n ${GUID}-parks-dev
oc set env --from=configmap/parksmap-config dc/parksmap -n ${GUID}-parks-dev
# give parksmap permission to discover routes
oc policy add-role-to-user view --serviceaccount=default -n ${GUID}-parks-dev
#
oc set triggers dc/parksmap --remove-all -n ${GUID}-parks-dev
oc expose dc/parksmap --port 8080 -n ${GUID}-parks-dev
oc expose svc/parksmap -n ${GUID}-parks-dev
# readiness and liveness probes
oc set probe dc/parksmap --readiness --get-url=http://:8080/ws/healthz/ --failure-threshold=3 --initial-delay-seconds=60 -n ${GUID}-parks-dev
oc set probe dc/parksmap --liveness --failure-threshold=3 --initial-delay-seconds=60 -- echo ok -n ${GUID}-parks-dev
