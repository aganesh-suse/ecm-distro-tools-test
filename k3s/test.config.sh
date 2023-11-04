LOG="debug"  # Can be debug or info. More logs for debug value
VERSION_UNDER_TEST="128_3"  # used for config file names to make them unique to version being tested
PRDT="k3s"
# ENV VARS: 
PEM="${PEM_FILE_PATH}"
S3_ACCESS_KEY="${AWS_ACCESS_KEY_ID}"
S3_SECRET_KEY="${AWS_SECRET_ACCESS_KEY}"
REPO_PATH="${HOME}/repos/${PRDT}"


OS_NAME="ubuntu"
SERVER3="3.129.128.78"
SERVER2="18.191.18.220"
SERVER1="3.143.238.251"
AGENT1="18.218.207.233"

# COMMIT="c0d00b9ebb9c9d2822b7d7e6e549c2f917930393"
# RELEASE_BRANCH="master"
# RELEASE_BRANCH="release-1.27"
# RELEASE_BRANCH="release-1.26"
# RELEASE_BRANCH2="release-1.25"
# RELEASE_BRANCH2="release-1.25"
if [ "${RELEASE_BRANCH}" ] || [ "${COMMIT}" ]; then
# PRIVATE_IP="172.31.20.65"
    CLUSTER_NAME="commit-setup-${VERSION_UNDER_TEST}"  # S3 Folder Name; Values are: commit-setup or version-setup
else
    CLUSTER_NAME="version-setup-${VERSION_UNDER_TEST}"  # S3 Folder Name
fi
# echo "RELEASE_BRANCH=${RELEASE_BRANCH}"


# Previous versions (Pre-Upgrade/Install Versions)
# VERSION="v1.28.3+k3s1"
# VERSION="v1.27.7+k3s1"
# VERSION="v1.26.10+k3s1"
# VERSION="v1.25.15+k3s1"

# RC1 INSTALL BUILDS
# VERSION="v1.28.4-rc1+k3s1"
# VERSION="v1.27.8-rc1+k3s1"
# VERSION="v1.26.11-rc1+k3s1"
# VERSION="v1.25.16-rc1+k3s1"

# RC1 MANUAL UPGRADE BUILDS
# VERSION2="v1.28.3-rc1+k3s1"
# VERSION2="v1.27.7-rc1+k3s1"
# VERSION2="v1.26.10-rc1+k3s1"
# VERSION2="v1.25.15-rc1+k3s1"

# RC1 SUC UPGRADE BUILDS
# VERSION2="v1.28.3-rc1-k3s1"
# VERSION2="v1.27.7-rc1-k3s1"
# VERSION2="v1.26.10-rc1-k3s1"
# VERSION2="v1.25.15-rc1-k3s1"

# Final Release (Post Release check builds)
VERSION="v1.28.3+k3s1"
# VERSION="v1.27.7+k3s1"
# VERSION="v1.26.10+k3s1"
# VERSION="v1.25.15+k3s1"

# COMMIT=$(cd ${REPO_PATH}; git checkout ${RELEASE_BRANCH} &> /dev/null && git pull &> /dev/null; git rev-parse HEAD)

# SETUP2
# RELEASE_BRANCH2="release-1.26"
# COMMIT2=$(cd ${REPO_PATH}; git checkout ${RELEASE_BRANCH2} &> /dev/null && git pull &> /dev/null; git rev-parse HEAD)
# VERSION2=""

# We either test 4 node cluster as SERVER1, SERVER2, SERVER3, AGENT1 - using $version for installs
# or 
# 2 node clusters - 2 setups as SERVER1, AGENT1 and SERVER2, AGENT2
# using $version for 1setup install and $version2 for second setup install
# in case of repro/validation setups needed


# Patch Validation Test options
MANUAL_UPGRADE=false
NODE_REPLACEMENT=false
SECRETS_ENCRYPT_TEST=false
CERT_ROTATE=false
SUC_UPGRADE=false
SYSTEM_UPGRADE_CONTROLLER_VERSION="latest"  # Can be 'latest' or version: 'v0.11.0'
DOCKER_CRI=false
RESTART_SERVICES=false
CLUSTER_RESET=false
CLUSTER_RESET_RESTORE_PATH_TEST=false
CLUSTER_RESET_WITH_RESTORE=false  # does not uninstall server1. runs test with killall/delete db of servers 2 and 3 like regular cluster restore test. except we use restore from snapshot in this case. 
RESTORE_FROM_S3_OR_LOCAL="s3"  # Can be s3 | local

