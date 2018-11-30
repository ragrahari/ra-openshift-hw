#!/bin/bash
# Setup Sonarqube Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
	echo "example: setup_sonar.sh ra"
	sleep 3
    exit 1
fi

GUID=$1
echo "Setting up Sonarqube in project $GUID-sonarqube"

# Code to set up the SonarQube project.
# Ideally just calls a template
# oc new-app -f ../templates/sonarqube.yaml --param .....
sleep 60
oc project ${GUID}-sonarqube
echo "Deploying persistent postgre database"
oc new-app --template=postgresql-persistent --param POSTGRESQL_USER=sonar --param POSTGRESQL_PASSWORD=sonar --param POSTGRESQL_DATABASE=sonar --param VOLUME_CAPACITY=4Gi --labels=app=sonarqube_db -n ${GUID}-sonarqube
echo "Deploying SonarQube image"
oc new-app --docker-image=wkulhanek/sonarqube:6.7.4 --env=SONARQUBE_JDBC_USERNAME=sonar --env=SONARQUBE_JDBC_PASSWORD=sonar --env=SONARQUBE_JDBC_URL=jdbc:postgresql://postgresql/sonar --labels=app=sonarqube -n ${GUID}-sonarqube
# Pause rollout and exponse sonarqube service
oc rollout pause dc sonarqube -n ${GUID}-sonarqube
oc expose service sonarqube -n ${GUID}-sonarqube
# Create and configure persistent volumen for sonarqube
echo "Creating and mounting PVC"
oc create -f ./Infrastructure/templates/pvc-sonar.yaml -n ${GUID}-sonarqube
oc set volume dc/sonarqube --add --overwrite --name=sonarqube-volume-1 --mount-path=/opt/sonarqube/data/ --type persistentVolumeClaim --claim-name=sonarqube-pvc -n ${GUID}-sonarqube
oc set resources dc/sonarqube --limits=memory=2Gi,cpu=2 --requests=memory=1Gi,cpu=1 -n ${GUID}-sonarqube
oc patch dc sonarqube --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${GUID}-sonarqube
# Set liveness and readiness probe
oc set probe dc/sonarqube --liveness --failure-threshold 3 --initial-delay-seconds 40 -- echo ok --period-seconds 10 --success-threshold 1 --timeout-seconds 1 -n ${GUID}-sonarqube
oc set probe dc/sonarqube --readiness --failure-threshold 3 --initial-delay-seconds 20 --get-url= http://:9000/about --period-seconds 10 --success-threshold 1 --timeout-seconds 1 -n ${GUID}-sonarqube
# Expose the service
oc rollout resume dc sonarqube -n ${GUID}-sonarqube
