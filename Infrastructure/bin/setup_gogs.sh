#!/bin/bash
# Setup Gogs Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
	echo "example: setup_gogs.sh ra"
	sleep 3
    exit 1
fi

GUID=$1
echo "Setting up Gogs in project $GUID-gogs"

# Code to set up the Gogs project.

oc new-project ${GUID}-gogs --display-name "${GUID} Gogs"
# Build the application
oc new-app postgresql-persistent --param POSTGRESQL_DATABASE=gogs --param POSTGRESQL_USER=gogs --param POSTGRESQL_PASSWORD=gogs --param VOLUME_CAPACITY=4Gi -lapp=postgresql_gogs
oc new-app wkulhanek/gogs:11.34 -lapp=gogs
# Create and mount pvc
oc create -f ../templates/gogs_pvc.yaml
oc set volume dc/gogs --add --overwrite --name=gogs-volume-1 --mount-path=/data/ --type persistentVolumeClaim --claim-name=gogs-data
oc expose svc gogs
# to get contents of app.ini, and then copied to local machine
#oc rsh <gogs-pod> cat /opt/gogs/custom/conf/app.ini
#oc create configmap gogs --from-file=<app.ini file>

oc set volume dc/gogs --add --overwrite --name=config-volume -m /opt/gogs/custom/conf/ -t configmap --configmap-name=gogs
# into a location on local machine
git clone https://github.com/wkulhanek/ParksMap.git
git remote add private-hw http://raj:rajman@$(oc get route gogs -n ${GUID}-gogs --template='{{ .spec.host}}'/CICD_HW/ParksMap.git
git push -u private-hw master