# Issue Validation Tests
# ETCD_SNAPSHOT_RETENTION_UPDATE_NODE_NAMES=false
# ETCD_SNAPSHOT_RETENTION_VALUE=2
ETCD_SNAPSHOT_TEST=false
ETCD_SNAPSHOT_RETENTION_VALUE=2
ON_DEMAND_SNAPSHOT_COUNT=3
PRUNE_RETENTION_VALUE=2

FLANNEL_TEST=false # Version bump tests
INSTALL_RANCHER_MANAGER=false
RANCHER_VERSION="v2.7.6"
STARGZ_LOGS=false  # logs the stargz related log lines
CUSTOM_TEST=false
SANITY_TEST=true

# installer and config options
REINSTALL=true
SSH_KEYSCAN=true  # Auto add hosts to known_hosts file. Should be run ONLY first time the setup is used for testing to avoid duplicate entries in known_hosts file
PREP_SLEMICRO=false
APPLY_WORKLOAD=true  # Use this for applying workload post install - if we only need install stage run and all tests are false. Esp in case of server1/agent1 and server2/agent2 configs, say. 
ETCD=false  # split roles in servers
SECRETS_ENCRYPT=false  # this generally goes together with the etcd value
TLS_SAN=false
DOCKER=false  # Set to true for docker cri test
EXEC=false  # if true Uses INSTALL_K3S_EXEC in the installer command
PREFER_BUNDLED_BIN=false
IPTABLES=false  # To install on rhel nodes set to true
# note - should cis, pod security and restricted be 1 option? are they the same purpose? 
# The following config options need further rigorous testing and bug fixing - use with caution 

# NO CNI FOR K3S. ONLY FLANNEL IS SUPPORTED WHICH IS DEFAULT
# CNI=false
# CNI_TYPE="cilium"  # can be canal or cilium TODO add cni in config
AUDIT=false
CIS=false  # Extra Hardening for RHEL
RESTRICTED=false  # Pod Security Restricted? true | false
NODE_NAME=false
NODE_EXTERNAL_IP=true

CUSTOM_WORKLOAD=false  # Update the workload content for the custom_workload.yaml file. OR
# Update the CUSTOM_WORKLOAD_YAML and CUSTOM_WORKLOAD_DESTINATION_FILE_PATH vars below, to the workload yaml filename to apply post install

if [ "${DOCKER_CRI}" = true ]; then
    DOCKER=true
fi
if [ "${MANUAL_UPGRADE}" = true ]; then
    EXEC=true
fi
if echo "${OS_NAME}" | grep -q "rhel" || echo "${OS_NAME}" | grep -q "slemicro"; then
    SELINUX=true
else
    SELINUX=false
fi

if [ "${LOG}" = "debug" ]; then
    echo "SET:
    DOCKER=${DOCKER}
    EXEC=${EXEC}
    SELINUX=${SELINUX}"
fi

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
    REPO_PATH=${REPO_PATH}
    PORT=${PORT}
    "
fi
# Setups
# SPLIT_INSTALL=true  # SERVER1 and AGENT1 on a version|commit, while SERVER2 and AGENT2 on version2|commit

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



if [ "${LOG}" = "debug" ]; then
    echo "SET:
    SPLIT_INSTALL=${SPLIT_INSTALL}
    VERSION=${VERSION}
    VERSION2=${VERSION2}
    RELEASE_BRANCH=${RELEASE_BRANCH}
    RELEASE_BRANCH2=${RELEASE_BRANCH2}
    COMMIT=${COMMIT}
    COMMIT2=${COMMIT2}
    OS_NAME=${OS_NAME}
    USER=${USER}
    SSH_USER=${SSH_USER}"
fi


# Config Edits based on tests/configs set to true
if [ "${CERT_ROTATE}" = true ] || [ "${SECRETS_ENCRYPT_TEST}" = true ]; then
    ETCD=true
    SECRETS_ENCRYPT=true
