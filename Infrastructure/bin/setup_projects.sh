#!/bin/bash
# Create all Homework Projects
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID USER"
	echo "example: setup_projects.sh ra ragrahari"
	sleep 3
    exit 1
fi

GUID=$1
USER=$2
FROM_JENKINS=$3

echo "Creating all Homework Projects for GUID=${GUID} and USER=${USER}"
oc new-project ${GUID}-nexus        --display-name="${GUID} AdvDev Homework Nexus"
oc new-project ${GUID}-sonarqube    --display-name="${GUID} AdvDev Homework Sonarqube"
oc new-project ${GUID}-jenkins    --display-name="${GUID} AdvDev Homework Jenkins"
oc new-project ${GUID}-parks-dev  --display-name="${GUID} AdvDev Homework Parks Development"
oc new-project ${GUID}-parks-prod --display-name="${GUID} AdvDev Homework Parks Production"

if [ "$FROM_JENKINS" = "true" ]; then
    echo "Updating policy to add role to user"
    oc policy add-role-to-user admin ${USER} -n ${GUID}-nexus
    oc policy add-role-to-user admin ${USER} -n ${GUID}-sonarqube
    oc policy add-role-to-user admin ${USER} -n ${GUID}-jenkins
    oc policy add-role-to-user admin ${USER} -n ${GUID}-parks-dev
    oc policy add-role-to-user admin ${USER} -n ${GUID}-parks-prod

    #echo "annotating namespaces"
    oc annotate namespace ${GUID}-nexus      openshift.io/requester=${USER} --overwrite
    oc annotate namespace ${GUID}-sonarqube  openshift.io/requester=${USER} --overwrite
    oc annotate namespace ${GUID}-jenkins    openshift.io/requester=${USER} --overwrite
    oc annotate namespace ${GUID}-parks-dev  openshift.io/requester=${USER} --overwrite
    oc annotate namespace ${GUID}-parks-prod openshift.io/requester=${USER} --overwrite
fi
