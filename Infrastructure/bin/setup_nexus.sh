#!/bin/bash
# Setup Nexus Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
	echo "example: setup_nexus.sh ra"
	sleep 5
    exit 1
fi

GUID=$1
echo "Setting up Nexus in project $GUID-nexus"

# Code to set up the Nexus. It will need to
# * Create Nexus
# * Set the right options for the Nexus Deployment Config
# * Load Nexus with the right repos
# * Configure Nexus as a docker registry
# Hint: Make sure to wait until Nexus if fully up and running
#       before configuring nexus with repositories.
#       You could use the following code:
# while : ; do
#   echo "Checking if Nexus is Ready..."
#   oc get pod -n ${GUID}-nexus|grep '\-2\-'|grep -v deploy|grep "1/1"
#   [[ "$?" == "1" ]] || break
#   echo "...no. Sleeping 10 seconds."
#   sleep 10
# done

# Ideally just calls a template
# oc new-app -f ../templates/nexus.yaml --param .....

# Use ${GUID}-nexus project
oc project ${GUID}-nexus
# Create the service using nexus3 image and expose the service
##oc new-app sonatype/nexus3:latest
echo "building new app using docker image"
oc new-app docker.io/sonatype/nexus3:latest -n ${GUID}-nexus
oc expose svc nexus3 -n ${GUID}-nexus
oc rollout pause deploymentconfig nexus3 -n ${GUID}-nexus
# Setup "Recreate" deployment strategy and configure resource limits
echo "configuring Nexus"
oc patch deploymentconfig/nexus3 --patch='{"spec":{"strategy":{"type":"Recreate"}}}' -n ${GUID}-nexus
oc set resources deploymentconfig/nexus3 --limits=memory=2Gi --requests=memory=1Gi -n ${GUID}-nexus
# Use yaml file to create persistent volume and mount it at /nexus-data
oc create -f ./Infrastructure/templates/pvc-nexus.yaml -n ${GUID}-nexus
oc set volume deploymentconfig/nexus3 -n ${GUID}-nexus
oc set volume deploymentconfig/nexus3 --add --overwrite --name=nexus3-volume-1 --mount-path=/nexus-data/ --type persistentVolumeClaim --claim-name=nexus-pvc -n ${GUID}-nexus
# Set liveness and readiness probe
oc set probe deploymentconfig/nexus3 --liveness --failure-threshold 3 --initial-delay-seconds 60 -- echo ok --period-seconds 10 --success-threshold 1 --timeout-seconds 1 -n ${GUID}-nexus
oc set probe deploymentconfig/nexus3 --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url= http://:8081/repository/maven-public/ --period-seconds 10 --success-threshold 1 --timeout-seconds 1 -n ${GUID}-nexus
# Expose the container registry
echo "exposing Nexus container"
oc expose deploymentconfig nexus3 --port=5000 --name=nexus-registry -n ${GUID}-nexus
oc create route edge nexus-registry --service=nexus-registry --port=5000 -n ${GUID}-nexus
oc rollout resume deploymentconfig nexus3 -n ${GUID}-nexus

# Wait for Nexus to be ready for repo setup

while : ; do
	echo "Checking if Nexus is Ready..."
    oc get pod -n ${GUID}-nexus | grep '\-1\-' | grep -v deploy | grep "1/1"
    if [ $? == "1" ] 
      then 
      echo "Sleeping 10 seconds."
        sleep 10
      else 
        break 
    fi
done

oc get routes -n $GUID-nexus
sleep 60

## Once Nexus is deployed, following script can be used to setup the Nexus repository
curl -o setup_nexus3.sh -s https://raw.githubusercontent.com/wkulhanek/ocp_advanced_development_resources/master/nexus/setup_nexus3.sh
chmod +x setup_nexus3.sh
./setup_nexus3.sh admin admin123 http://$(oc get route nexus3 --template='{{ .spec.host }}' -n ${GUID}-nexus)
rm setup_nexus3.sh
oc get routes -n $GUID-nexus