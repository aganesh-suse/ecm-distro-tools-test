LOG="debug"  # Can be debug or info. More logging for debug mode. 

OS_NAME="rhel"  # can be ubuntu or sles or rhel or slemicro or rocky or OL. (no versions)
PRDT="rke2"
VERSION_UNDER_TEST="128_4"
TEST_RUN="${RANDOM}"  # Not yet used. Planning to update/store configs in a new directory for every test run dynamic directory created.
echo "Test Run Value: ${TEST_RUN}"
# ENV VARS: (Please set these as environment variables including PREFIX value - which is the tag name for resources in aws)
PEM="${PEM_FILE_PATH}"
S3_ACCESS_KEY="${AWS_ACCESS_KEY_ID}"
S3_SECRET_KEY="${AWS_SECRET_ACCESS_KEY}"
REPO_PATH="${HOME}/repos/${PRDT}"  # Pre git cloned PRDT: k3s or rke2 in this path


# RHEL
# HA SETUP
SERVER3="1.1.1.1"
SERVER2="2.2.2.2"
SERVER1="3.3.3.3"
AGENT1="4.4.4.4"

# SPLIT INSTALL SETUP:
# SERVER1=""
# AGENT1=""
# SERVER2=""
# AGENT2=""

# In the case where primary/secondary setup is a commit id for comparison, provide RELEASE_BRANCH/COMMIT and RELEASE_BRANCH2/COMMIT2 var value here: 
# RELEASE_BRANCH="master"
# RELEASE_BRANCH2="release-1.27"
# RELEASE_BRANCH="release-1.26"
# RELEASE_BRANCH="release-1.25"
# RELEASE_BRANCH2="release-1.27"
# COMMIT="9e69b862192abc4c50fba50535c433b38f91463b"
# RELEASE_BRANCH2="release-1.24"  # Use to get COMMIT ID  master | release-1.26 | release-1.25 | release-1.24
# RELEASE_BRANCH2="master" 
# COMMIT2=""
if [ "${RELEASE_BRANCH}" ] || [ "${COMMIT}" ]; then
    # PRIVATE_IP="172.31.18.193"
    CLUSTER_NAME="commit-setup-${VERSION_UNDER_TEST}"
else
    CLUSTER_NAME="version-setup-${VERSION_UNDER_TEST}"
fi

# Previous versions (Pre-Upgrade/Install Versions)
VERSION="v1.28.3+rke2r1" 
# VERSION="v1.27.7+rke2r1"  
# VERSION="v1.26.10+rke2r1"
# VERSION="v1.25.15+rke2r1"

# INSTALL tests for RC Builds
# VERSION="v1.28.4-rc1+rke2r1"
# VERSION="v1.27.8-rc1+rke2r1"  
# VERSION="v1.26.11-rc1+rke2r1"
# VERSION="v1.25.16-rc1+rke2r1"

# UPGRADES for RC Builds / SPLIT INSTALL SECOND VERSIONS: 
# VERSION2="v1.28.4-rc1+rke2r1"
# VERSION2="v1.27.8-rc1+rke2r1"
# VERSION2="v1.26.11-rc1+rke2r1"
# VERSION2="v1.25.16-rc1+rke2r1"

# SUC VERSION Upgrades
# VERSION2="v1.28.4-rc1-rke2r1" # SUC Version
# VERSION2="v1.27.8-rc1-rke2r1"
# VERSION2="v1.26.11-rc1-rke2r1"
# VERSION2="v1.25.16-rc1-rke2r1"


# Test options
MANUAL_UPGRADE=false
NODE_REPLACEMENT=false
SECRETS_ENCRYPT_TEST=false  # Use rhel9.2 setup. (Ubuntu doesnt allow sudo commands without providing password)
CERT_ROTATE=false
SUC_UPGRADE=false
CLUSTER_RESET=false
# CLUSTER_RESET_RESTORE_PATH_TEST=false  # ETCD SNAPSHOT TEST # with uninstall server1