fi
if [ "${CIS}" = true ]; then
    PROTECT_KERNEL=true  # Extra Hardening for rhel
    POD_SECURITY=true
    if [ "${RESTRICTED}" = true ]; then  # pod-security restricted
        POD_SECURITY_TYPE="restricted"  # Can be: privileged | restricted
    else
        POD_SECURITY_TYPE="privileged"
    fi
else
    PROTECT_KERNEL=false
    POD_SECURITY=false  
fi

if [ "${INSTALL_RANCHER_MANAGER}" = true ]; then
    TLS_SAN=true
fi

if [ "${LOG}" = "debug" ]; then
    echo "SET:
    ETCD=${ETCD}
    SECRETS_ENCRYPT=${SECRETS_ENCRYPT}
    CIS=${CIS}
    PROTECT_KERNEL=${PROTECT_KERNEL}
    POD_SECURITY=${POD_SECURITY}
    RESTRICTED=${RESTRICTED}
    POD_SECURITY_TYPE=${POD_SECURITY_TYPE}
    TLS_SAN=${TLS_SAN}
    "
fi

# File/Path on the server/agent nodes
PRDT="k3s"  # Product we are testing
USER_HOME="/home/${USER}"
CONFIG_DIR="/etc/rancher/${PRDT}"
DATADIR="/var/lib/rancher/${PRDT}"
CONFIG_YAML_FILE_PATH="${CONFIG_DIR}/config.yaml"

# File locations
YAML_FOLDER="${PWD}/yamls"
BASIC_CONFIG="${YAML_FOLDER}/k3s.basic.yaml"
SERVER1_CONFIG="${YAML_FOLDER}/server1_${VERSION_UNDER_TEST}.yaml"
SERVER2_CONFIG="${YAML_FOLDER}/server2_${VERSION_UNDER_TEST}.yaml"
SERVER3_CONFIG="${YAML_FOLDER}/server3_${VERSION_UNDER_TEST}.yaml"
AGENT1_CONFIG="${YAML_FOLDER}/agent1_${VERSION_UNDER_TEST}.yaml"
AGENT2_CONFIG="${YAML_FOLDER}/agent2_${VERSION_UNDER_TEST}.yaml"
# Configs relates files
KUBELET_CONF_KERNEL_PARAMS="${YAML_FOLDER}/90-kubelet.conf"
if [ "${RESTRICTED}" = false ]; then 
    POD_SECURITY_YAML="${YAML_FOLDER}/pod-security.yaml"
else    
    POD_SECURITY_YAML="${YAML_FOLDER}/pod-security-restricted.yaml"
fi    
AUDIT_YAML="${YAML_FOLDER}/audit.yaml"
# Source Files - aliases and 3rd party installers
SOURCE_FOLDER="${PWD}/sources"
SOURCE="${SOURCE_FOLDER}/k3s.source"
SOURCE2="${SOURCE_FOLDER}/aliases.sh"
ETCDCTL_INSTALLER="${SOURCE_FOLDER}/etcdctl_installer.sh"
# Test Related yamls
# Workloads
WORKLOADS_GH="https://gist.githubusercontent.com/rancher-max/5b160babb714d8d5a123df6a24ec9b3d/raw/7e2d36fbf735e6d1e2a8e10cc2cf1ce19ea7c978/workloads.yaml"
WORKLOADS_GH_MORE="https://gist.githubusercontent.com/aganesh-suse/cea96a8648001cd06098f49694f8adc9/raw/6f16496a7a4f4e0ffc9d9bcbcddae09b718a0fcb/more-workloads.yaml"
CUSTOM_WORKLOAD_YAML="${YAML_FOLDER}/custom_workload.yaml"
CUSTOM_WORKLOAD_DESTINATION_FILE_PATH="/home/${USER}/custom_workload.yaml"
CLUSTERIP_YAML="${YAML_FOLDER}/clusterip.yaml"
WEB_YAML="${YAML_FOLDER}/web.yaml"  # Chart with Boostrap option

