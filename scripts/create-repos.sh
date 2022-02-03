#!/usr/bin/env bash

set -eo pipefail

USE_GITEA=${USE_GITEA:-false}

if [[ "${USE_GITEA}" == "true" ]]; then
  exec $(dirname "${BASH_SOURCE}")/bootstrap-gitea.sh
fi

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
[[ -n "${DEBUG:-}" ]] && set -x

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

command -v gh >/dev/null 2>&1 || { echo >&2 "The Github CLI gh but it's not installed. Download https://github.com/cli/cli "; exit 1; }

set +e
oc version --client | grep '4.7\|4.8'
OC_VERSION_CHECK=$?
set -e
if [[ ${OC_VERSION_CHECK} -ne 0 ]]; then
  echo "Please use oc client version 4.7 or 4.8 download from https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/ "
fi


if [[ -z ${GIT_ORG} ]]; then
  echo "We recommend to create a new github organization for all your gitops repos"
  echo "Setup a new organization on github https://docs.github.com/en/organizations/collaborating-with-groups-in-organizations/creating-a-new-organization-from-scratch"
  echo "Please set the environment variable GIT_ORG when running the script like:"
  echo "GIT_ORG=acme-org OUTPUT_DIR=gitops-production ./scripts/bootstrap.sh"

  exit 1
fi

if [[ -z ${OUTPUT_DIR} ]]; then
  echo "Please set the environment variable OUTPUT_DIR when running the script like:"
  echo "GIT_ORG=acme-org OUTPUT_DIR=gitops-production ./scripts/bootstrap.sh"

  exit 1
else
  echo "Creating GitHub repositories and local clones in folder:" ${OUTPUT_DIR}
fi
mkdir -p "${OUTPUT_DIR}"



CP_EXAMPLES=${CP_EXAMPLES:-true}
ACE_SCENARIO=${ACE_SCENARIO:-false}
ACE_BOM_PATH=${ACE_BOM_PATH:-scripts/bom/ace}
CP_DEFAULT_TARGET_NAMESPACE=${CP_DEFAULT_TARGET_NAMESPACE:-tools}

GITOPS_PROFILE=${GITOPS_PROFILE:-0-bootstrap/single-cluster}