CLUSTER_RESET_WITH_RESTORE=false  # does not uninstall server1. runs test with killall/delete db of servers 2 and 3 like regular cluster restore test. except we use restore from snapshot in this case. 
RESTORE_FROM_S3_OR_LOCAL="s3"  # Can be s3 | local

ETCD_SNAPSHOT_RETENTION=false  # Includes Update Node names of server/agent 2 times

ETCD_SNAPSHOT_TEST=false
ETCD_SNAPSHOT_RETENTION_VALUE=5
ON_DEMAND_SNAPSHOT_COUNT=5
PRUNE_RETENTION_VALUE=3


INSTALL_RANCHER_MANAGER=false
RANCHER_VERSION="v2.7.8"

CUSTOM_TEST=false

CUSTOM_SELINUX_TEST=true

# installer options
REINSTALL=true
SSH_KEYSCAN=false
CHANNEL="latest"  # For rhel and slemicro, this can be only testing. They will be reset later.
PREP_SLEMICRO=false
PREP_FAPOLICYD=false  # To be used with rhel. (we run yum install) 
APPLY_WORKLOAD=true
# TAKE_SNAPSHOT=false
CIS=false
ETCD=false  # split roles in servers - true or false. If true - server1 etcd, server2 control plane, server3 both.
SECRETS_ENCRYPT=false  # this generally goes together with the etcd value
TLS_SAN=false
NODE_EXTERNAL_IP=true
NODE_NAME=false
POD_SECURITY=false
CNI=true
CNI_TYPE="calico"  # can be canal or cilium or calico or "multus,calico" or "multus,canal"
AUDIT=false
PROTECT_KERNEL=false  # Can this be true without cis hardening? not sure.
PROTECT_KERNEL_SET_CONFIG=false  # When CIS is true, it should automatically take this param as true in config - without us setting. 
# So unless, we intentionally need this in the config.yaml for a test, we are not setting the same. Leave it to false. Else switch to true. 

CUSTOM_WORKLOAD=false  # Update the workload content for the custom_workload.yaml file. OR
# Update the CUSTOM_WORKLOAD_YAML and CUSTOM_WORKLOAD_DESTINATION_FILE_PATH vars below, to the workload yaml filename to apply post install
CUSTOM_MANIFEST=false  # Update the custom_manifest.yaml to have the content we will push into /var/lib/rancher/rke2/server/manifests/ directory
CUSTOM_INSTALL_CMD=false
CUSTOM_INSTALL_STRING="INSTALL_RKE2_SKIP_FAPOLICY=true"

# INSTALL METHOD VARIABLE CHANGE: 
if [ "${OS_NAME}" = "rhel" ] || [ "${OS_NAME}" = "slemicro" ]; then
    INSTALL_METHOD=rpm  # rpm or tar or yum
else
    INSTALL_METHOD=tar  # rpm or tar or yum
fi
# INSTALL_METHOD=rpm  # Overwrite value - For cases when we want to use tar for rhel or yum
if [ "${LOG}" = "debug" ]; then
    echo "SET: INSTALL_METHOD=${INSTALL_METHOD}"
fi

# USER variable update
if [ -z "${SSH_USER}" ]; then
    case "${OS_NAME}" in
        *"ubuntu"*) USER="ubuntu";;
        *"rocky"*) USER="rocky";;
        *"slemicro"*) USER="suse";;        
        *"OL"*) 
        # Tiov IT AMIs and Packer AMIs generated from them use 'cloud-user'
        # ProComputer AMIs user 'ec2-user' as the ssh username (explicitly set with image id - ex: OL8.8)
            USER="cloud-user"
            ;;
        *) USER="ec2-user";;                        
    esac
else
    USER="${SSH_USER}"
fi

echo "USER: ${USER}
SSH_USER: ${SSH_USER}"