SU_NS_PRIVILEGE_YAML="${YAML_FOLDER}/su_ns_privilege.yaml"
# suc_privileged_yaml="${YAML_FOLDER}/system-upgrade-controller-privileged.yaml"
AUTO_UPGRADE_PLAN_YAML="${YAML_FOLDER}/auto_upgrade_plan.yaml"
if [ "${SUC_UPGRADE}" = true ]; then
    AUTO_UPGRADE_RELEASE=$(echo "${VERSION2}" | sed 's/+/_/g' | sed 's/-/_/g')
    echo "SET AUTO_UPGRADE_RELEASE: ${AUTO_UPGRADE_RELEASE}"
    # "1.26"  # 1.24 | 1.25 | 1.26 | 1.27
    AUTO_UPGRADE_PLAN_YAML_FILE="${YAML_FOLDER}/auto_upgrade_plan_${AUTO_UPGRADE_RELEASE}.yaml"
fi

# SYSTEM_UPGRADE_CONTROLLER_VERSION="v0.11.0"
if [ "${SYSTEM_UPGRADE_CONTROLLER_VERSION}" = "latest" ]; then
    SYSTEM_UPGRADE_CRD="https://github.com/rancher/system-upgrade-controller/releases/latest/download/system-upgrade-controller.yaml"
else
    SYSTEM_UPGRADE_CRD="https://github.com/rancher/system-upgrade-controller/releases/download/${SYSTEM_UPGRADE_CONTROLLER_VERSION}/system-upgrade-controller.yaml"
fi
# SYSTEM_UPGRADE_CRD="https://github.com/rancher/system-upgrade-controller/releases/download/${SYSTEM_UPGRADE_CONTROLLER_VERSION}/system-upgrade-controller.yaml"
# SYSTEM_UPGRADE_CRD="https://github.com/rancher/system-upgrade-controller/releases/latest/download/system-upgrade-controller.yaml"

CERT_MANAGER_VERSION="latest"  # Latest version: v1.13.0 ; Old version Max uses: v1.11.0
if [ "${CERT_MANAGER_VERSION}" = "latest" ]; then
    CERT_MANAGER_CRD="https://github.com/jetstack/cert-manager/releases/latest/download/cert-manager.crds.yaml"
else
    CERT_MANAGER_CRD="https://github.com/jetstack/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.crds.yaml"
fi
CERT_MANAGER_NS="cert-manager"

KUBECONFIG="--kubeconfig ${CONFIG_DIR}/k3s.yaml"
KUBECTL_PATH="/usr/local/bin/kubectl"
KUBECTL="sudo ${KUBECTL_PATH} ${KUBECONFIG}"

# Path and Filenames on On the server/agent nodes
# CONFIG_FILE_PATH="${CONFIG_DIR}"
# SERVER_FILE_PATH="${DATADIR}/server"
# USER_HOME="/home/${USER}"
DB_PATH="${DATADIR}/server/db"
DB_PATH_BACKUP="${DATADIR}/server/db-backup"

# S3 Related vars
S3_BUCKET="sonobuoy-results"
S3_FOLDER="${PREFIX}-${PRDT}snap/${CLUSTER_NAME}"
S3_FOLDER_1="${S3_FOLDER}/k3s1"
S3_FOLDER_2="${S3_FOLDER}/k3s2"
S3_FOLDER_3="${S3_FOLDER}/k3s3"
S3_URL_1="s3://${S3_BUCKET}/${S3_FOLDER_1}"
S3_URL_2="s3://${S3_BUCKET}/${S3_FOLDER_2}"
S3_URL_3="s3://${S3_BUCKET}/${S3_FOLDER_3}"
S3_REGION="us-east-2"
TOKEN="secret"

if [ "${CLUSTER_RESET_RESTORE_PATH_TEST}" = true ]; then
    TAKE_SNAPSHOT=true    
fi

if [ "${NODE_REPLACEMENT}" = true ] || [ "${ETCD_SNAPSHOT_RETENTION_UPDATE_NODE_NAMES}" = true ]; then
    NODE_NAME=true
fi

# OVERRIDE VARIABLES
# SELINUX=false  # In case we want to override and have false even for rhel
# USER="cloud-user"  # In case we need to override user value.
TEARDOWN=true
PORT="6443"
# Delete the content of the s3 bucket and folder before starting the test.
if [ "${REINSTALL}" = true ]; then
    aws s3 rm "${S3_URL_1}" --recursive
    aws s3 rm "${S3_URL_2}" --recursive
    aws s3 rm "${S3_URL_3}" --recursive
fi
