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

sleep 300

oc project ${GUID}-parks-prod
# Grant the correct permissions to pull images from the development project
oc policy add-role-to-group system:image-puller system:serviceaccounts:${GUID}-parks-prod -n ${GUID}-parks-dev
# Grant the correct permissions to the Jenkins service account
oc policy add-role-to-user edit system:serviceaccount:${GUID}-jenkins:jenkins -n ${GUID}-parks-prod
oc policy add-role-to-user admin system:serviceaccount:ra-gpte-jenkins:jenkins -n ${GUID}-parks-prod
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

#----- Commands for MLBParks app -----#
# Green
oc create configmap mlbparks-green-config \
 --from-literal=DB_HOST=mongodb \
 --from-literal=DB_PORT=27017 \
 --from-literal=DB_USERNAME=mongodb \
 --from-literal=DB_PASSWORD=mongodb \
 --from-literal=DB_NAME=parks \
 --from-literal=DB_REPLICASET=rs0 \
 --from-literal=APPNAME="MLB Parks (Green)" \
 -n ${GUID}-parks-prod
# Blue
oc create configmap mlbparks-blue-config \
 --from-literal=DB_HOST=mongodb \
 --from-literal=DB_PORT=27017 \
 --from-literal=DB_USERNAME=mongodb \
 --from-literal=DB_PASSWORD=mongodb \
 --from-literal=DB_NAME=parks \
 --from-literal=DB_REPLICASET=rs0 \
 --from-literal=APPNAME="MLB Parks (Blue)" \
 -n ${GUID}-parks-prod
# Green deployment : APPNAME="MLB Parks (Green)"
oc new-app ${GUID}-parks-dev/mlbparks --name=mlbparks-green --allow-missing-imagestream-tags=true -l type=parksmap-backend -n ${GUID}-parks-prod
oc set triggers dc/mlbparks-green --remove-all -n ${GUID}-parks-prod
oc set env --from=configmap/mlbparks-green-config dc/mlbparks-green -n ${GUID}-parks-prod
oc expose dc/mlbparks-green --port 8080 -n ${GUID}-parks-prod
oc expose svc/mlbparks-green --name=mlbparks -n ${GUID}-parks-prod
# Probes for green deployment
oc set probe dc/mlbparks-green --readiness --get-url=http://:8080/ws/healthz/ --failure-threshold=3 --initial-delay-seconds=15 -n ${GUID}-parks-prod
oc set probe dc/mlbparks-green --liveness --failure-threshold 3 --initial-delay-seconds 30 -- echo ok -n ${GUID}-parks-prod
# Blue Deployment : APPNAME="MLB Parks (Blue)"
oc new-app ${GUID}-parks-dev/mlbparks --name=mlbparks-blue --allow-missing-imagestream-tags=true -l type=parksmap-backend-inactive -n ${GUID}-parks-prod
oc set resources dc/mlbparks-blue --limits=memory=512Mi,cpu=250m -n ${GUID}-parks-prod
oc set triggers dc/mlbparks-blue --remove-all -n ${GUID}-parks-prod
oc set env --from=configmap/mlbparks-blue-config dc/mlbparks-blue -n ${GUID}-parks-prod
# Probes for blue deployment
oc set probe dc/mlbparks-blue --readiness --get-url=http://:8080/ws/healthz/ --failure-threshold=3 --initial-delay-seconds=15 -n ${GUID}-parks-prod
oc set probe dc/mlbparks-blue --liveness --failure-threshold 3 --initial-delay-seconds 30 -- echo ok -n ${GUID}-parks-prod

#----- Commands for nationalparks app -----#
# Green
oc create configmap nationalparks-green-config \
 --from-literal=DB_HOST=mongodb \
 --from-literal=DB_PORT=27017 \
 --from-literal=DB_USERNAME=mongodb \
 --from-literal=DB_PASSWORD=mongodb \
 --from-literal=DB_NAME=parks \
 --from-literal=DB_REPLICASET=rs0 \
 --from-literal=APPNAME="National Parks (Green)" \
 -n ${GUID}-parks-prod
# Blue
oc create configmap nationalparks-blue-config \
 --from-literal=DB_HOST=mongodb \
 --from-literal=DB_PORT=27017 \
 --from-literal=DB_USERNAME=mongodb \
 --from-literal=DB_PASSWORD=mongodb \
 --from-literal=DB_NAME=parks \
 --from-literal=DB_REPLICASET=rs0 \
 --from-literal=APPNAME="National Parks (Blue)" \
 -n ${GUID}-parks-prod
# Green Deployment
oc new-app ${GUID}-parks-dev/nationalparks --name=nationalparks-green --allow-missing-imagestream-tags=true -l type=parksmap-backend -n ${GUID}-parks-prod
oc set triggers dc/nationalparks-green --remove-all -n ${GUID}-parks-prod
oc set env --from=configmap/nationalparks-green-config dc/nationalparks-green -n ${GUID}-parks-prod
oc expose dc/nationalparks-green --port=8080 -n ${GUID}-parks-prod
oc expose svc/nationalparks-green --name=nationalparks -n ${GUID}-parks-prod
# Probes for green deployment
oc set probe dc/nationalparks-green --readiness --get-url=http://:8080/ws/healthz/ --failure-threshold=3 --initial-delay-seconds=30 -n ${GUID}-parks-prod
oc set probe dc/nationalparks-green --liveness --failure-threshold 3 --initial-delay-seconds 30 -- echo ok -n ${GUID}-parks-prod
# Blue Deployment
oc new-app ${GUID}-parks-dev/nationalparks --name=nationalparks-blue --allow-missing-imagestream-tags=true -l type=parksmap-backend-inactive -n ${GUID}-parks-prod
oc set triggers dc/nationalparks-blue --remove-all -n ${GUID}-parks-prod
oc set env --from=configmap/nationalparks-blue-config dc/nationalparks-blue -n ${GUID}-parks-prod
# Probes for blue deployment
oc set probe dc/nationalparks-blue --readiness --get-url=http://:8080/ws/healthz/ --failure-threshold=3 --initial-delay-seconds=30 -n ${GUID}-parks-prod
oc set probe dc/nationalparks-blue --liveness --failure-threshold 3 --initial-delay-seconds 30 -- echo ok -n ${GUID}-parks-prod

#----- Commands for parksmap app -----#
# Green
oc new-app ${GUID}-parks-dev/parksmap --name=parksmap-green --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc set triggers dc/parksmap-green --remove-all -n ${GUID}-parks-prod
oc expose dc/parksmap-green --port=8080 -n ${GUID}-parks-prod
oc expose svc/parksmap-green --name=parksmap -n ${GUID}-parks-prod
# Probes
oc set probe dc/parksmap-green --readiness --get-url=http://:8080/ws/healthz/ --failure-threshold=3 --initial-delay-seconds=15 -n ${GUID}-parks-prod
oc set probe dc/parksmap-green --liveness --failure-threshold 3 --initial-delay-seconds 30 -- echo ok -n ${GUID}-parks-prod
# Blue
oc new-app ${GUID}-parks-dev/parksmap --name=parksmap-blue --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc set triggers dc/parksmap-blue --remove-all -n ${GUID}-parks-prod
# Probes
oc set probe dc/parksmap-blue --readiness --get-url=http://:8080/ws/healthz/ --failure-threshold=3 --initial-delay-seconds=15 -n ${GUID}-parks-prod
oc set probe dc/parksmap-blue --liveness --failure-threshold 3 --initial-delay-seconds 30 -- echo ok -n ${GUID}-parks-prod