case "${PRDT}" in
    "rke2")
        PORT="9345"
        if [ -z "${RKE2_REPO_PATH}" ]; then
            REPO_PATH="${HOME}/repos/${PRDT}"
        else
            REPO_PATH="${RKE2_REPO_PATH}"  # Set Env Variable
        fi
        ;;
    "k3s")
        PORT="6443"
        if [ -z "${K3S_REPO_PATH}" ]; then
            REPO_PATH="${HOME}/repos/${PRDT}"
        else
            REPO_PATH="${K3S_REPO_PATH}"  # Set Env Variable
        fi    
        ;;
esac
if [ "${LOG}" = "debug" ]; then
    echo "SET: 
    OS_NAME=${OS_NAME}
    USER=${USER}"
fi
PORT="9345"

# CIS / PROTECT_KERNEL and SELINUX related edits
if [ "${CIS}" = true ]; then
    PROTECT_KERNEL=true  # If cis profile value is set, this is default to true automatically - else install will fail
    if [ "${INSTALL_METHOD}" = "rpm" ]; then
        CIS_SYSCTL_FILE_PATH="/usr/share/rke2/rke2-cis-sysctl.conf"
    else
        CIS_SYSCTL_FILE_PATH="/usr/local/share/rke2/rke2-cis-sysctl.conf"
    fi
fi
if [ -z "${VERSION}" ]; then
    if echo "${RELEASE_BRANCH}" | grep -q "1.24"; then
        CIS_PROFILE="cis-1.6"
    else
        CIS_PROFILE="cis"  # deprecated value: cis-1.23
    fi
else
    if echo "${VERSION}" | grep -q "1.24"; then
        CIS_PROFILE="cis-1.6"
    else
        CIS_PROFILE="cis"  # deprecated value: cis-1.23
    fi
fi
if [ "${OS_NAME}" = "rhel" ] || echo "${OS_NAME}" | grep -q "slemicro"; then
    SELINUX=true
else
    SELINUX=false
fi
if [ "${CUSTOM_SELINUX_TEST}" = true ]; then
    SELINUX=true
fi
# SELINUX=false

if [ "${CERT_ROTATE}" = true ] || [ "${SECRETS_ENCRYPT_TEST}" = true ]; then
    ETCD=true
    SECRETS_ENCRYPT=true
fi
if [ "${LOG}" = "debug" ]; then
    echo "SET: 
    CIS=${CIS}
    CIS_PROFILE=${CIS_PROFILE}
    PROTECT_KERNEL=${PROTECT_KERNEL}
    SELINUX=${SELINUX}
    ETCD=${ETCD}
    SECRETS_ENCRYPT=${SECRETS_ENCRYPT}
    "
fi

# Setup Type - 4 node install with 1 version VS two 2-node installs with different versions/commits.
# SPLIT_INSTALL=true  # SERVER1 and AGENT1 on a version|commit, while SERVER2 and AGENT2 on version2|commit
# REPO_PATH="${HOME}/repos/rke2"
if [ "${SERVER2}" ] && [ "${SERVER3}" ]; then
    SPLIT_INSTALL=false
    # echo "This is a 4 node setup test run"
    if [ -z "${VERSION}" ] ; then  # If VERSION was empty, we get COMMIT for RELEASE_BRANCH 
        if [ "${RELEASE_BRANCH}" ]; then
            COMMIT=$(cd ${REPO_PATH}; git checkout ${RELEASE_BRANCH} &> /dev/null && git pull &> /dev/null; git rev-parse HEAD)
            echo "4 node HA Setup: will be installed with COMMIT: ${COMMIT}"
        else
            if [ "${COMMIT}" ]; then
                echo "4 node HA Setup: will be installed with COMMIT: ${COMMIT}"
            else
                echo "FATAL: Please set RELEASE_BRANCH var to get COMMIT OR directly set COMMIT vat OR set VERSION var to install desired version"
                exit
            fi
        fi
    else
        echo "4 node HA Setup: will be installed with VERSION: ${VERSION}"
    fi