GIT_BRANCH=${GIT_BRANCH:-master}
GIT_PROTOCOL=${GIT_PROTOCOL:-https}
GIT_HOST=${GIT_HOST:-github.com}
GIT_BASEURL=${GIT_BASEURL:-${GIT_PROTOCOL}://${GIT_HOST}}
GIT_GITOPS=${GIT_GITOPS:-multi-tenancy-gitops.git}
GIT_GITOPS_NAME=multi-tenancy-gitops
GIT_GITOPS_BRANCH=${GIT_GITOPS_BRANCH:-${GIT_BRANCH}}
GIT_GITOPS_INFRA=${GIT_GITOPS_INFRA:-multi-tenancy-gitops-infra.git}
GIT_GITOPS_INFRA_BRANCH=${GIT_GITOPS_INFRA_BRANCH:-${GIT_BRANCH}}
GIT_GITOPS_INFRA_NAME=multi-tenancy-gitops-infra
GIT_GITOPS_SERVICES=${GIT_GITOPS_SERVICES:-multi-tenancy-gitops-services.git}
GIT_GITOPS_SERVICES_BRANCH=${GIT_GITOPS_SERVICES_BRANCH:-${GIT_BRANCH}}
GIT_GITOPS_SERVICES_NAME=multi-tenancy-gitops-services
GIT_GITOPS_APPLICATIONS=${GIT_GITOPS_APPLICATIONS:-multi-tenancy-gitops-apps.git}
GIT_GITOPS_APPLICATIONS_BRANCH=${GIT_GITOPS_APPLICATIONS_BRANCH:-${GIT_BRANCH}}
GIT_GITOPS_APPLICATIONS_NAME=multi-tenancy-gitops-apps
GIT_GITOPS_ACE_SCENARIO_NAME=ace-customer-details

create_repos () {
    echo "Github user/org is ${GIT_ORG}"

    pushd ${OUTPUT_DIR}

    GHREPONAME=$(gh api /repos/${GIT_ORG}/multi-tenancy-gitops -q .name || true)
    if [[ ! ${GHREPONAME} = "multi-tenancy-gitops" ]]; then
      echo "Repository ${GIT_GITOPS_NAME} not found, creating from template and cloning"
      gh repo create ${GIT_ORG}/multi-tenancy-gitops --public --template https://github.com/cloud-native-toolkit/multi-tenancy-gitops --clone
      mv multi-tenancy-gitops gitops-0-bootstrap
    elif [[ ! -d gitops-0-bootstrap ]]; then
      echo "Repository ${GIT_GITOPS_NAME} found but not cloned... cloning repository"
      gh repo clone ${GIT_ORG}/multi-tenancy-gitops gitops-0-bootstrap
    else
      echo "Repository ${GIT_GITOPS_NAME} exists and already cloned... nothing to do"
    fi
    cd gitops-0-bootstrap
    git checkout ${GIT_GITOPS_BRANCH} || git checkout --track origin/${GIT_GITOPS_BRANCH}
    cd ..

    GHREPONAME=$(gh api /repos/${GIT_ORG}/multi-tenancy-gitops-infra -q .name || true)
    if [[ ! ${GHREPONAME} = "multi-tenancy-gitops-infra" ]]; then
      echo "Repository not found for ${GIT_GITOPS_INFRA_NAME}; creating from template and cloning"
      gh repo create ${GIT_ORG}/multi-tenancy-gitops-infra --public --template https://github.com/cloud-native-toolkit/multi-tenancy-gitops-infra --clone
      mv multi-tenancy-gitops-infra gitops-1-infra
    elif [[ ! -d gitops-1-infra ]]; then
      echo "Repository ${GIT_GITOPS_INFRA_NAME} found but not cloned... cloning repository"
      gh repo clone ${GIT_ORG}/multi-tenancy-gitops-infra gitops-1-infra
    else
      echo "Repository ${GIT_GITOPS_INFRA_NAME} exists and already cloned... nothing to do"
    fi
    cd gitops-1-infra
    git checkout ${GIT_GITOPS_INFRA_BRANCH} || git checkout --track origin/${GIT_GITOPS_INFRA_BRANCH}
    cd ..

    GHREPONAME=$(gh api /repos/${GIT_ORG}/multi-tenancy-gitops-services -q .name || true)
    if [[ ! ${GHREPONAME} = "multi-tenancy-gitops-services" ]]; then
      echo "Repository ${GIT_GITOPS_SERVICES_NAME} not found, creating from template and cloning"
      gh repo create ${GIT_ORG}/multi-tenancy-gitops-services --public --template https://github.com/cloud-native-toolkit/multi-tenancy-gitops-services --clone
      mv multi-tenancy-gitops-services gitops-2-services
    elif [[ ! -d gitops-2-services ]]; then
      echo "Repository ${GIT_GITOPS_SERVICES_NAME} found but not cloned... cloning repository"
      gh repo clone ${GIT_ORG}/multi-tenancy-gitops-services gitops-2-services
    else
      echo "Repository ${GIT_GITOPS_SERVICES_NAME} exists and already cloned... nothing to do"
    fi
    cd gitops-2-services
    git checkout ${GIT_GITOPS_SERVICES_BRANCH} || git checkout --track origin/${GIT_GITOPS_SERVICES_BRANCH}
    cd ..

    if [[ "${CP_EXAMPLES}" == "true" ]]; then
      echo "Creating repos for Cloud Pak examples"

      GHREPONAME=$(gh api /repos/${GIT_ORG}/multi-tenancy-gitops-apps -q .name || true)
      if [[ ! ${GHREPONAME} = "multi-tenancy-gitops-apps" ]]; then
        echo "Repository ${GIT_GITOPS_APPLICATIONS_NAME} not found, creating from template and cloning"
        gh repo create ${GIT_ORG}/multi-tenancy-gitops-apps --public --template https://github.com/cloud-native-toolkit-demos/multi-tenancy-gitops-apps --clone
        mv multi-tenancy-gitops-apps gitops-3-apps
      elif [[ ! -d gitops-3-apps ]]; then
        echo "Repository ${GIT_GITOPS_APPLICATIONS_NAME} found but not cloned... cloning repository"
        gh repo clone ${GIT_ORG}/multi-tenancy-gitops-apps gitops-3-apps
      else
        echo "Repository ${GIT_GITOPS_APPLICATIONS_NAME} exists and already cloned... nothing to do"
      fi
      cd gitops-3-apps
      git checkout ${GIT_GITOPS_APPLICATIONS_BRANCH} || git checkout --track origin/${GIT_GITOPS_APPLICATIONS_BRANCH}
      cd ..

      if [[ "${ACE_SCENARIO}" == "true" ]]; then
        GHREPONAME=$(gh api /repos/${GIT_ORG}/ace-customer-details -q .name || true)
        if [[ ! ${GHREPONAME} = "ace-customer-details" ]]; then
          echo "Repository not found for ${GIT_GITOPS_ACE_SCENARIO_NAME}; creating from template and cloning"
          gh repo create ${GIT_ORG}/ace-customer-details --public --template https://github.com/cloud-native-toolkit-demos/ace-customer-details --clone
          mv ace-customer-details src-ace-app-customer-details
        elif [[ ! -d src-ace-app-customer-details ]]; then
          echo "Repository ${GIT_GITOPS_ACE_SCENARIO_NAME} found but not cloned... cloning repository"
          gh repo clone ${GIT_ORG}/ace-customer-details src-ace-app-customer-details
        else
          echo "Repository ${GIT_GITOPS_ACE_SCENARIO_NAME} exists and already cloned... nothing to do"
        fi
        cd src-ace-app-customer-details
        git checkout master || git checkout --track origin/master
        cd ..
      fi

    fi

    popd

}

# main

create_repos

exit 0