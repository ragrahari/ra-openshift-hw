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

### TO TEST ###

# Grant the correct permissions to pull images from the development project
oc policy add-role-to-group system:image-puller system:serviceaccounts:${GUID}-parks-prod -n ${GUID}-parks-dev
# Grant the correct permissions to the Jenkins service account
oc policy add-role-to-user edit system:serviceaccount:${GUID}-jenkins:jenkins -n ${GUID}-parks-prod
# create headless MongoDB service
oc create -f ../templates/mongodb_internal.yaml
# create regular MongoDB service
oc create -f ../templates/mongodb.yaml
# create the stateful cluster of MongoDBs
oc create -f ../templates/mongo_statefulset.yaml
# allows parksmap app to look for routes
oc policy add-role-to-user view --serviceaccount=default

#----- Commands for MLBParks app -----#
# Green
oc create configmap mlbparks-green-config \
 --from-literal=DB_HOST=mongodb \
 --from-literal=DB_PORT=27017 \
 --from-literal=DB_USERNAME=prod \
 --from-literal=DB_PASSWORD=prod \
 --from-literal=DB_NAME=mongodb \
 --from-literal=DB_REPLICASET=rs0 \
 --from-literal=APPNAME="MLB Parks (Green)" \
 -n ${GUID}-parks-prod
# Blue
oc create configmap mlbparks-blue-config \
 --from-literal=DB_HOST=mongodb \
 --from-literal=DB_PORT=27017 \
 --from-literal=DB_USERNAME=prod \
 --from-literal=DB_PASSWORD=prod \
 --from-literal=DB_NAME=mongodb \
 --from-literal=DB_REPLICASET=rs0 \
 --from-literal=APPNAME="MLB Parks (Blue)" \
 -n ${GUID}-parks-prod
# Needs to have proper APPNAME for grading to succeed. verify!
# Green deployment : APPNAME="MLB Parks (Green)"
oc new-app ${GUID}-parks-dev/mlbparks --name=mlbparks-green --allow-missing-imagestream-tags=true -l type=parksmap-backend -n ${GUID}-parks-prod
oc set triggers dc/mlbparks-green --remove-all -n ${GUID}-parks-prod
oc set env --from=configmap/mlbparks-green-config dc/mlbparks-green
oc expose svc/mlbparks-green --name=mlbparks
# Probes for green deployment
oc set probe dc/mlbparks-green --readiness --get-url=http://:8080/ws/healthz/ --failure-threshold=3 --initial-delay-seconds=15
oc set probe dc/mlbparks-green --liveness --failure-threshold 3 --initial-delay-seconds 30 -- echo ok
# Blue Deployment : APPNAME="MLB Parks (Blue)"
oc new-app ${GUID}-parks-dev/mlbparks --name=mlbparks-blue --allow-missing-imagestream-tags=true -l type=parksmap-backend-inactive -n ${GUID}-parks-prod
oc set resources dc/mlbparks-blue --limits=memory=512Mi,cpu=250m
oc set triggers dc/mlbparks-blue --remove-all -n ${GUID}-parks-prod
oc set env --from=configmap/mlbparks-blue-config dc/mlbparks-blue
# Probes for blue deployment
oc set probe dc/mlbparks-blue --readiness --get-url=http://:8080/ws/healthz/ --failure-threshold=3 --initial-delay-seconds=15
oc set probe dc/mlbparks-blue --liveness --failure-threshold 3 --initial-delay-seconds 30 -- echo ok

#----- Commands for nationalparks app -----#
# Green
oc create configmap nationalparks-green-config \
 --from-literal=DB_HOST=mongodb \
 --from-literal=DB_PORT=27017 \
 --from-literal=DB_USERNAME=prod \
 --from-literal=DB_PASSWORD=prod \
 --from-literal=DB_NAME=mongodb \
 --from-literal=DB_REPLICASET=rs0 \
 --from-literal=APPNAME="National Parks (Green)" \
 -n ${GUID}-parks-prod
# Blue
oc create configmap nationalparks-blue-config \
 --from-literal=DB_HOST=mongodb \
 --from-literal=DB_PORT=27017 \
 --from-literal=DB_USERNAME=prod \
 --from-literal=DB_PASSWORD=prod \
 --from-literal=DB_NAME=mongodb \
 --from-literal=DB_REPLICASET=rs0 \
 --from-literal=APPNAME="National Parks (Blue)" \
 -n ${GUID}-parks-prod
# Green Deployment
oc new-app ${GUID}-parks-dev/nationalparks --name=nationalparks-green --allow-missing-imagestream-tags=true -l type=parksmap-backend -n ${GUID}-parks-prod
oc set triggers dc/nationalparks-green --remove-all -n ${GUID}-parks-prod
oc set env --from=configmap/nationalparks-green-config dc/nationalparks-green
oc expose svc/nationalparks-green --name=nationalparks
# Probes for green deployment
oc set probe dc/nationalparks-green --readiness --get-url=http://:8080/ws/healthz/ --failure-threshold=3 --initial-delay-seconds=30
oc set probe dc/nationalparks-green --liveness --failure-threshold 3 --initial-delay-seconds 30 -- echo ok
# Blue Deployment
oc new-app ${GUID}-parks-dev/nationalparks --name=nationalparks-blue --allow-missing-imagestream-tags=true -l type=parksmap-backend-inactive -n ${GUID}-parks-prod
oc set triggers dc/nationalparks-blue --remove-all -n ${GUID}-parks-prod
oc set env --from=configmap/nationalparks-blue-config dc/nationalparks-blue
# Probes for blue deployment
oc set probe dc/nationalparks-blue --readiness --get-url=http://:8080/ws/healthz/ --failure-threshold=3 --initial-delay-seconds=30
oc set probe dc/nationalparks-blue --liveness --failure-threshold 3 --initial-delay-seconds 30 -- echo ok

#----- Commands for parksmap app -----#
oc new-app ${GUID}-parks-dev/parksmap --name=parksmap-green --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc set triggers dc/parksmap-green --remove-all -n ${GUID}-parks-prod
oc expose svc/parksmap-green --name=parksmap
oc set probe dc/parksmap-green --readiness --get-url=http://:8080/ws/healthz/ --failure-threshold=3 --initial-delay-seconds=15
oc set probe dc/parksmap-green --liveness --failure-threshold 3 --initial-delay-seconds 30 -- echo ok
oc new-app ${GUID}-parks-dev/parksmap --name=parksmap-blue --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc set triggers dc/parksmap-blue --remove-all -n ${GUID}-parks-prod
# Probes
oc set probe dc/parksmap-blue --readiness --get-url=http://:8080/ws/healthz/ --failure-threshold=3 --initial-delay-seconds=15
oc set probe dc/parksmap-blue --liveness --failure-threshold 3 --initial-delay-seconds 30 -- echo ok

## NOTE: On first time setup, I also loaded the databases for the mlbparks and nationalparks applications manually by calling their “/ws/load/data” endpoints manually. This only has to be done once.