else
    SPLIT_INSTALL=true
    echo "This is a 2 node test run"
    if [ -z "${COMMIT}" ]; then
        if [ -z "${RELEASE_BRANCH}" ]; then  # VERSION was provided as input
            if [ -z "${VERSION}" ]; then
                echo "FATAL: Provide VERSION or RELEASE_BRANCH or COMMIT values for setup 1 testing"
                exit
            fi
            echo "2 node server/agent Setup 1: SERVER1:${SERVER1}/AGENT1:${AGENT1} Combo will be installed with VERSION: ${VERSION}"
        else  # RELEASE_BRANCH was provided as input - we need to find COMMIT value
            COMMIT=$(cd ${REPO_PATH}; git checkout ${RELEASE_BRANCH} &> /dev/null && git pull &> /dev/null; git rev-parse HEAD)
            echo "2 node server/agent Setup 1: SERVER1:${SERVER1}/AGENT1:${AGENT1} Combo will be installed on RELEASE_BRANCH: ${RELEASE_BRANCH} with COMMIT: ${COMMIT}"
        fi
    else  # COMMIT was provided as input 
        echo "2 node server/agent Setup 1: SERVER1:${SERVER1}/AGENT1:${AGENT1} Combo will be installed with COMMIT: ${COMMIT}"
    fi

    # During issue validation we need older VERSION setup and newer COMMIT2 from RELEASE_BRANCH2 based on VERSION
    # Both setups will be in same release branch. We get RELEASE_BRANCH2 based on VERSION here:
    if [ -z "${VERSION2}" ]; then
        if [ -z "${COMMIT2}" ]; then  # COMMIT2 not provided, we need to get the same. 
            if [ -z "${RELEASE_BRANCH2}" ]; then
                if [ -z "${VERSION}" ];then
                    echo "FATAL: Please provide VERSION2 or RELEASE_BRANCH2 or COMMIT 2 values for setup2; 
Note: VERSION from setup1 can be used to find RELEASE_BRANCH2; but if we use COMMIT/RELEASE_BRANCH for setup1, we need to explicitly set the same for setup2"
                    exit
                fi
                if echo "${VERSION}" | grep -q "1.28"; then
                    RELEASE_BRANCH2="master"
                fi
                if echo "${VERSION}" | grep -q "1.27"; then
                    RELEASE_BRANCH2="release-1.27"
                fi    
                if echo "${VERSION}" | grep -q "1.26"; then
                    RELEASE_BRANCH2="release-1.26"
                fi
                if echo "${VERSION}" | grep -q "1.25"; then
                    RELEASE_BRANCH2="release-1.25"
                fi
                if echo "${VERSION}" | grep -q "1.24"; then
                    RELEASE_BRANCH2="release-1.24"
                fi
            fi   
            COMMIT2=$(cd ${REPO_PATH}; git checkout ${RELEASE_BRANCH2} &> /dev/null && git pull &> /dev/null; git rev-parse HEAD)
        fi
        echo "2 node server/agent Setup 2: SERVER2:${SERVER2}/AGENT2:${AGENT2} Combo will be installed on RELEASE_BRANCH2: ${RELEASE_BRANCH2} with COMMIT ID: ${COMMIT2}"
    else
        echo "2 node server/agent Setup 2: SERVER2:${SERVER2}/AGENT2:${AGENT2} Combo will be installed with VERSION2: ${VERSION2}"
    fi
fi


if [ "${LOG}" = "debug" ]; then
    echo "SET: 
    SPLIT_INSTALL=${SPLIT_INSTALL}
    RELEASE_BRANCH=${RELEASE_BRANCH}
    RELEASE_BRANCH2=${RELEASE_BRANCH2}
    VERSION=${VERSION}
    VERSION2=${VERSION2}
    COMMIT=${COMMIT}
    COMMIT2=${COMMIT2}    
    "
fi


