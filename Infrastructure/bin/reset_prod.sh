#!/bin/bash
# Reset Production Project (initial active services: Blue)
# This sets all services to the Blue service so that any pipeline run will deploy Green
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Resetting Parks Production Environment in project ${GUID}-parks-prod to Green Services"

# Code to reset the parks production environment to make
# all the green services/routes active.
# This script will be called in the grading pipeline
# if the pipeline is executed without setting
# up the whole infrastructure to guarantee a Blue
# rollout followed by a Green rollout.

# Set route to Green Service
# MLBParks
oc patch route mlbparks -n ${GUID}-parks-prod -p '{"spec":{"to":{"name":"mlbparks-green"}}}'
# Nationalparks
oc patch route nationalparks -n ${GUID}-parks-prod -p '{"spec":{"to":{"name":"nationalparks-green"}}}'
# Parksmap
oc patch route parksmap -n ${GUID}-parks-prod -p '{"spec":{"to":{"name":"parksmap-green"}}}'

# Add echo statement so that the script succeeds even if the patch didn't do anything
echo "Updated"