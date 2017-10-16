#!/bin/bash
#--context-dir="2/test/s2i"
SCRIPT_DIR=$(dirname ${0})
JENKINS_S2I_ROOT=${SCRIPT_DIR}/jenkins-s2i

function clear() {
  oc login --username ${USERNAME} --password ${PASSWORD}
  oc delete project ${PROJECT_ID}
  oc logout
}

function create_nexus() {
  oc new-app sonatype/nexus:3.6.0
  oc expose svc/nexus
  oc get routes

  oc set probe dc/nexus \
    --liveness \
    --failure-threshold 3 \
    --initial-delay-seconds 30 \
    -- echo ok
  oc set probe dc/nexus \
    --readiness \
    --failure-threshold 3 \
    --initial-delay-seconds 30 \
    --get-url=http://:8081/nexus/content/groups/public
  oc volumes dc/nexus --add \
    --name 'nexus-volume' \
    --type 'pvc' \
    --mount-path '/sonatype-work/' \
    --claim-name 'nexus-pv' \
    --claim-size '10G' \
    --overwrite
}

function create_pipeline_git() {
  oc login --username ${USERNAME} --password ${PASSWORD}
  oc new-project ${PROJECT_ID}
  #oc create -f ${SCRIPT_DIR}/templates/pvc.yaml
  #oc new-app -f ${SCRIPT_DIR}/templates/hogarama-jenkins.yml \
  #  -p "JENKINS_SERVICE_HOST=hogarama-jenkins" \
  #  -p "JNLP_SERVICE_NAME=hogarama-jenkins-jnlp"

  oc new-app -f ${SCRIPT_DIR}/templates/hogarama-nexus.yml \
    -p "SERVICE_NAME=hogarama-nexus"
  oc new-app -f ${SCRIPT_DIR}/templates/hogarama-jenkins-pipeline-git.yml \
    -p "APP_NAME=hogajama" \
    -p "GIT_REPO=https://github.com/Gepardec/Hogarama.git" \
    -p "GIT_REF=OPENSHIFT_JENKINS_PIPELINE" \
    -p "JENKINS_FILE_PATH=Hogajama/Jenkinsfile" \
    -p "MAVEN_MIRROR_URL=http://hogarama-nexus:8081/nexus/content/groups/public"
  oc new-app -f ${SCRIPT_DIR}/templates/hogarama-jenkins-pipeline-git.yml \
    -p "APP_NAME=mqtt-java-lcient" \
    -p "GIT_REPO=https://github.com/Gepardec/Hogarama.git" \
    -p "GIT_REF=OPENSHIFT_JENKINS_PIPELINE" \
    -p "JENKINS_FILE_PATH=mqtt-client-java/mqtt-client/Jenkinsfile" \
    -p "MAVEN_MIRROR_URL=http://hogarama-nexus:8081/nexus/content/groups/public"

  oc logout
}

function restore() {
  clear && create
}

USERNAME=${2:-"developer"}
PASSWORD=${3:-"developer"}
PROJECT_ID=${4:-"hogarama-buildserver"}

${1}