# AUTO_UPGRADE_RELEASE=$(echo "${VERSION2}" | sed 's/+//g')
# echo "SET AUTO_UPGRADE_RELEASE: ${AUTO_UPGRADE_RELEASE}"
# "1.26"  # 1.24 | 1.25 | 1.26 | 1.27


PEM="${HOME}/.ssh/archana-aws.pem"

# File/Path on the server/agent nodes
USER_HOME="/home/${USER}"
CONFIG_DIR="/etc/rancher/rke2"
DATADIR="/var/lib/rancher/rke2"
SERVER_DIR="${DATADIR}/server"
MANIFEST_DIR="${SERVER_DIR}/manifests"
LOGS_DIR="${SERVER_DIR}/logs"

# Install configs and yamls
YAML_FOLDER="${PWD}/yamls"
# TO DO: Create a test config folder and dynamic test run folder - to store test run related config files.
BASIC_CONFIG="${YAML_FOLDER}/rke2.basic.yaml"
SERVER1_CONFIG="${YAML_FOLDER}/server1-${VERSION_UNDER_TEST}.yaml"
SERVER2_CONFIG="${YAML_FOLDER}/server2-${VERSION_UNDER_TEST}.yaml"
SERVER3_CONFIG="${YAML_FOLDER}/server3-${VERSION_UNDER_TEST}.yaml"
AGENT1_CONFIG="${YAML_FOLDER}/agent1-${VERSION_UNDER_TEST}.yaml"
AGENT2_CONFIG="${YAML_FOLDER}/agent2-${VERSION_UNDER_TEST}.yaml"
POD_SECURITY_YAML="${YAML_FOLDER}/pod-security.yaml"
AUDIT_YAML="${YAML_FOLDER}/audit-policy.yaml"
# Source Files - aliases and 3rd party installers
SOURCE_FOLDER="${PWD}/sources"
SOURCE="${SOURCE_FOLDER}/rke2.source"
SOURCE2="${SOURCE_FOLDER}/aliases.sh"
ETCDCTL_INSTALLER="${SOURCE_FOLDER}/etcdctl_installer.sh"
# Test related Yamls
WORKLOADS_GH="https://gist.githubusercontent.com/rancher-max/5b160babb714d8d5a123df6a24ec9b3d/raw/7e2d36fbf735e6d1e2a8e10cc2cf1ce19ea7c978/workloads.yaml"
WORKLOADS_GH_MORE="https://gist.githubusercontent.com/aganesh-suse/cea96a8648001cd06098f49694f8adc9/raw/6f16496a7a4f4e0ffc9d9bcbcddae09b718a0fcb/more-workloads.yaml"

CUSTOM_WORKLOAD_YAML="${YAML_FOLDER}/custom_workload.yaml"
CUSTOM_WORKLOAD_DESTINATION_FILE_PATH="/home/${USER}/custom_workload.yaml"

CUSTOM_MANIFEST_YAML="${YAML_FOLDER}/custom_manifest.yaml"
CUSTOM_MANIFEST_DESTINATION_FILE_PATH="/home/${USER}/rke2-canal-config.yaml"  # Edit the file name for destination

CLUSTERIP_YAML="${YAML_FOLDER}/clusterip.yaml"

SUC_PRIVILEGED_YAML="${YAML_FOLDER}/system-upgrade-controller-privileged.yaml"
SU_NS_PRIVILEGE_YAML="${YAML_FOLDER}/su_ns_privilege.yaml"

AUTO_UPGRADE_PLAN_YAML="${YAML_FOLDER}/auto_upgrade_plan.yaml"

if [ "${SUC_UPGRADE}" = true ]; then
    AUTO_UPGRADE_RELEASE=$(echo "${VERSION2}" | sed 's/+/_/g' | sed 's/-/_/g')
    echo "SET AUTO_UPGRADE_RELEASE: ${AUTO_UPGRADE_RELEASE}"
    # "1.26"  # 1.24 | 1.25 | 1.26 | 1.27
    AUTO_UPGRADE_PLAN_YAML_FILE="${YAML_FOLDER}/auto_upgrade_plan_${AUTO_UPGRADE_RELEASE}.yaml"
fi

SYSTEM_UPGRADE_CONTROLLER_VERSION="latest"
# SYSTEM_UPGRADE_CONTROLLER_VERSION="v0.11.0"
if [ "${SYSTEM_UPGRADE_CONTROLLER_VERSION}" = "latest" ]; then
    SYSTEM_UPGRADE_CRD="https://github.com/rancher/system-upgrade-controller/releases/latest/download/system-upgrade-controller.yaml"
else
    SYSTEM_UPGRADE_CRD="https://github.com/rancher/system-upgrade-controller/releases/download/${SYSTEM_UPGRADE_CONTROLLER_VERSION}/system-upgrade-controller.yaml"
fi

KUBECONFIG="--kubeconfig ${CONFIG_DIR}/rke2.yaml"
KUBECTL_PATH="${DATADIR}/bin/kubectl"
KUBECTL="${KUBECTL_PATH} ${KUBECONFIG}"
DB_PATH="${DATADIR}/server/db"
DB_PATH_BACKUP="${DATADIR}/server/db-backup"
SNAPSHOTS_DIR="${DB_PATH}/snapshots"
# # File/Path on the server/agent nodes
# USER_HOME="/home/${USER}"
# CONFIG_DIR="/etc/rancher/rke2"
# DATADIR="/var/lib/rancher/rke2"


# S3 Related vars  # TODO: Delete the snapshots created by test
S3_BUCKET="sonobuoy-results"
S3_FOLDER="${PREFIX}-${PRDT}snap/${CLUSTER_NAME}"
S3_FOLDER_1="${S3_FOLDER}/${PRDT}-1"
S3_FOLDER_2="${S3_FOLDER}/${PRDT}-2"
S3_FOLDER_3="${S3_FOLDER}/${PRDT}-3"
S3_URL_1="s3://${S3_BUCKET}/${S3_FOLDER_1}"
S3_URL_2="s3://${S3_BUCKET}/${S3_FOLDER_2}"
S3_URL_3="s3://${S3_BUCKET}/${S3_FOLDER_3}"
S3_REGION="us-east-2"

if [ "${CLUSTER_RESET_RESTORE_PATH_TEST}" = true ] || [ "${CLUSTER_RESET}" = true ] || [ "${ETCD_SNAPSHOT_RETENTION}" = true ]; then
    TAKE_SNAPSHOT=true
    TOKEN="secret"
fi
if [ "${ETCD_SNAPSHOT_RETENTION}" = true ]; then
    # ETCD=true
    NODE_NAME=true
fi
if [ "${INSTALL_RANCHER_MANAGER}" = true ]; then
    TLS_SAN=true
fi

if [ "${LOG}" = "debug" ]; then
    echo "SET: TAKE_SNAPSHOT=${TAKE_SNAPSHOT}
    ETCD: ${ETCD}
    NODE_NAME: ${NODE_NAME}
    TLS_SAN: ${TLS_SAN}
    "
fi

# OVERRIDE VARIABLES
# SELINUX=false  # In case we want to override and have false even for rhel
# USER="cloud-user"  # In case we need to override user value.
# INSTALL_METHOD="rpm"
TAKE_SNAPSHOT=false
# NODE_NAME=false
# SELINUX=false
TOKEN="secret"
# Delete the content of the s3 bucket and folder before starting the test.
if [ "${REINSTALL}" = true ]; then
    echo "S3_FOLDER: ${S3_FOLDER}"
    echo "Deleting S3_URLs: ${S3_URL_1} ${S3_URL_2} ${S3_URL_3}"
    aws s3 rm "${S3_URL_1}" --recursive
    aws s3 rm "${S3_URL_2}" --recursive
    aws s3 rm "${S3_URL_3}" --recursive
fi
