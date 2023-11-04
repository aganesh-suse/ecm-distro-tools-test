#!/bin/sh

# shellcheck source="./test.config.sh"
if [ "$1" ]; then
    . "$1"
else
    . ./test.config.sh
fi

execute () {
    # $1 command string $2 SERVER_IP $3 SERVER_TYPE $4 "SKIP" echo output
    if [ -z $2 ]; then
        if [ -z $4 ]; then
            echo "Execute: "
            echo "$ $1 On SERVER1: ${SERVER1}"
        fi
        ssh -i "${PEM}" "${USER}"@"$SERVER1" "$1"
    else
        if [ -z $4 ]; then    
            echo "Execute: "
            echo "$ $1 On $3: $2"
        fi
        ssh -i "${PEM}" "${USER}"@"$2" "$1"
    fi
}

copy () {
    # $1 Local_Source_File_Path $2 Remote_Destination_File_Path $3 Node_IP $4 Node_Type(Optional)
    echo "Copy File from $1 to $2 on Node $4: $3"
    scp -i "${PEM}" "$1" "${USER}"@"$3":"$2"
}

print_ssh_info () {
    # $1 NODE_IP whose ssh details we want to print 
    echo "========================================
    ssh -i ${PEM} ${USER}@$1
========================================"
}

ssh_keyscan () {
    if [ "${SSH_KEYSCAN}" = true ]; then
        if [ -z "${SERVER1}" ]; then
            echo "SERVER1 not found - skipping ssh-keyscan"
        else
            echo "Adding SERVER1 ${SERVER1} ssh-keyscan"
            ssh-keyscan -H "${SERVER1}" >> "${HOME}/.ssh/known_hosts"
        fi
        if [ -z "${SERVER2}" ]; then
            echo "SERVER2 not found - skipping ssh-keyscan"
        else
            echo "Adding SERVER2 ${SERVER2} ssh-keyscan"        
            ssh-keyscan -H "${SERVER2}" >> "${HOME}/.ssh/known_hosts"
        fi
        if [ -z "${SERVER3}" ]; then
            echo "SERVER3 not found - skipping ssh-keyscan"
        else
            echo "Adding SERVER3 ${SERVER3} ssh-keyscan"        
            ssh-keyscan -H "${SERVER3}" >> "${HOME}/.ssh/known_hosts"
        fi
        if [ -z "${AGENT1}" ]; then
            echo "AGENT1 not found - skipping ssh-keyscan"
        else
            echo "Adding AGENT1 ${AGENT1} ssh-keyscan"        
            ssh-keyscan -H "${AGENT1}" >> "${HOME}/.ssh/known_hosts"
        fi
        if [ -z "${AGENT2}" ]; then
            echo "AGENT2 not found - skipping ssh-keyscan"
        else
            echo "Adding AGENT2 ${AGENT2} ssh-keyscan"        
            ssh-keyscan -H "${AGENT2}" >> "${HOME}/.ssh/known_hosts"
        fi
    fi
}

update_selinux () {
    # $1 Node_IP $2 Node_Type
    echo "======Update SELINUX for $2 $1========"
    execute "sudo transactional-update setup-selinux; sudo reboot" "$1" "$2"
    echo "========== $2 DONE ===========================" 
}

prep_slemicro () {
    if [ "${PREP_SLEMICRO}" = true ]; then
        if echo "${OS_NAME}" | grep -q "slemicro"; then
            if [ "${SERVER1}" ];then
                update_selinux "${SERVER1}" "SERVER1"
            fi
            if [ "${SERVER2}" ];then
                update_selinux "${SERVER2}" "SERVER2"               
            fi
            if [ "${SERVER3}" ];then
                update_selinux "${SERVER3}" "SERVER3"                
            fi
            if [ "${AGENT1}" ];then
                update_selinux "${AGENT1}" "AGENT1"                  
            fi
            if [ "${AGENT2}" ];then
                update_selinux "${AGENT2}" "AGENT2"              
            fi
            echo "Sleep for 60 seconds - waiting for VM to come back on after reboot"; sleep 60                                 
        fi
    fi
}

prep_fapolicyd () {
    if [ "${PREP_FAPOLICYD}" = true ]; then
        if echo "${OS_NAME}" | grep -q "rhel"; then
            if [ "${SERVER1}" ]; then
                execute "sudo yum install fapolicyd -y" "${SERVER1}" "SERVER1"
            fi
            if [ "${SPLIT_INSTALL}" = true ] && [ "${SERVER2}" ]; then
                execute "sudo yum install fapolicyd -y" "${SERVER2}" "SERVER2"
            fi
        fi
    fi
}

permissions_update () {
    # Provide permissions for the kubeconfig file in case of slemicro/selinux enabled.
    if echo "${OS_NAME}" | grep -q "slemicro"; then
        if echo "$2" | grep -q "SERVER"; then
            execute "sudo chmod 755 ${CONFIG_DIR}/rke2.yaml" "$1" "$2"
        fi
    fi    
}

cleanup_configs () {
    if [ "${REINSTALL}" = true ]; then
        rm -rf "${SERVER1_CONFIG}"
        rm -rf "${SERVER2_CONFIG}"
        rm -rf "${SERVER3_CONFIG}"
        rm -rf "${AGENT1_CONFIG}"
        rm -rf "${AGENT2_CONFIG}"
    fi
}

which_rke2_uninstall () {
    # Find path of rke2-uninstall.sh in different platforms
    RKE2_UNINSTALL=$(execute "which rke2-uninstall.sh" "${SERVER1}" "SERVER1" "SKIP_LOG")
    RKE2_AGENT_UNINSTALL=$(execute "which rke2-agent-uninstall.sh" "${AGENT1}" "AGENT1" "SKIP_LOG")  
}

uninstall () {
    # Uninstall rke2 - server
    # $1 Node_IP_Address $2 Node_Type
    # Ex: Call using: uninstall ${SERVER1} "SERVER1"
    echo "==========================================================
    UNINSTALL rke2 service for $2: $1
=========================================================="
    execute " grep -qxF 'export PATH=\$PATH:/var/lib/rancher/rke2/bin:/mnt/bin' ~/.bashrc || echo 'export PATH=\$PATH:/var/lib/rancher/rke2/bin:/mnt/bin' >> ~/.bashrc" "$1" "$2"
    if [ -z "${RKE2_UNINSTALL}" ]; then
        which_rke2_uninstall
    fi
    execute "sudo ${RKE2_UNINSTALL}" "$1" "$2"
    echo "=========================================================="
}

uninstall_agent () {
    # Uninstall rke2 agent
    # $1 Node_IP_Address $2 Node_Type
    # Ex: Call using: uninstall_agent ${AGENT1} "AGENT1"
    echo "==========================================================
    UNINSTALL rke2 service for $2: $1
=========================================================="
    if [ -z "${RKE2_UNINSTALL}" ]; then
        which_rke2_uninstall
    fi
    execute "sudo ${RKE2_AGENT_UNINSTALL}" "$1" "$2"
    echo "=========================================================="    
}

install_iptables () {
    # Install iptables on rhel
    # $1 node_ip_address #2 node_type
    if echo "${OS_NAME}" | grep -q "rhel"; then
        echo "Install iptables on $2: $1"
        execute "sudo  dnf install iptables-services -y" "$1" "$2" 
    fi    
}

install_etcdctl () {
    # Install Etcdctl
    # $1 Node IP address
    echo "INSTALL etcdctl"
    if echo "${OS_NAME}" | grep -q "ubuntu"; then
        execute "sudo apt-get update; sudo -- apt install etcd-client" "$1"
        ETCDCTL="/usr/bin/etcdctl"
    else  # rhel | slemicro | rocky etc
        # copy etcdctl installer and run the same
        copy "${ETCDCTL_INSTALLER}" "${USER_HOME}/etcdctl_installer.sh" "$1" 
        execute "chmod +x ${USER_HOME}/etcdctl_installer.sh" "$1"
        execute "${USER_HOME}/etcdctl_installer.sh" "$1"
        ETCDCTL="/tmp/etcd-download-test/etcdctl"
    fi
}

get_pods_for_ns () {
    # $1 NAMESPACE $2 Node_IP $3 Show_Labels
    # Ex: get_pods_for_ns "clusterip" "${SERVER1}" "show_labels"
    if [ -z "$1" ]; then  # Namespace not provided
        APPEND="-A"
    else
        APPEND="-n $1"
    fi
    if [ "$3" ]; then
        APPEND="${APPEND} --show-labels"
    fi
    if [ -z "$2" ]; then
        execute "${KUBECTL} get pods ${APPEND}" "${SERVER1}" "SERVER1"
    else
        execute "${KUBECTL} get pods ${APPEND}" "$2"
    fi
}

install_helm () {
    execute "sudo snap install helm --classic" "${SERVER1}" "SERVER1"
    execute "sudo snap install helm --classic" "${SERVER2}" "SERVER2"
    execute "sudo snap install helm --classic" "${SERVER3}" "SERVER3"
    execute "sudo snap install helm --classic" "${AGENT1}" "AGENT1"
}

install_rancher () {
    if [ "${CERT_MANAGER_VERSION}" = "latest" ]; then
        APPEND_VERBAGE=""
    else
        APPEND_VERBAGE="--version ${CERT_MANAGER_VERSION}"
    fi
    execute "helm repo add rancher-latest https://releases.rancher.com/server-charts/latest && \
helm repo add jetstack https://charts.jetstack.io && \
helm repo update && \
kubectl create namespace cattle-system && \
kubectl create namespace cert-manager && \
kubectl apply --validate=false -f ${CERT_MANAGER_CRD} && 
kubectl config view --raw > ~/.kube/config && \
helm install cert-manager jetstack/cert-manager --namespace cert-manager ${APPEND_VERBAGE} && \
helm install rancher rancher-latest/rancher --namespace cattle-system \
--set hostname=${SERVER1}.nip.io --set global.cattle.psp.enabled=false \
--set rancherImageTag=${RANCHER_VERSION} --version=${RANCHER_VERSION}" "${SERVER1}" "SERVER1"
    get_pods_for_ns "${CERT_MANAGER_NS}" "${SERVER1}"
    execute "kubectl -n cattle-system rollout status deploy/rancher" "${SERVER1}" "SERVER1"
    echo "=============== RANCHER PASSWORD ===================="
    execute "kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}'" "${SERVER1}" "SERVER1"
    echo "====================================================="    
    execute "echo https://${SERVER1}.nip.io/dashboard/?setup=$(kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}')" "${SERVER1}" "SERVER1"
}

cmd () {
    # Create installer command string based on test options + server|agent etc
    # $1 commit|version $2 version_value|commit_value $3 Node-IP-address $4 server|agent $5 tar|rpm (Install Method)
    # Ex: cmd version v1.24.5+rke2r1 3.1.1.1 server tar
    CMD=""
    if echo "$1" | grep -q "commit"; then
        CMD="INSTALL_RKE2_COMMIT='$2'"
    else
        CMD="INSTALL_RKE2_VERSION='$2'"
    fi
    if [ "${CHANNEL}" ]; then
        CMD="${CMD} INSTALL_RKE2_CHANNEL=${CHANNEL}"
    else
        if echo "${OS_NAME}" | grep -q "rhel" || echo "${OS_NAME}" | grep -q "slemicro"; then
            if echo "$2" | grep -q "rc"; then  # RC Builds only in testing channel for rpms/rhel/slemicro.
                CMD="${CMD} INSTALL_RKE2_CHANNEL=testing"
            fi
            if echo "$1" | grep -q "commit" ; then  # Commits only in testing channel for rpms/rhel/slemicro.
                CMD="${CMD} INSTALL_RKE2_CHANNEL=testing"
            fi
        fi
    fi
    if echo "$4" | grep -q "server"; then
        CMD="${CMD} INSTALL_RKE2_TYPE='server'"
    else
        CMD="${CMD} INSTALL_RKE2_TYPE='agent'"
    fi
    if [ "$5" ]; then
        CMD="${CMD} INSTALL_RKE2_METHOD=$5"
    fi
    if [ "${CUSTOM_INSTALL_CMD}" = true ]; then
        CMD="${CMD} ${CUSTOM_INSTALL_STRING}"
    fi
}

install_rke2 () {
    # install rke2
    # $1 commit|version $2 version_value|commit_value $3 Node-IP-address $4 server|agent $5 tar|rpm (install method)
    # Ex: install_rke2 version v1.24.5+rke2r1 3.1.1.1 server tar  
    echo "INSTALL/UPGRADE RKE2 with options: $1 $2 $3 $4 $5" 
    cmd "$1" "$2" "$3" "$4" "$5"
    INSTALL_OUTPUT_FILE="${USER_HOME}/install_output"
    execute "curl -sfL https://get.rke2.io | sudo ${CMD} sh - 2>&1 | tee -a ${INSTALL_OUTPUT_FILE}" "$3" 
    FAIL_OUT=$(execute "cat ${INSTALL_OUTPUT_FILE} | grep 'The requested URL returned error: 404' &> /dev/null; echo \$?" "${SERVER1}" "SERVER1" "SKIP_LOG")
    FAIL_OUT2=$(execute "cat ${INSTALL_OUTPUT_FILE} | grep 'Failed' &> /dev/null; echo \$?" "${SERVER1}" "SERVER1" "SKIP_LOG") 
    if [ "${FAIL_OUT}" = 0 ] || [ "${FAIL_OUT2}" = 0 ]; then
        echo "====================================
    FATAL: RKE2 INSTALLER FAILED
===================================="
        # execute "cat ${INSTALL_OUTPUT_FILE}" "$3" 
        exit
    fi
    if [ "${SELINUX}" = true ]; then
        echo "NOTE the selinux rpm list for versions: "
        execute "rpm -qa | grep selinux" "$3"
    fi
    echo "=========== INSTALL DONE ============="
}

enable_now () {
    # Enable and Start rke2 service - server or agent
    # $1 IP address $2 server|agent
    echo "ENABLE and START Service for $1 $2"
    execute "sudo systemctl enable --now rke2-$2" "$1" "$2"
}

enable () {
    # Enable only - rke2 service - server or agent
    # $1 IP address $2 server|agent  
    echo "ENABLE Service for $1 $2"
    execute "sudo systemctl enable rke2-$2" "$1" "$2"
}

start () {
    # Start rke2 service - server or agent
    # $1 IP address $2 server|agent 
    echo "START Service for $1 $2"
    execute "timeout 2m sudo systemctl start rke2-$2" "$1" "$2"
}

stop () {
    # Stop rke2 service - server or agent    
    # $1 IP address $2 server|agent
    echo "STOP Service for $1 $2"
    execute "sudo systemctl stop rke2-$2" "$1" "$2"
}

restart () {
    # Restart rke2 service - server or agent  
    # $1 IP address $2 server|agent   
    echo "RESTART Service for $1 $2"
    execute "timeout 2m sudo systemctl restart rke2-$2" "$1" "$2"
}

stop_start () {
    # Stop, then Start rke2 service - server or agent
    # $1 IP address $2 server|agent   
    stop "$1" "$2"
    start "$1" "$2"
}

stop_start_all_nodes () {
    stop_start "${SERVER1}" "server"
    stop_start "${SERVER2}" "server"
    stop_start "${SERVER3}" "server"
    stop_start "${AGENT1}" "agent"    
}

get_nodes () {
    # Kubectl Get nodes
    # $1 IP address
    if [ -z "$1" ]; then
        execute "${KUBECTL} get nodes" "${SERVER1}" "SERVER1"
    else
        execute "${KUBECTL} get nodes" "$1"
    fi
}

get_pods () {
    # Kubectl Get pods -A
    # $1 IP address
    if [ -z "$1" ]; then
        execute "${KUBECTL} get pods -A" "${SERVER1}" "SERVER1"
    else
        execute "${KUBECTL} get pods -A" "$1"
    fi
}

get_system_upgrade_pods () {
    # Kubectl get pods in system upgrade namespace
    execute "${KUBECTL} get pods -n system-upgrade --show-labels" "${SERVER1}" 
}



create_custom_dir () {
    # $1 IP Address $2 Node Type $3 Directory to create $4 Permissions
    echo "CREATE $3 directory on $2: $1"
    if [ -z "$4" ]; then
        execute "sudo mkdir -p $3" "$1" "$2"
    else
        echo "SET directory permissions to: $4"
        execute "sudo mkdir -p -m $4 $3" "$1" "$2"
    fi     
}

create_config_directory () {
    # $1 IP Address $2 Node Type
    create_custom_dir "$1" "$2" "${CONFIG_DIR}"
}

create_server_directory () {
    # $1 IP Address $2 Node Type    
    create_custom_dir "$1" "$2" "${SERVER_DIR}"
}

create_manifest_directory () {
    # $1 IP Address $2 Node Type    
    create_custom_dir "$1" "$2" "${MANIFEST_DIR}"
}

create_log_directory () {
    # $1 IP Address $2 Node Type     
    create_custom_dir "$1" "$2" "${LOGS_DIR}" "700"
}

copy_over_config () {
    # Copy the config.yaml onto nodes
    # $1 Node IP address $2 Config_File $3 Node Type
    echo "STEP5: Node IP: $1: Copy config file: $2  Node Type: $3"
    scp -i "${PEM}" "$2" "${USER}"@"$1":"${USER_HOME}"/config.yaml
    execute "sudo cp ${USER_HOME}/config.yaml ${CONFIG_DIR}/config.yaml" "$1"
    echo "==============================================
    CONFIG YAML CONTENT: $3 
=============================================="
    execute "cat ${CONFIG_DIR}/config.yaml" "$1"
    echo "=============================================="

}

copy_over_files () {
    # Copy files onto nodes - sources & yaml files
    # $1 Node IP address $2 Config_File $3 Node Type
    copy "${SOURCE}" "${USER_HOME}/rke2.source" "$1"
    execute "grep -qxF 'source ${USER_HOME}/rke2.source' ~/.bashrc  || echo 'source ${USER_HOME}/rke2.source' >> ~/.bashrc" "$1" "$3"
    copy "${SOURCE2}" "${USER_HOME}/aliases.sh" "$1"
    execute "grep -qxF 'source ${USER_HOME}/aliases.sh' ~/.bashrc  || echo 'source ${USER_HOME}/aliases.sh' >> ~/.bashrc" "$1" "$3"    
    copy_over_config "$1" "$2" "$3"
    if [ "${CUSTOM_MANIFEST}" = true ]; then
        copy "${CUSTOM_MANIFEST_YAML}" "${CUSTOM_MANIFEST_DESTINATION_FILE_PATH}" "$1"
        execute "sudo mv ${CUSTOM_MANIFEST_DESTINATION_FILE_PATH} ${MANIFEST_DIR}" "$1"
    fi
}

copy_over_files_to_server_nodes () {
    # $1 Node_IP $2 Config_File $3 Node Type
    copy "${CLUSTERIP_YAML}" "${USER_HOME}/clusterip.yaml" "$1"
    if [ "${CUSTOM_WORKLOAD}" = true ]; then
        copy "${CUSTOM_WORKLOAD_YAML}" "${CUSTOM_WORKLOAD_DESTINATION_FILE_PATH}" "$1"
    fi
}

create_local_configs () {
    if [ "${SERVER1}" ]; then
        cp "${BASIC_CONFIG}" "${SERVER1_CONFIG}"
    fi
    if [ "${SERVER2}" ]; then
        cp "${BASIC_CONFIG}" "${SERVER2_CONFIG}"
    fi
    if [ "${SERVER3}" ]; then
        cp "${BASIC_CONFIG}" "${SERVER3_CONFIG}"
    fi
    if [ "${AGENT1}" ]; then
        cp "${BASIC_CONFIG}" "${AGENT1_CONFIG}"
    fi
    if [ "${AGENT2}" ]; then
        cp "${BASIC_CONFIG}" "${AGENT2_CONFIG}"
    fi
}

node_external_ip () {
    # $1 Node IP $2 Config File
    if [ "${NODE_EXTERNAL_IP}" = true ]; then
        echo "node-external-ip: $1" >> "$2"
    fi
}
write_kubeconfig_mode () {
    # $1 config_file
    echo "write-kubeconfig-mode: \"0644\"" >> "$1"
}

cni () {
    # $1 config_file
    if [ "${CNI}" = true ]; then
        echo "cni: ${CNI_TYPE}" >> "$1"
    fi
}

cis () {
    # $1 config_file
    if [ "${CIS}" = true ]; then
        echo "profile: \"${CIS_PROFILE}\"" >> "$1"
    fi
}

protect_kernel () {
    # $1 IP address $2 config_file $3 Node Type
    if [ "${PROTECT_KERNEL}" = true ]; then
        if [ "${PROTECT_KERNEL_SET_CONFIG}" = true ]; then
            echo "protect-kernel-defaults: true" >> "$2"
        fi
        echo "STEP 6a: $3 $1: User Add etcd; Copy kernel params and restart systemd-sysctl"        
        if echo "${OS_NAME}" | grep -q "slemicro"; then
            execute "sudo groupadd --system etcd && sudo useradd -s /sbin/nologin --system -g etcd etcd;
sudo printf 'on_oovm.panic_on_oom=0 \nvm.overcommit_memory=1 \nkernel.panic=10 \nkernel.panic_ps=1 \nkernel.panic_on_oops=1 \n' > ~/60-rke2-cis.conf;
sudo cp 60-rke2-cis.conf /etc/sysctl.d/;
printf 'cat-ing out the file located at /etc/sysctl.d/60-rke2-cis.conf then restarting systemd-sysctl';
sudo cat /etc/sysctl.d/60-rke2-cis.conf;
sudo systemctl restart systemd-sysctl" "$1" "$3"
        else
            execute 'sudo useradd -r -c "etcd user" -s /sbin/nologin -M etcd -U' "$1" "$3"
        fi
        # ssh -i "${PEM}" "${USER}"@"$1" 'sudo useradd -r -c "etcd user" -s /sbin/nologin -M etcd -U'
        # ssh -i "${PEM}" "${USER}"@"$1" 'sudo cp -f /usr/share/rke2/rke2-cis-sysctl.conf /etc/sysctl.d/60-rke2-cis.conf'
        # ssh -i "${PEM}" "${USER}"@"$1" 'sudo systemctl restart systemd-sysctl'        
    fi
}

protect_kernel_post_install () {
    # $1 IP address
    if [ "${PROTECT_KERNEL}" = true ]; then
        execute "sudo cp -f ${CIS_SYSCTL_FILE_PATH} /etc/sysctl.d/60-rke2-cis.conf" "$1"
        execute "sudo systemctl restart systemd-sysctl" "$1"
        # ssh -i "${PEM}" "${USER}"@"$1" "sudo cp -f ${CIS_SYSCTL_FILE_PATH} /etc/sysctl.d/60-rke2-cis.conf"
        # ssh -i "${PEM}" "${USER}"@"$1" 'sudo systemctl restart systemd-sysctl'
    fi        
}

selinux () {
    if [ "${SELINUX}" = true ]; then
        echo "selinux: true" >> "$1"
    fi
}

tls_san () {
    # $1 Node IP $2 Config_File
    if [ "${TLS_SAN}" = true ]; then
        echo "tls-san: \"$1.nip.io\"" >> "$2"
    fi
}

etcd () {
    # $1 SERVER1_CONFIG (etcd only); $2 SERVER2_CONFIG (control plane only)
    if [ "${ETCD}" = true ]; then
        # Server 1 Configs: 
        echo "disable-apiserver: true
disable-controller-manager: true
disable-scheduler: true" >> "$1"
        # Server 2 Configs: 
        echo "disable-etcd: true" >> "$2"
    fi
    if [ "${ETCD_SNAPSHOT_RETENTION}" = true ] || [ "${ETCD_SNAPSHOT_TEST}" = true ]; then
        # SERVER1 - etcd only; SERVER2: control plane only; SERVER3 both etcd and control plane
        # echo "etcd-snapshot-schedule-cron: 0 * */1 * *
        echo "etcd-snapshot-retention: ${ETCD_SNAPSHOT_RETENTION_VALUE}
etcd-snapshot-schedule-cron: \"* * * * *\"
etcd-s3: true
etcd-s3-access-key: ${S3_ACCESS_KEY}
etcd-s3-secret-key: ${S3_SECRET_KEY}
etcd-s3-bucket: ${S3_BUCKET}
etcd-s3-folder: ${S3_FOLDER_1}
etcd-s3-region: ${S3_REGION}
" >> "${SERVER1_CONFIG}"
        echo "etcd-snapshot-retention: ${ETCD_SNAPSHOT_RETENTION_VALUE}
etcd-snapshot-schedule-cron: \"* * * * *\"
etcd-s3: true
etcd-s3-access-key: ${S3_ACCESS_KEY}
etcd-s3-secret-key: ${S3_SECRET_KEY}
etcd-s3-bucket: ${S3_BUCKET}
etcd-s3-folder: ${S3_FOLDER_2}
etcd-s3-region: ${S3_REGION}
" >> "${SERVER2_CONFIG}"
        echo "etcd-snapshot-retention: ${ETCD_SNAPSHOT_RETENTION_VALUE}
etcd-snapshot-schedule-cron: \"* * * * *\"
etcd-s3: true
etcd-s3-access-key: ${S3_ACCESS_KEY}
etcd-s3-secret-key: ${S3_SECRET_KEY}
etcd-s3-bucket: ${S3_BUCKET}
etcd-s3-folder: ${S3_FOLDER_3}
etcd-s3-region: ${S3_REGION}
" >> "${SERVER3_CONFIG}"
    fi
}

node_name () {
    # $1 Node_Name $2 Server_Config_File
    if [ "${NODE_NAME}" = true ]; then
        echo "node-name: \"$1\"" >> "$2"
    fi
}

node_name_all_nodes () {
    if [ "${SERVER1}" ]; then
        NODE_NAME_SERVER1="${CLUSTER_NAME}-server1"
        node_name "${NODE_NAME_SERVER1}" "${SERVER1_CONFIG}"
    fi
    if [ "${SERVER2}" ]; then
        NODE_NAME_SERVER2="server2"    
        node_name "${NODE_NAME_SERVER2}" "${SERVER2_CONFIG}"
    fi
    if [ "${SERVER3}" ]; then
        NODE_NAME_SERVER3="server3"    
        node_name "${NODE_NAME_SERVER3}" "${SERVER3_CONFIG}"
    fi
    if [ "${AGENT1}" ]; then
        NODE_NAME_AGENT1="agent1"    
        node_name "${NODE_NAME_AGENT1}" "${AGENT1_CONFIG}"
    fi
    if [ "${AGENT2}" ]; then
        NODE_NAME_AGENT2="agent2"    
        node_name "${NODE_NAME_AGENT2}" "${AGENT2_CONFIG}"
    fi    
}

update_node_name () {
    if [ -z "$1" ]; then
        SUFFIX="${RANDOM}"
    else
        SUFFIX="$1"
    fi
    echo "==================================================
    Update Node Name with Suffix: ${SUFFIX}
=================================================="
    NEW_NODE_NAME_SERVER1="${NODE_NAME_SERVER1}-${SUFFIX}"
    NEW_NODE_NAME_SERVER2="${NODE_NAME_SERVER2}-${SUFFIX}"
    NEW_NODE_NAME_SERVER3="${NODE_NAME_SERVER3}-${SUFFIX}"
    NEW_NODE_NAME_AGENT1="${NODE_NAME_AGENT1}-${SUFFIX}"    
    execute "sudo sed -i -re 's/${NODE_NAME_SERVER1}/${NEW_NODE_NAME_SERVER1}/g' \"${CONFIG_DIR}/config.yaml\"" "${SERVER1}" "SERVER1"
    execute "sudo sed -i -re 's/${NODE_NAME_SERVER2}/${NEW_NODE_NAME_SERVER2}/g' \"${CONFIG_DIR}/config.yaml\"" "${SERVER2}" "SERVER2"
    execute "sudo sed -i -re 's/${NODE_NAME_SERVER3}/${NEW_NODE_NAME_SERVER3}/g' \"${CONFIG_DIR}/config.yaml\"" "${SERVER3}" "SERVER3"
    execute "sudo sed -i -re 's/${NODE_NAME_AGENT1}/${NEW_NODE_NAME_AGENT1}/g' \"${CONFIG_DIR}/config.yaml\"" "${AGENT1}" "AGENT1"

    execute "sudo sed -i -re 's/${NODE_NAME_SERVER1}/${NEW_NODE_NAME_SERVER1}/g' \"${USER_HOME}/config.yaml\"" "${SERVER1}" "SERVER1"
    execute "sudo sed -i -re 's/${NODE_NAME_SERVER2}/${NEW_NODE_NAME_SERVER2}/g' \"${USER_HOME}/config.yaml\"" "${SERVER2}" "SERVER2"
    execute "sudo sed -i -re 's/${NODE_NAME_SERVER3}/${NEW_NODE_NAME_SERVER3}/g' \"${USER_HOME}/config.yaml\"" "${SERVER3}" "SERVER3"
    execute "sudo sed -i -re 's/${NODE_NAME_AGENT1}/${NEW_NODE_NAME_AGENT1}/g' \"${USER_HOME}/config.yaml\"" "${AGENT1}" "AGENT1"  
    # stop_start "${SERVER2}" "server"
    # stop_start "${SERVER3}" "server"
    # stop_start "${AGENT1}" "agent"
    stop_start_all_nodes
    execute "cat ${CONFIG_DIR}/config.yaml" "${SERVER1}" "SERVER1"
}

delete_old_node_names () {
    # $1 Old_Name_Server1 $2 Old_Name_Server2 $3 Old_Name_Server3 $4 Old_Name_Agent1 $5 Update_Server_Config(Optional)
    echo "===================== DELETE OLD NODE NAMES AND RESTART K3S SERVICE =================================="
    # Delete server 2 old name from server 1 AND Restart server 2 k3s. 
    execute "${KUBECTL} delete node $2" "${SERVER1}" "SERVER1"
    stop_start "${SERVER2}" "server"    
    # Delete server 3 old name from server 1 AND Restart server 3 k3s. 
    execute "${KUBECTL} delete node $3" "${SERVER1}" "SERVER1"
    stop_start "${SERVER3}" "server"     
    # Delete agent 1 old name from server 1 AND Restart agent 1 k3s.
    execute "${KUBECTL} delete node $4" "${SERVER1}" "SERVER1"
    stop_start "${AGENT1}" "agent"     
    # Delete server 1 old name from server 2; Update the server detail for server 1 to point to server 2; Restart server 1 k3s. 
    execute "${KUBECTL} delete node $1" "${SERVER2}" "SERVER2"
    if [ "$5" = "update" ]; then
        echo "Updating server 1 config file: "
        execute "echo 'server: https://${SERVER2}:${PORT}' >> ${USER_HOME}/config.yaml" "${SERVER1}" "SERVER1"
        execute "sudo cp ${USER_HOME}/config.yaml ${CONFIG_DIR}/config.yaml" "${SERVER1}" "SERVER1"        
        execute "cat ${CONFIG_YAML_FILE_PATH}" "${SERVER1}" "SERVER1"
    fi
    stop_start "${SERVER1}" "server"
    get_nodes    
    echo "===================== DELETE DONE =================================="    
}

secrets_encrypt () {
    # $1 Config_File
    if [ "${SECRETS_ENCRYPT}" = true ]; then
        echo "secrets-encryption: true" >> "$1"
    fi
}

audit () {
    # $1 Node IP address $2 Config_File $3 Node Type   
    if [ "${AUDIT}" = true ]; then
        echo "kube-apiserver-arg:
- \"audit-log-maxage=30\"                
- \"audit-log-maxbackup=10\"
- \"audit-log-maxsize=100\"
- \"audit-log-format=json\"
- \"audit-policy-file=${CONFIG_DIR}/audit-policy.yaml\"
- \"audit-log-path=/var/log/kube-audit/anyname.log\"
" >> "$2"
    echo "STEP 5a: $3 $1: COPY over pod security yaml file"
    scp -i "${PEM}" "${AUDIT_YAML}" "${USER}"@"$1":"${USER_HOME}"/audit-policy.yaml
    execute "sudo cp ${USER_HOME}/audit-policy.yaml ${CONFIG_DIR}/audit-policy.yaml" "$1" 
    # ssh -i "${PEM}" "${USER}"@"$1" "sudo cp ${USER_HOME}/audit-policy.yaml ${CONFIG_DIR}/audit-policy.yaml"
    fi
}

pod_security () {
    # Node IP address $1 Config_File $2 Node Type $3
    echo "Pod Security step for Node: $1 Config file $2 Node Type: $3"
    if [ "${POD_SECURITY}" = true ]; then
        echo "pod-security-admission-config-file: ${CONFIG_DIR}/pod-security.yaml" >> "$2"
        echo "STEP 5a: $3 $1: COPY over pod security yaml file"
        scp -i "${PEM}" "${POD_SECURITY_YAML}" "${USER}"@"$1":"${USER_HOME}"/pod-security.yaml
        execute "sudo cp ${USER_HOME}/pod-security.yaml ${CONFIG_DIR}/pod-security.yaml" "$1" 
        # ssh -i "${PEM}" "${USER}"@"$1" "sudo cp ${USER_HOME}/pod-security.yaml ${CONFIG_DIR}/pod-security.yaml"
    fi    
}

edit_local_configs () {
    # Node IP address $1 Config_File $2 Node Type $3
    # etcd "${SERVER1_CONFIG}" ${SERVER2_CONFIG}
    echo "EDIT Local Configs: Node Type: $3 IP: $1 Config File: $2"
    node_external_ip "$1" "$2"
    cis "$2"
    protect_kernel "$1" "$2" "$3"
    selinux "$2"
}

edit_server_only_configs () {
    # Node IP address $1 Config_File $2 Node Type $3    
    echo "Edit config file: Node Type: $3 IP: $1  Config File: $2 "    
    tls_san "$1" "$2"    
    write_kubeconfig_mode "$2"
    secrets_encrypt "$2"
    audit "$1" "$2" "$3"
    pod_security "$1" "$2" "$3"
    cni "$2"     
}

edit_secondary_node_configs () {
    if [ "${SPLIT_INSTALL}" = false ]; then 
        # Split intall = true, server2 is a main server 
        # Split_Install = false, server2 is a secondary server / HA setup
        if [ -z "${PRIVATE_IP}" ]; then
            echo "server: https://${SERVER1}:${PORT}" >> "${SERVER2_CONFIG}"
        else
            echo "server: https://${PRIVATE_IP}:${PORT}" >> "${SERVER2_CONFIG}"
        fi            
    fi
    if [ "${SERVER3}" ]; then
        # HA Setup
        if [ -z "${PRIVATE_IP}" ]; then
            echo "server: https://${SERVER1}:${PORT}" >> "${SERVER3_CONFIG}"
        else
            echo "server: https://${PRIVATE_IP}:${PORT}" >> "${SERVER3_CONFIG}"
        fi
    fi
    if [ "${AGENT1}" ]; then
        # Join SERVER1 cluster setup
        echo "server: https://${SERVER1}:${PORT}" >> "${AGENT1_CONFIG}"
    fi
    if [ "${AGENT2}" ]; then
        # Join SERVER2 cluster setup
        echo "server: https://${SERVER2}:${PORT}" >> "${AGENT2_CONFIG}"
    fi
}

# Test Related Functions

apply_workload () {
    # $1 Node_IP_Address $2 Node_Type for logging $3 namespace to deploy the workload on, Ex: clusterip-2
    # We are using clusterip.yaml for this. 
    # Note: clusterip.yaml was already copied over in copy_over_files funtion
    if [ -z "$3" ]; then
        NAMESPACE="clusterip"
    else
        NAMESPACE="$3"
    fi
    if [ -z "$1" ]; then
        echo "Start a workload (clusterip.yaml) on SERVER1: ${SERVER1}"
        execute "${KUBECTL} apply -f ${USER_HOME}/clusterip.yaml -n ${NAMESPACE}" "${SERVER1}" "SERVER1"
        execute "${KUBECTL} apply -f ${WORKLOADS_GH}" "${SERVER1}" "SERVER1"
        execute "${KUBECTL} -n ${NAMESPACE} get pods" "${SERVER1}" "SERVER1"       
        if [ "${CUSTOM_WORKLOAD}" = true ]; then
            execute "${KUBECTL} apply -f ${CUSTOM_WORKLOAD_DESTINATION_FILE_PATH}" "${SERVER1}" "SERVER1" 
        fi
    else
        echo "Start a workload (clusterip.yaml) on $2: $1"
        execute "${KUBECTL} apply -f ${USER_HOME}/clusterip.yaml -n ${NAMESPACE}" "$1" "$2"
        execute "${KUBECTL} apply -f ${WORKLOADS_GH}" "$1" "$2"        
        execute "${KUBECTL} -n ${NAMESPACE} get pods" "$1" "$2"
        if [ "${CUSTOM_WORKLOAD}" = true ]; then
            execute "${KUBECTL} apply -f ${CUSTOM_WORKLOAD_DESTINATION_FILE_PATH}" "$1" "$2"
        fi
    fi

}

update_server1_config () {
    echo "Update the config.yaml of server1 ${SERVER1} to point to server3 ${SERVER3}"
    echo "server: https://${SERVER3}:${PORT}" >> "${SERVER1_CONFIG}"
    echo "SERVER1 ${SERVER1}: Copy over ${SERVER1_CONFIG}"
    scp -i "${PEM}" "${SERVER1_CONFIG}" "${USER}"@"${SERVER1}":"${USER_HOME}"/config.yaml
    execute "sudo cp ${USER_HOME}/config.yaml ${CONFIG_DIR}/config.yaml" "${SERVER1}" "SERVER1"
    # ssh -i "${PEM}" "${USER}"@"${SERVER1}" "sudo cp ${USER_HOME}/config.yaml ${CONFIG_DIR}/config.yaml"
}

get_node_names () {
    echo "Getting hostnames for nodes"
    if [ "${SERVER1}" ]; then
        HOSTNAME1=$(ssh -i "${PEM}" "${USER}"@"${SERVER1}" "hostname")
        echo "SERVER1 ${SERVER1} hostname is ${HOSTNAME1}"
    fi
    if [ "${SERVER2}" ]; then
        HOSTNAME2=$(ssh -i "${PEM}" "${USER}"@"${SERVER2}" "hostname")
        echo "SERVER2 ${SERVER2} hostname is ${HOSTNAME2}"
    fi
    if [ "${SERVER3}" ]; then
        HOSTNAME3=$(ssh -i "${PEM}" "${USER}"@"${SERVER3}" "hostname")
        echo "SERVER3 ${SERVER3} hostname is ${HOSTNAME3}"
    fi
    if [ "${AGENT1}" ]; then
        HOSTNAME_AGENT1=$(ssh -i "${PEM}" "${USER}"@"${AGENT1}" "hostname")
        echo "AGENT1 ${AGENT1} hostname is ${HOSTNAME_AGENT1}"
    fi
    if [ "${AGENT2}" ]; then
        HOSTNAME_AGENT2=$(ssh -i "${PEM}" "${USER}"@"${AGENT2}" "hostname")
        echo "AGENT2 ${AGENT2} hostname is ${HOSTNAME_AGENT2}"
    fi
}

delete_node () {
    # $1 hostname of node to delete
    # $2 Node Type of ($1 node_type_of_hostname)    
    # $3 IP address of node to run kubectl command on via ssh
    # $4 Node Type of ssh cmd node ($3 node_type_of_ssh_node)
    # Ex: delete_node $hostname node_type_of_hostname $ssh_ip_address node_type_of_ssh_node
    echo "DELETE NODE: $1 hostname of $2 ; execute cmd on node $3 which is: $4"
    execute "${KUBECTL} delete node $1" "$3"
}

reinstall_node () {
    # $1 Node IP address $2 Config_File $3 Node Type 
    # 4 through 7 arguments are for install_rke2 options
    # Ex: reinstall_node $ip $config_file $node_type version|commit ${VERSION}|${COMMIT} server|agent tar|rpm 
    # reinstall_node $1 $2 $3 $4 $5 $6 $7
    # $8 "SKIP" restart of service
    # Ex: reinstall_node $1 $2 $3 $4 $5 $6 $7 "SKIP"
    echo "Uninstall $1 $3"
    uninstall "$1" "$3"
    if [ -z "$8" ]; then    
        echo "Create Directory ${CONFIG_DIR} on $1 $3"
        create_config_directory "$1" "$3"
        if [ "$3" = "SERVER1" ] || [ "$3" = "server1" ]; then
            echo "UPDATE SERVER1 config"
            update_server1_config
        else
            echo "copy_over_config $1 $2 $3"
            copy_over_config "$1" "$2" "$3"
        fi
    else
        echo "SKIP: Create Directory ${CONFIG_DIR}"
    fi
    echo "Installing RKE2: $4 $5 $1 $6 $7"
    install_rke2 "$4" "$5" "$1" "$6" "$7"
    if [ -z "$8" ]; then
        echo "Stop Start RKE2 $1 $6"
        stop_start "$1" "$6"
    else
        echo "SKIP: Stop/Start of RKE2 Service"
    fi
}

certificate_rotate () {
    # $1 IP Address $2 Node_Type
    echo "Rotate Certificate for $2: $1"
    execute "sudo rke2 certificate rotate &> cert_rotate_output" "$1"
}

display_identical_files () {
    # $1 IP address $2 
    echo "Get identical files for: $2: $1"
    TLS_DIR=$(ssh -i "${PEM}" "${USER}"@"$1" "sudo ls -lt ${SERVER_DIR}/ | grep tls | awk {'print \$9'} | sed -n '2 p'")
    echo "TLS_DIR : ${TLS_DIR}"
    execute "sudo diff -sr ${SERVER_DIR}/tls/ ${SERVER_DIR}/${TLS_DIR}/ | grep -i identical | awk '{print \$2}' | xargs basename -a | awk 'BEGIN{print \"Identical Files:  \"}; {print \$1}'" "$1"   
}

hexdump () {
    # $1 IP address
    echo "SERVER1 ${SERVER1} Hexdump: "
    execute "sudo ETCDCTL_API=3 ${ETCDCTL} --cert ${SERVER_DIR}/tls/etcd/server-client.crt --key ${SERVER_DIR}/tls/etcd/server-client.key --endpoints https://127.0.0.1:2379 --cacert ${SERVER_DIR}/tls/etcd/server-ca.crt get /registry/secrets/default/secret1 | hexdump -C" "${SERVER1}" "SERVER1"
}

create_secret () {    
    # $1 Ip address $2 node type
    echo "Create Secret: SERVER1 ${SERVER1} "
    execute "${KUBECTL} create secret generic secret1 -n default --from-literal=mykey=mydata" "${SERVER1}" "SERVER1"
}

secret_encrypt_status () {   
    # $1 IP address $2 node type
    echo "SECRET_ENCRYPT: SERVER2 ${SERVER2} Get Status"
    execute "sudo rke2 secrets-encrypt status &> secrets-encrypt-status" "${SERVER2}" "SERVER2"
}
secret_encrypt_prepare () {    
    # $1 IP address $2 node type
    echo "SECRET_ENCRYPT: SERVER2 ${SERVER2} Run Prepare"
    execute "sudo rke2 secrets-encrypt prepare" "${SERVER2}" "SERVER2"
}
secret_encrypt_rotate () {  
    # $1 IP address $2 node type
    echo "SECRET_ENCRYPT: SERVER2 ${SERVER2} Run rotate"
    execute "sudo rke2 secrets-encrypt rotate" "${SERVER2}"
    echo "Sleep for 5 seconds"; sleep 5
}
secret_encrypt_reencrypt () {  
    # $1 IP address $2 node type
    echo "SECRET_ENCRYPT: SERVER2 ${SERVER2} Run reencrypt"
    execute "sudo rke2 secrets-encrypt reencrypt" "${SERVER2}" "SERVER2"
    echo "Sleep for 15 seconds"; sleep 15
}

get_node_count () {
    NODE_COUNT=$(ssh -i "${PEM}" "${USER}"@"${SERVER1}" "${KUBECTL} get nodes | grep -v NAME | wc -l")
    echo "Node Count Value was ${NODE_COUNT}"
}

restart_all_nodes () {
    echo "Restart rke2 server/agent services on all nodes"
    get_node_count
    stop_start "${SERVER1}" "server"
    echo "Sleep for 5 seconds"; sleep 5
    stop_start "${SERVER2}" "server"
    echo "Sleep for 5 seconds"; sleep 5
    if [ "${NODE_COUNT}" = "4" ]; then
        echo "Node Count: ${NODE_COUNT} - so attempting to restart server3 ${SERVER3} as well"
        stop_start "${SERVER3}" "server"  # We deleted the server3 from cluster in secrets encrypt test
    fi
    stop_start "${AGENT1}" "agent"
}

stop_all_nodes () {
    stop "${SERVER1}" "server"
    stop "${SERVER2}" "server"
    stop "${SERVER3}" "server"
    stop "${AGENT1}" "agent"        
}

apply_suc_crd () {
    execute "${KUBECTL} apply -f ${SYSTEM_UPGRADE_CRD}" "${SERVER1}" "SERVER1"
    if [ "${CIS}" = true ] && [ "${POD_SECURITY}" = false ]; then
        scp -i "${PEM}" "${SU_NS_PRIVILEGE_YAML}" "${USER}"@"${SERVER1}":/home/ec2-user/su_ns_privilege.yaml
        execute "${KUBECTL} apply -f /home/ec2-user/su_ns_privilege.yaml" "${SERVER1}" "SERVER1" 
    fi
}

create_auto_upgrade_plan () {
    cp "${AUTO_UPGRADE_PLAN_YAML}" "${AUTO_UPGRADE_PLAN_YAML_FILE}"
    sed -i -re "s/upgrade_version/${VERSION2}/g" "${AUTO_UPGRADE_PLAN_YAML_FILE}"
    scp -i "${PEM}" "${AUTO_UPGRADE_PLAN_YAML_FILE}" "${USER}"@"${SERVER1}":"${USER_HOME}"/plan.yaml
}


apply_auto_upgrade_plan () {
    create_auto_upgrade_plan
    execute "${KUBECTL} apply -f ${USER_HOME}/plan.yaml; ${KUBECTL} get plans -n system-upgrade > plans; ${KUBECTL} get jobs -n system-upgrade > jobs" "${SERVER1}" "SERVER1"
}

get_nodes_pods_upgrade_status () {
    echo "Sleep for 60 seconds"; sleep 60
    get_nodes
    get_pods
    get_system_upgrade_pods
}

get_rke2_status () {
    # $1 Node_IP $2 "SKIP_SLEEP" string. If passed, sleep will be skipped. 
    # No input to method call, we will first sleep for 60 seconds. 
    if [ -z "$2" ]; then
        echo "Sleep for 60 seconds before get rke2 status"; sleep 60
    else
        if echo "$2" | grep -q "SKIP"; then
            echo "SKIP sleep before get rke2 status"
        else
            echo "Sleep for $2 seconds before get rke2 status"; sleep "$2"
        fi 
    fi
    get_nodes "$1"
    get_pods "$1"
}

compare_list_snapshots_values () {
    if [ "${SPLIT_INSTALL}" = false ]; then
        LS_WC=$(execute "sudo ls -lrt /var/lib/rancher/${PRDT}/server/db/snapshots | grep -v total | wc -l" "${SERVER1}" "SERVER1" "SKIP")
        LS_WC_2=$(execute "sudo ls -lrt /var/lib/rancher/${PRDT}/server/db/snapshots | grep -v total | wc -l" "${SERVER2}" "SERVER2" "SKIP")    
        LS_WC_3=$(execute "sudo ls -lrt /var/lib/rancher/${PRDT}/server/db/snapshots | grep -v total | wc -l" "${SERVER3}" "SERVER3" "SKIP")  

        ETCD_LS_WC=$(execute "sudo ${PRDT} etcd-snapshot list 2>/dev/null | grep -v Name |  wc -l" "${SERVER1}" "SERVER1" "SKIP")
        ETCD_LS_WC_2=$(execute "sudo ${PRDT} etcd-snapshot list 2>/dev/null | grep -v Name |  wc -l" "${SERVER2}" "SERVER2" "SKIP")
        ETCD_LS_WC_3=$(execute "sudo ${PRDT} etcd-snapshot list 2>/dev/null | grep -v Name |  wc -l" "${SERVER3}" "SERVER3" "SKIP")

        K_ETCDFILE_WC=$(execute "${KUBECTL} get etcdsnapshotfile | grep -v NAME |  wc -l" "${SERVER1}" "SERVER1" "SKIP")
        K_ETCDFILE_WC_2=$(execute "${KUBECTL} get etcdsnapshotfile | grep -v NAME |  wc -l" "${SERVER2}" "SERVER2" "SKIP")
        K_ETCDFILE_WC_3=$(execute "${KUBECTL} get etcdsnapshotfile | grep -v NAME |  wc -l" "${SERVER3}" "SERVER3" "SKIP")

        CM_DATA=$(execute "${KUBECTL} get cm -n kube-system ${PRDT}-etcd-snapshots | grep ${PRDT} | awk '{print \$2}'" "${SERVER1}" "SERVER1" "SKIP")
        CM_DATA_2=$(execute "${KUBECTL} get cm -n kube-system ${PRDT}-etcd-snapshots | grep ${PRDT} | awk '{print \$2}'" "${SERVER2}" "SERVER2" "SKIP")
        CM_DATA_3=$(execute "${KUBECTL} get cm -n kube-system ${PRDT}-etcd-snapshots | grep ${PRDT} | awk '{print \$2}'" "${SERVER3}" "SERVER3" "SKIP")  

        echo "
        SERVER1: ls folder = ${LS_WC}; ${PRDT} snapshot list = ${ETCD_LS_WC}; 
        SERVER2: ls folder = ${LS_WC_2}; ${PRDT} snapshot list = ${ETCD_LS_WC_2}; 
        SERVER3: ls folder = ${LS_WC_3}; ${PRDT} snapshot list = ${ETCD_LS_WC_3};         
        SERVER1: get etcdsnapshotfile = ${K_ETCDFILE_WC}; configmap data = ${CM_DATA}
        SERVER2: get etcdsnapshotfile = ${K_ETCDFILE_WC_2}; configmap data = ${CM_DATA_2}
        SERVER3: get etcdsnapshotfile = ${K_ETCDFILE_WC_3}; configmap data = ${CM_DATA_3}
    "
    fi
}

list_snapshots () {
    # $1 Node_IP $2 Node_Type
    if [ -z "$1" ]; then
        NODE_IP="${SERVER1}"
        NODE_TYPE="SERVER1"
    else
        NODE_IP="$1"
        NODE_TYPE="$2"
    fi

    echo "==========LIST SNAPSHOTS OUTPUTS FOR SETUP: ${NODE_TYPE}: ${NODE_IP}===============================================" 
    execute "sudo ls -lrt /var/lib/rancher/${PRDT}/server/db/snapshots" "${NODE_IP}" "${NODE_TYPE}"
    execute "sudo ls -lrt /var/lib/rancher/${PRDT}/server/db/snapshots | grep -v total | wc -l" "${NODE_IP}" "${NODE_TYPE}"

    execute "sudo ${PRDT} etcd-snapshot list 2>/dev/null" "${NODE_IP}" "${NODE_TYPE}"
    execute "sudo ${PRDT} etcd-snapshot list 2>/dev/null | grep -v Name |  wc -l" "${NODE_IP}" "${NODE_TYPE}"

    execute "${KUBECTL} get etcdsnapshotfile" "${NODE_IP}" "${NODE_TYPE}"
    execute "${KUBECTL} get etcdsnapshotfile | grep -v NAME | wc -l" "${NODE_IP}" "${NODE_TYPE}"

    # execute "${KUBECTL} describe cm ${PRDT}-etcd-snapshots -n kube-system" "${NODE_IP}" "${NODE_TYPE}"
    execute "${KUBECTL} get cm -n kube-system ${PRDT}-etcd-snapshots" "${NODE_IP}" "${NODE_TYPE}"
    execute "${KUBECTL} get cm -n kube-system ${PRDT}-etcd-snapshots | grep ${PRDT} | awk '{print \$2}'" "${NODE_IP}" "${NODE_TYPE}"
    echo "===================================LIST SNAPSHOTS OUTPUTS DONE==========================================="
    compare_list_snapshots_values 
}

take_snapshot () {
    # $1 snapshot_type: local | s3
    echo "====================
    TAKE SNAPSHOT
===================="
    print_ssh_info "${SERVER1}"
    if [ -z "$1" ]; then
        SNAPSHOT_TYPE="s3"
    else
        SNAPSHOT_TYPE="$1"
    fi
    if [ -z "${S3_BUCKET}" ] || [ -z "${S3_ACCESS_KEY}" ] || [ -z "${S3_SECRET_KEY}" ]; then
        echo "FATAL: Please set environment variables: S3_BUCKET, S3_ACCESS_KEY, S3_SECRET_KEY. Exiting."
        exit
    fi
    echo "Take Snapshot in folder ${S3_FOLDER} for S3 Bucket: ${S3_BUCKET}"
    OUT_FILE="${USER_HOME}/snapshot_output-${RANDOM}"

    ETCD_S3_IN_CONFIG_YAML=$(execute "grep etcd-s3 ${CONFIG_DIR}/config.yaml; echo \$?" "${SERVER1}" "SERVER1" "SKIP_LOG")
    echo "ETCD_S3_IN_CONFIG_YAML: ${ETCD_S3_IN_CONFIG_YAML}"
    if [ "${ETCD_S3_IN_CONFIG_YAML}" = 1 ] && [ "${SNAPSHOT_TYPE}" = "s3" ]; then
        execute "sudo ${PRDT} etcd-snapshot save --s3 --s3-bucket=${S3_BUCKET} --s3-folder=${S3_FOLDER} --s3-region=${S3_REGION} --s3-access-key=${S3_ACCESS_KEY} --s3-secret-key=\"${S3_SECRET_KEY}\" 2>&1 | tee -a ${OUT_FILE}"
    else
        execute "sudo ${PRDT} etcd-snapshot save 2>&1 | tee -a ${OUT_FILE}"
    fi
    # if [ "${ETCD_SNAPSHOT_RETENTION}" = true  ] || [ "${ETCD_SNAPSHOT_TEST}" = true  ]; then
    #     execute "sudo ${PRDT} etcd-snapshot save &> ${OUT_FILE}"
    # else
    #     execute "sudo ${PRDT} etcd-snapshot save --s3 --s3-bucket=${S3_BUCKET} --s3-folder=${S3_FOLDER} --s3-region=${S3_REGION} --s3-access-key=${S3_ACCESS_KEY} --s3-secret-key=\"${S3_SECRET_KEY}\" &> ${OUT_FILE}"
    # fi
    execute "cat ${OUT_FILE}"
    SNAPSHOT_FILENAME=$(execute "grep \"S3 upload complete for\"  \"${OUT_FILE}\" | awk '{ print \$7}' | sed 's/\"//g' | head -1" "${SERVER1}" "SERVER1" "SKIP_LOG")
    echo "Etcd Snapshot Path: ${SNAPSHOT_FILENAME}"
    if [ "${SNAPSHOT_FILENAME}" = "" ]; then
        echo "FATAL: TAKING SNAPSHOT FAILED"
        exit
    fi
}

restore_cluster_from_snapshot () {
    # $1 snapshot_type: local | s3
    if [ -z "$1" ]; then
        SNAPSHOT_TYPE="s3"
    else
        SNAPSHOT_TYPE="$1"
    fi    
    echo "==========================================================================
    RESTORE CLUSTER FROM SNAPSHOT: ${SNAPSHOT_FILENAME}
=========================================================================="    
    print_ssh_info "${SERVER1}"
    if [ -z "${SNAPSHOT_FILENAME}" ]; then
        take_snapshot "${SNAPSHOT_TYPE}"
    fi
    if [ -z "${TOKEN}" ]; then  # We already checked for S3 vars during take_snapshot stage
        echo "FATAL: Please set environment variable: TOKEN. Exiting."
        exit
    fi

    SNAPSHOT_FILENAME=$(execute "sudo ${PRDT} etcd-snapshot list 2> /dev/null | grep 'on-demand' | awk '{print \$1}' | head -1" "${SERVER1}" "SERVER1" "SKIP_LOG")
    echo "Going to use snapshot name: ${SNAPSHOT_FILENAME} for restore operation"

    OUT_FILE="${USER_HOME}/cluster_reset_output-${RANDOM}"

    ETCD_S3_IN_CONFIG_YAML=$(execute "grep etcd-s3 ${CONFIG_DIR}/config.yaml; echo \$?" "${SERVER1}" "SERVER1" "SKIP_LOG")
    echo "ETCD_S3_IN_CONFIG_YAML: ${ETCD_S3_IN_CONFIG_YAML}"

    if [ "${SNAPSHOT_TYPE}" = "s3" ]; then
        if [ "${ETCD_S3_IN_CONFIG_YAML}" = 1 ]; then
            # s3 snapshot restore when s3 details NOT in config.yaml
            echo "s3 snapshot restore when s3 details NOT in config.yaml"
            execute "sudo ${PRDT} server --cluster-reset --etcd-s3 \
--cluster-reset-restore-path=${SNAPSHOT_FILENAME} \
--etcd-s3-bucket=${S3_BUCKET} --etcd-s3-folder=${S3_FOLDER} --etcd-s3-region=${S3_REGION} \
--etcd-s3-access-key=${S3_ACCESS_KEY} --etcd-s3-secret-key=\"${S3_SECRET_KEY}\" \
--token=${TOKEN} --debug 2>&1 | tee -a ${OUT_FILE}"
        else
            # s3 snapshot restore, when s3 details EXIST in config.yaml
            echo "s3 snapshot restore, when s3 details EXIST in config.yaml"
            execute "sudo ${PRDT} server --cluster-reset \
--cluster-reset-restore-path=${SNAPSHOT_FILENAME} \
--token=${TOKEN} --debug 2>&1 | tee -a ${OUT_FILE}"
        fi
    else
        # Local snapshot path restore
        echo "Local snapshot path restore"
        execute "sudo ${PRDT} server --cluster-reset \
--cluster-reset-restore-path=${SNAPSHOTS_DIR}/${SNAPSHOT_FILENAME} \
--token=${TOKEN} --debug 2>&1 | tee -a ${OUT_FILE}"
    fi
}

restore_cluster_from_local_snapshot () {
    echo "==========================================================================
    RESTORE CLUSTER FROM LOCAL SNAPSHOT: ${SNAPSHOT_FILENAME}
=========================================================================="
    print_ssh_info "${SERVER1}"
    if [ -z "${SNAPSHOT_FILENAME}" ]; then
        take_snapshot "local"
    fi
    if [ -z "${TOKEN}" ]; then  # We already checked for S3 vars during take_snapshot stage
        echo "FATAL: Please set environment variable: TOKEN. Exiting."
        exit
    fi
    SNAPSHOT_FILENAME=$(execute "sudo ${PRDT} etcd-snapshot list 2> /dev/null | grep 'on-demand' | awk '{print \$1}' | head -1" "${SERVER1}" "SERVER1" "SKIP_LOG")
    echo "Going to use snapshot name: ${SNAPSHOT_FILENAME} for restore operation"    
    OUT_FILE="${USER_HOME}/cluster_reset_from_local_snapshot"    
    execute "sudo ${PRDT} server --cluster-reset \
  --cluster-reset-restore-path=${SNAPSHOTS_DIR}/${SNAPSHOT_FILENAME} \
  --token=${TOKEN} 2>&1 | tee -a ${OUT_FILE}"
}

restore_cluster_from_given_path () {
    # $1 cluster_reset_restore_s3_path_name
    echo "==========================================================================
    RESTORE CLUSTER FROM SNAPSHOT: $1
=========================================================================="
    print_ssh_info "${SERVER1}"   
    if [ -z "${TOKEN}" ]; then  # We already checked for S3 vars during take_snapshot stage
        echo "FATAL: Please set environment variable: TOKEN. Exiting."
        exit
    fi
    OUT_FILE="${USER_HOME}/cluster_reset_output_using_path"    
    execute "sudo ${PRDT} server --cluster-reset --etcd-s3 \
  --cluster-reset-restore-path=$1 \
  --etcd-s3-bucket=${S3_BUCKET} --etcd-s3-folder=${PRDT}snap --etcd-s3-region=us-east-2 \
  --etcd-s3-access-key=${S3_ACCESS_KEY} --etcd-s3-secret-key=\"${S3_SECRET_KEY}\" \
  --token=${TOKEN} &> ${OUT_FILE}"
}

create_directory_all () {
    echo "CREATE ${CONFIG_DIR} directory structure"    
    if [ "${SERVER1}" ]; then
        create_config_directory "${SERVER1}" "SERVER1"
        # if [ "${RESTRICTED}" = true ]; then
        #     create_server_directory "${SERVER1}" "SERVER1"
        # fi
        if [ "${CUSTOM_MANIFEST}" = true ]; then
            create_manifest_directory "${SERVER1}" "SERVER1"
        fi        
    fi
    if [ "${SERVER2}" ]; then
        create_config_directory "${SERVER2}" "SERVER2"
        # if [ "${RESTRICTED}" = true ]; then
        #     create_server_directory "${SERVER2}" "SERVER2"
        # fi
        if [ "${CUSTOM_MANIFEST}" = true ]; then
            create_manifest_directory "${SERVER2}" "SERVER2"
        fi         
    fi
    if [ "${SERVER3}" ]; then
        create_config_directory "${SERVER3}" "SERVER3"
        # if [ "${RESTRICTED}" = true ]; then
        #     create_server_directory "${SERVER3}" "SERVER3"
        # fi
        if [ "${CUSTOM_MANIFEST}" = true ]; then
            create_manifest_directory "${SERVER3}" "SERVER3"
        fi             
    fi
    if [ "${AGENT1}" ]; then
        create_config_directory "${AGENT1}" "AGENT1"
        if [ "${CUSTOM_MANIFEST}" = true ]; then
            create_manifest_directory "${AGENT1}" "AGENT1"
        fi         
    fi
    if [ "${AGENT2}" ]; then
        create_config_directory "${AGENT2}" "AGENT1"
        if [ "${CUSTOM_MANIFEST}" = true ]; then
            create_manifest_directory "${AGENT2}" "AGENT1"
        fi         
    fi                
}

cleanup_configs () {
    if [ "${REINSTALL}" = true ]; then
        echo "STAGE: Cleanup Pre-Existing Config files on local system"    
        rm -rf "${SERVER1_CONFIG}"
        rm -rf "${SERVER2_CONFIG}"
        rm -rf "${SERVER3_CONFIG}"
        rm -rf "${AGENT1_CONFIG}"
        rm -rf "${AGENT2_CONFIG}"
    fi
}


update_push_configs () {  # Common configs for both server and agents
    # $1 Node_IP $2 Config_File $3 Node_Type    
    edit_local_configs "$1" "$2" "$3"
    copy_over_files "$1" "$2" "$3"
}

update_push_server_configs () {
    # $1 Node_IP $2 Config_File $3 Node_Type
    edit_server_only_configs "$1" "$2" "$3"
    update_push_configs "$1" "$2" "$3"
    copy_over_files_to_server_nodes "$1" "$2" "$3"
}


uninstall_all_nodes () {
    cleanup_configs
    echo "==============================================
        STAGE: UNINSTALL ALL NODES
=============================================="
    if [ "${SERVER1}" ]; then
        uninstall "${SERVER1}" "SERVER1"
    fi
    if [ "${SERVER2}" ]; then
        uninstall "${SERVER2}" "SERVER2"           
    fi
    if [ "${SERVER3}" ]; then
        uninstall "${SERVER3}" "SERVER3"           
    fi
    if [ "${AGENT1}" ]; then
        uninstall "${AGENT1}" "AGENT1"           
    fi
    if [ "${AGENT2}" ]; then
        uninstall "${AGENT2}" "AGENT2"           
    fi
}

install_iptables_all_nodes () {
    echo "==================================================
STAGE: INSTALL IPTABLES ON ALL NODES - RHEL ONLY
=================================================="
    if [ "${SERVER1}" ]; then
        install_iptables "${SERVER1}" "SERVER1"
    fi
    if [ "${SERVER2}" ]; then
        install_iptables "${SERVER2}" "SERVER2"           
    fi
    if [ "${SERVER3}" ]; then
        install_iptables "${SERVER3}" "SERVER3"           
    fi
    if [ "${AGENT1}" ]; then
        install_iptables "${AGENT1}" "AGENT1"           
    fi
    if [ "${AGENT2}" ]; then
        install_iptables "${AGENT2}" "AGENT2"           
    fi
}

create_n_copy_configs () {
    echo "==============================================
     STAGE: CREATE EDIT AND COPY OVER CONFIGS
=============================================="
    create_local_configs
    create_directory_all
    edit_secondary_node_configs
    node_name_all_nodes
    if [ "${SERVER1}" ]; then
        etcd "${SERVER1_CONFIG}" "${SERVER2_CONFIG}"
        update_push_server_configs "${SERVER1}" "${SERVER1_CONFIG}" "SERVER1"
    fi
    if [ "${SERVER2}" ]; then
        update_push_server_configs "${SERVER2}" "${SERVER2_CONFIG}" "SERVER2"
    fi
    if [ "${SERVER3}" ]; then
        update_push_server_configs "${SERVER3}" "${SERVER3_CONFIG}" "SERVER3"    
    fi
    if [ "${AGENT1}" ]; then
        update_push_configs "${AGENT1}" "${AGENT1_CONFIG}" "AGENT1"
    fi
    if [ "${AGENT2}" ]; then
        update_push_configs "${AGENT2}" "${AGENT2_CONFIG}" "AGENT2"
    fi
}

rke2_version () {
    # $1 IP address $2 Node Type: SERVER1|AGENT1
    echo "RKE2 Version on $2: $1"
    execute 'rke2 -v' "$1" "$2"
}

reboot_node () {
    # $1 Node_IP $2 Node_Type
    if [ "${SELINUX}" = true ] && echo "${OS_NAME}" | grep -q "slemicro" ; then
        execute "sudo reboot" "$1" "$2"
        echo "Sleep for 60 seconds after reboot"; sleep 60
    fi
}

install_steps () {
    # $1 commit|version $2 commit_id|version_number $3 Node_IP $4 Node_Type    
    echo "=====================================================
    INSTALL $1: $2 on $4 $3
    ssh -i ${PEM} ${USER}@$3
====================================================="
    if echo "$4" | grep -q "SERVER"; then
        TYPE="server"
    else
        TYPE="agent"
    fi
    install_rke2 "$1" "$2" "$3" "${TYPE}" "${INSTALL_METHOD}"
    protect_kernel_post_install "$3"
    reboot_node "$3" "$4"
    enable_now "$3" "${TYPE}"
    permissions_update "$3" "$4"
    rke2_version "$3" "$4"
    get_rke2_status "$3" "30"
}

update_secondary_server_ip () {
    if [ "${PRIVATE_IP}" ]; then
        execute "sudo sed -i -re 's/${PRIVATE_IP}/${SERVER1}/g' \"${CONFIG_DIR}/config.yaml\"" "${SERVER2}" "SERVER2"
        execute "sudo sed -i -re 's/${PRIVATE_IP}/${SERVER1}/g' \"${CONFIG_DIR}/config.yaml\"" "${SERVER3}" "SERVER3"
        stop_start "${SERVER2}" "server"
        stop_start "${SERVER3}" "server"
    fi  
}



install_rke2_on_all_nodes () {
    # Ex: install_rke2_on_all_nodes commit commit_id 
    # $1 commit|version $2 commit_id|version_number
    if [ "${SERVER1}" ]; then
        install_steps "$1" "$2" "${SERVER1}" "SERVER1"
    fi
    if [ "${SERVER2}" ]; then
        install_steps "$1" "$2" "${SERVER2}" "SERVER2"

    fi
    if [ "${SERVER3}" ]; then
        install_steps "$1" "$2" "${SERVER3}" "SERVER3"
    fi
    if [ "${AGENT1}" ]; then
        install_steps "$1" "$2" "${AGENT1}" "AGENT1"    
    fi
    update_secondary_server_ip
    get_rke2_status
}

install_rke2_on_setup1 () {
    # SERVER1 and AGENT1 will be installed here: 
    # Ex: install_rke2_on_setup1 commit commit_id 
    # $1 commit|version $2 commit_id|version_number 
    if [ "${SERVER1}" ]; then
        install_steps "$1" "$2" "${SERVER1}" "SERVER1"
    fi
    if [ "${AGENT1}" ]; then
        install_steps "$1" "$2" "${AGENT1}" "AGENT1"
    fi      
}

install_rke2_on_setup2 () {
    # SERVER2 and AGENT2 will be installed here: 
    # Ex: install_rke2_on_setup2 commit commit_id 
    # $1 commit|version $2 commit_id|version_number 
    if [ "${SERVER2}" ]; then
        install_steps "$1" "$2" "${SERVER2}" "SERVER2"
    fi
    if [ "${AGENT2}" ]; then
        install_steps "$1" "$2" "${AGENT2}" "AGENT2"
    fi  
}


install_actions () {
    echo "==============================================
        STAGE: INSTALL ACTIONS
=============================================="
    if [ "${SPLIT_INSTALL}" = false ]; then
        if [ "${VERSION}" ]; then
            install_rke2_on_all_nodes "version" "${VERSION}"        
        else
            install_rke2_on_all_nodes "commit" "${COMMIT}"
        fi
    else
        if [ "${VERSION}" ]; then
            install_rke2_on_setup1 "version" "${VERSION}"
        else
            install_rke2_on_setup1 "commit" "${COMMIT}"
        fi
        if [ "${VERSION2}" ]; then
            install_rke2_on_setup2 "version" "${VERSION2}"
        else
            install_rke2_on_setup2 "commit" "${COMMIT2}"
        fi        
    fi
}

post_install_actions () {
    echo "=========================================================
    STAGE: POST INSTALL - GET STATUS, APPLY WORKLOAD
========================================================="    
    get_rke2_status "${SERVER1}"
    get_rke2_status "${SERVER1}"      
    # get_pods "${SERVER1}"
    if [ "${SPLIT_INSTALL}" = true ]; then 
        get_rke2_status "${SERVER2}"
        get_rke2_status "${SERVER2}"        
        # get_pods "${SERVER2}"
    fi
    if [ "${APPLY_WORKLOAD}" = true ]; then
        apply_workload "${SERVER1}" "SERVER1"
        if [ "${SPLIT_INSTALL}" = true ] ; then
            apply_workload "${SERVER2}" "SERVER2"
        fi
    fi
    if [ "${TAKE_SNAPSHOT}" = true ]; then
        take_snapshot
    fi    
}

reinstall () {
    if [ "${REINSTALL}" = true ]; then
        uninstall_all_nodes
        install_iptables_all_nodes
        create_n_copy_configs
        install_actions
        post_install_actions        
    fi
}

verify_nodeport () {
    if [ "$1" ]; then  ## The second set of nodeport with 'more' namespace
        TMP_PORT="30097"
    else
        TMP_PORT="30096"
    fi
    execute "curl -H "HOSTS" http://${SERVER1}:${TMP_PORT}" "${SERVER1}" "SERVER1"
}

get_services () {
    execute "kubectl get services -A -o wide" "${SERVER1}" "SERVER1"
}

get_ingress () {
    execute "kubectl get ingress -A -o wide" "${SERVER1}" "SERVER1"
}


########### INSTALL STARTS HERE  ########################

ssh_keyscan
prep_slemicro
prep_fapolicyd
reinstall

######### TESTS Start Here !!!! #################

if [ "${MANUAL_UPGRADE}" = true ]; then

    if [ "${REINSTALL}" = true ]; then
        # Giving additional time for pods to come up after install
        echo "Sleep for 60 seconds";  60
    fi
    echo "==============================================
            MANUAL UPGRADE TEST
=============================================="
    echo "BEFORE MANUAL_UPGRADE NODE VERSIONS"
    get_nodes "${SERVER1}"
    get_pods "${SERVER1}"

    echo "1. START New WORKLOAD - clusterip.yaml
2. INSTALL new versions on all nodes
3. RESTART SERVICES of servers and agents"

    apply_workload "${SERVER1}" "SERVER1"

    echo "UPGRADE: SERVER2 ${SERVER2}"
    install_rke2 "version" "${VERSION2}" "${SERVER2}" "server" "${INSTALL_METHOD}"    
    stop_start "${SERVER2}" "server"

    echo "UPGRADE: SERVER3 ${SERVER3}"
    install_rke2 "version" "${VERSION2}" "${SERVER3}" "server" "${INSTALL_METHOD}"     
    stop_start "${SERVER3}" "server"

    update_server1_config

    echo "UPGRADE SERVER1 ${SERVER1}"
    install_rke2 "version" "${VERSION2}" "${SERVER1}" "server" "${INSTALL_METHOD}"
    stop_start "${SERVER1}" "server"

    echo "UPGRADE AGENT1 ${AGENT1}"
    install_rke2 "version" "${VERSION2}" "${AGENT1}" "agent" "${INSTALL_METHOD}"
    stop_start "${AGENT1}" "agent"

    get_nodes "${SERVER1}"
    get_pods "${SERVER1}"

fi

if [ "${NODE_REPLACEMENT}" = true ]; then
    if [ "${REINSTALL}" = true ]; then
        # Giving additional time for pods to come up after install
        echo "Sleep for 60 seconds"; sleep 60
    fi
    echo "==============================================
            NODE REPLACEMENT TEST
=============================================="
    echo "STEPS:
1. Pre-uograde - start a new workload
2. Delete node, say server2 from cluster (run command on different node, server1)
3. Uninstall server2. 
4. Create Directory ${CONFIG_DIR} and Update/Copy over config files
   4a. For server1 alone - point to server2 in config file to join the cluster.
5. Install server2 with new version. 
6. Restart server2 rke2 service. 
7. Repeat 1 through 5 for all servers and agents.
"
    echo "BEFORE MANUAL_UPGRADE NODE VERSIONS"
    get_nodes "${SERVER1}"
    get_pods "${SERVER1}"

    get_node_names
    apply_workload "${SERVER1}" "SERVER1"

    delete_node "${HOSTNAME2}" "SERVER2" "${SERVER1}" "SERVER1"
    reinstall_node "${SERVER2}" "${SERVER2_CONFIG}" "SERVER2" "version" "${VERSION2}" "server" "${INSTALL_METHOD}"

    delete_node "${HOSTNAME3}" "SERVER3" "${SERVER1}" "SERVER1"
    reinstall_node "${SERVER3}" "${SERVER3_CONFIG}" "SERVER3" "version" "${VERSION2}" "server" "${INSTALL_METHOD}"

    delete_node "${HOSTNAME1}" "SERVER1" "${SERVER2}" "SERVER2"
    reinstall_node "${SERVER1}" "${SERVER1_CONFIG}" "SERVER1" "version" "${VERSION2}" "server" "${INSTALL_METHOD}"

    delete_node "${HOSTNAME_AGENT1}" "AGENT1" "${SERVER2}" "SERVER2"
    reinstall_node "${AGENT1}" "${AGENT1_CONFIG}" "AGENT1" "version" "${VERSION2}" "agent" "${INSTALL_METHOD}"
    
    stop_start "${AGENT1}" "agent"
    echo "Sleep for 15 seconds"; sleep 15
    get_nodes "${SERVER1}"
    get_pods "${SERVER1}"

fi

if [ "${CERT_ROTATE}" = true ]; then
    echo "==============================================
            CERTIFICATE ROTATE TEST
=============================================="
    echo "Steps: 
1. Stop rke2 service 
2. Perform certificate rotate
3. Start rke2 service
4. Perform 1 to 3 steps for all 3 server nodes
5. Restart agent service
6. Get and Display Identical File diffs from the new tls-dir and old tls dir on all 3 server nodes"
    stop  "${SERVER1}" "server"
    certificate_rotate "${SERVER1}" "SERVER1"
    start "${SERVER1}" "server"

    stop  "${SERVER2}" "server"
    certificate_rotate "${SERVER2}" "SERVER2"
    start "${SERVER2}" "server"

    stop  "${SERVER3}" "server"
    certificate_rotate "${SERVER3}" "SERVER3"
    start "${SERVER3}" "server"

    stop_start "${AGENT1}" "agent"

    display_identical_files "${SERVER1}" "SERVER1"
    display_identical_files "${SERVER2}" "SERVER2"
    display_identical_files "${SERVER3}" "SERVER3"
fi

if [ "${SECRETS_ENCRYPT_TEST}" = true ]; then
    echo "==============================================
            SECRETS ENCRYPT TEST
=============================================="
    get_node_names
    echo "Status of RKE2 before secrets test start: (Note the # of servers and agents before delete)"
    get_rke2_status "SKIP_SLEEP"
    delete_node "${HOSTNAME3}" "SERVER3" "${SERVER1}" "SERVER1"
    install_etcdctl "${SERVER1}"
    hexdump
    create_secret
    hexdump
    secret_encrypt_status
    secret_encrypt_prepare
    restart_all_nodes
    secret_encrypt_rotate
    restart_all_nodes
    secret_encrypt_reencrypt
    restart_all_nodes
    hexdump
    echo "Expect 2 servers and 1 agent(since we deleted server3):"
    get_rke2_status
fi

if [ "${SUC_UPGRADE}" = true ]; then
    echo "==============================================
                SUC UPGRADE TEST
=============================================="
    apply_suc_crd
    get_system_upgrade_pods
    apply_workload
    apply_auto_upgrade_plan
    get_nodes_pods_upgrade_status
    get_nodes_pods_upgrade_status
    get_nodes_pods_upgrade_status
    get_nodes_pods_upgrade_status
    get_nodes_pods_upgrade_status
    get_nodes_pods_upgrade_status
    stop_start "${AGENT1}" "agent"
    get_nodes_pods_upgrade_status
fi

if [ "${CLUSTER_RESET}" = true ]; then
    echo "==============================================
                CLUSTER RESET TEST
=============================================="
    execute "sudo rke2-killall.sh" "${SERVER2}" "SERVER2"
    execute "sudo rke2-killall.sh" "${SERVER3}" "SERVER3"
    echo "Status should not be available - RKE2 cluster should be down"
    get_rke2_status "SKIP"
    stop "${SERVER1}" "server"
    execute "sudo rke2 server --cluster-reset" "${SERVER1}" "SERVER1"
    start "${SERVER1}" "server"
    echo "Sleep for 60 seconds"; sleep 60
    get_rke2_status
    execute "sudo mv ${DB_PATH} ${DB_PATH_BACKUP}" "${SERVER2}" "SERVER2" 
    execute "sudo mv ${DB_PATH} ${DB_PATH_BACKUP}" "${SERVER3}" "SERVER3"
    start "${SERVER2}" "server"
    echo "Sleep for 60 seconds"; sleep 60
    start "${SERVER3}" "server"
    echo "Sleep for 60 seconds"; sleep 60
    stop_start "${AGENT1}" "agent"
    get_rke2_status     
fi

if [ "${CLUSTER_RESET_RESTORE_PATH_TEST}" = true ]; then
    echo "==============================================
        CLUSTER RESET RESTORE PATH TEST
=============================================="
    echo "STEP: APPLY WORKDLOAD"
    apply_workload "${SERVER1}" "SERVER1" "clusterip-2"
    echo "STEP: STOP ALL NODES"    
    stop_all_nodes
    echo "STEP: REINSTALL SERVER1 - SKIP STARTING SERVICE"     
    reinstall_node "${SERVER1}" "${SERVER1_CONFIG}" "SERVER1" "version" "${VERSION}" "server" "${INSTALL_METHOD}" "SKIP"
    echo "STEP: Restore Cluster from Snapshot"
    restore_cluster_from_snapshot
    echo "STEP: Start RKE2 Service on SERVER1"
    start "${SERVER1}" "server"
    echo "Sleep for 60 seconds"; sleep 60
    get_rke2_status    
    execute "sudo mv ${DB_PATH} ${DB_PATH_BACKUP}" "${SERVER2}" "SERVER2"
    execute "sudo mv ${DB_PATH} ${DB_PATH_BACKUP}" "${SERVER3}" "SERVER3"    
    stop_start "${SERVER2}" "server"
    echo "Sleep for 60 seconds"; sleep 60
    stop_start "${SERVER3}" "server"
    echo "Sleep for 60 seconds"; sleep 60
    stop_start "${SERVER3}" "server"
    echo "Sleep for 60 seconds"; sleep 60    
    stop_start "${AGENT1}" "agent"
    echo "Sleep for 60 seconds"; sleep 60     
    get_rke2_status
fi

common_restore_steps () {
    # $1 Restore Path to use $2 Node_Name_server2 (to delete this node) $3 Node_Name_Server3 (to delete this node)
    echo "STAGE: PERFORMING RESTORE WITH SNAPSHOT: $1"
    echo "Sleep for 60 seconds"; sleep 60
    # Kill the servers
    echo "=====================================KILL START"
    execute "sudo rke2-killall.sh" "${SERVER2}" "SERVER2"
    echo "=====================================KILL FINISH"
    echo "=====================================KILL START"        
    execute "sudo rke2-killall.sh" "${SERVER3}" "SERVER3"
    echo "=====================================KILL FINISH"    
    echo "Status should not be available - RKE2 cluster should be down"
    get_rke2_status "SKIP"
    stop "${SERVER1}" "server"
    echo "STEP: REINSTALL SERVER1 - SKIP STARTING SERVICE"
    if [ -z "${COMMIT}" ]; then
        reinstall_node "${SERVER1}" "${SERVER1_CONFIG}" "SERVER1" "version" "${VERSION}" "server" "${INSTALL_METHOD}" "SKIP"
    else
        reinstall_node "${SERVER1}" "${SERVER1_CONFIG}" "SERVER1" "commit" "${COMMIT}" "server" "${INSTALL_METHOD}" "SKIP"
    fi
    echo "STEP: Restore Cluster from Snapshot 1: $1"
    # restore from snapshot 1
    restore_cluster_from_given_path "$1"
    echo "STEP: Start RKE2 Service on SERVER1"
    start "${SERVER1}" "server"
    echo "Sleep for 60 seconds"; sleep 60
    get_rke2_status    
    execute "sudo mv ${DB_PATH} ${DB_PATH_BACKUP}" "${SERVER2}" "SERVER2"
    execute "sudo mv ${DB_PATH} ${DB_PATH_BACKUP}" "${SERVER3}" "SERVER3"
    # delete_node old node names on the cluster
    execute "${KUBECTL} get nodes | grep -v NotReady | grep -v NAME | awk '{print \$1}' > ${USER_HOME}/node_names_not_ready" "${SERVER1}" "SERVER1"
    echo "NODES NOT READY:"; execute "cat ${USER_HOME}/node_names_not_ready"    
    # delete_node "$2" "SERVER2" "${SERVER1}" "SERVER1"
    # delete_node "$3" "SERVER3" "${SERVER1}" "SERVER1"          
    stop_start "${SERVER2}" "server"
    echo "Sleep for 60 seconds"; sleep 60
    stop_start "${SERVER3}" "server"
    echo "Sleep for 60 seconds"; sleep 60
    stop_start "${SERVER3}" "server"
    echo "Sleep for 60 seconds"; sleep 60    
    stop_start "${AGENT1}" "agent"
    echo "Sleep for 60 seconds"; sleep 60     
    get_rke2_status
    echo "Sleep for 60 seconds"; sleep 60     
    get_rke2_status
    echo "Sleep for 60 seconds"; sleep 60     
    get_rke2_status
    execute "${KUBECTL} get nodes | grep -v NotReady | grep -v NAME | awk '{print \$1}' > ${USER_HOME}/node_names_not_ready" "${SERVER1}" "SERVER1"
    echo "NODES NOT READY:"; execute "cat ${USER_HOME}/node_names_not_ready"

}

if [ "${ETCD_SNAPSHOT_RETENTION}" = true ]; then
    echo "=======================================================================================================
        ETCD SNAPSHOT RETENTION TEST
        1) Set the cron for snapshot creation and retention limit in config yaml
        2) Sleep for 2 mins. 
        3) Update the node name with SUFFIX_1; Delete the old server node name; Restart rke2 service
        4) Repeat step 3 with SUFFIX_2
        5) list snapshots between steps to track them. 
======================================================================================================="
    echo "Sleep 2m"; sleep 2m
    get_rke2_status "${SERVER1}" "SKIP_SLEEP"
    list_snapshots
    # execute "sudo ls -lrt /var/lib/rancher/rke2/server/db/snapshots" "${SERVER1}" "SERVER1"
    # execute "sudo rke2 etcd-snapshot list" "${SERVER1}" "SERVER1"    
    SUFFIX_1="${RANDOM}"
    SUFFIX_2="${RANDOM}"    
    update_node_name "${SUFFIX_1}"
    echo "Sleep 2m"; sleep 2m
    list_snapshots
    # execute "sudo ls -lrt /var/lib/rancher/rke2/server/db/snapshots" "${SERVER1}" "SERVER1"
    # execute "sudo rke2 etcd-snapshot list" "${SERVER1}" "SERVER1"  
    get_rke2_status "${SERVER1}" "SKIP_SLEEP"
    # take_snapshot
    # RESTORE_PATH2="${SNAPSHOT_FILENAME}"
    # common_restore_steps "${RESTORE_PATH2}" "${NEW_NODE_NAME_SERVER2}" "${NEW_NODE_NAME_SERVER3}"
    # SUFFIX_2="${RANDOM}"    
    update_node_name "${SUFFIX_2}"
    echo "Sleep 2m"; sleep 2m
    list_snapshots
    # execute "sudo ls -lrt /var/lib/rancher/rke2/server/db/snapshots" "${SERVER1}" "SERVER1"
    # execute "sudo rke2 etcd-snapshot list" "${SERVER1}" "SERVER1"  
    get_rke2_status "${SERVER1}" "SKIP_SLEEP"       
    # echo "Sleep for 60 seconds"; sleep 60     
    # take_snapshot
    # RESTORE_PATH3="${SNAPSHOT_FILENAME}"
    # common_restore_steps "${RESTORE_PATH3}" "server2-${SUFFIX_2}-${SUFFIX_1}"  "server3-${SUFFIX_2}-${SUFFIX_1}"
    # take_snapshot
    # take_snapshot
fi

if [ "${ETCD_SNAPSHOT_TEST}" = true ]; then
    echo "=====================================================================================================================
        ETCD SNAPSHOT TEST: Save, Prune, Delete, List operations
        Tests covered: 
        1) Save on-demand snapshots - Ex: 5 snapshots. 
        2) Prune on-demand snapshots - say, retention size 3
        3) Delete an on-demand snapshot. 
        4) List snapshots. (For above numbers, Remaining 2 on-demand and 2 cron snapshots with latest timestamps)
====================================================================================================================="
    apply_workload
    if [ "${SPLIT_INSTALL}" = true ]; then
        apply_workload "${SERVER2}" "SERVER2"
    fi
    # echo "Sleep 2m"; sleep 2m
    # list_snapshots 
    # SUFFIX_1="${RANDOM}"
    # SUFFIX_2="${RANDOM}"
    # update_node_name "${SUFFIX_1}"
    # delete_old_node_names "${NODE_NAME_SERVER1}" "${NODE_NAME_SERVER2}" "${NODE_NAME_SERVER3}" "${NODE_NAME_AGENT1}" "update"    
    # echo "Sleep 3m"; sleep 3m
    # list_snapshots     
    # update_node_name "${SUFFIX_2}"
    # delete_old_node_names "${NODE_NAME_SERVER1}-${SUFFIX_1}" "${NODE_NAME_SERVER2}-${SUFFIX_1}" "${NODE_NAME_SERVER3}-${SUFFIX_1}" "${NODE_NAME_AGENT1}-${SUFFIX_1}"    
    # echo "Sleep 3m"; sleep 3m
    # list_snapshots     
    # get_rke2_status "${SERVER1}" "SKIP_SLEEP"
    echo "==========================================================
    STEP: Save on demand snapshots - ${ON_DEMAND_SNAPSHOT_COUNT} snapshots
=========================================================="
    list_snapshots
    if [ "${SPLIT_INSTALL}" = true ]; then
        list_snapshots "${SERVER2}" "SERVER2"
    fi
    for (( I=0; I < "${ON_DEMAND_SNAPSHOT_COUNT}"; I++ ))
    do
        echo "Saving Snapshot Count $I"
        execute "sudo ${PRDT} etcd-snapshot save" "${SERVER1}" "SERVER1"
        if [ "${SPLIT_INSTALL}" = true ]; then 
            execute "sudo ${PRDT} etcd-snapshot save" "${SERVER2}" "SERVER2"
        fi
        echo "Sleeping for 5 sec"; sleep 5      
        # execute "sudo ${PRDT} etcd-snapshot save 2> /dev/null" "${SERVER1}" "SERVER1"
        # execute "sudo ${PRDT} etcd-snapshot save 2> /dev/null" "${SERVER2}" "SERVER2"
        # execute "sudo ${PRDT} etcd-snapshot save 2> /dev/null" "${SERVER3}" "SERVER3"
    done

    echo "=============================================
    Status of snapshot list BEFORE PRUNE/ AFTER SAVE 
============================================="
    list_snapshots
    if [ "${SPLIT_INSTALL}" = true ]; then
        list_snapshots "${SERVER2}" "SERVER2"
    fi
    echo "===================================================================
    STEP: Prune on-demand snapshots with retention size of ${PRUNE_RETENTION_VALUE}: 
==================================================================="           
    echo "Sleeping for 5 sec"; sleep 5  
    execute "sudo ${PRDT} etcd-snapshot prune --snapshot-retention ${PRUNE_RETENTION_VALUE}" "${SERVER1}" "SERVER1"
    if [ "${SPLIT_INSTALL}" = true ]; then     
        execute "sudo ${PRDT} etcd-snapshot prune --snapshot-retention ${PRUNE_RETENTION_VALUE}" "${SERVER2}" "SERVER2"
    fi
    echo "Note: snapshots should be deleted. List should have only ${PRUNE_RETENTION_VALUE} remaining on-demand snapshots and ${ETCD_SNAPSHOT_RETENTION_VALUE} cron snapshots"
    echo "============================================================
    Status of snapshot list AFTER PRUNE and BEFORE DELETE
=============================================================="
    list_snapshots
    if [ "${SPLIT_INSTALL}" = true ]; then
        list_snapshots "${SERVER2}" "SERVER2"
    fi
    echo "========================================
    STEP: Delete on-demand snapshot
========================================"
    SNAP_LIST="${USER_HOME}/snap_list_${RANDOM}"
    execute "sudo ${PRDT} etcd-snapshot list | grep 'on-demand'  &> ${SNAP_LIST}" "${SERVER1}" "SERVER1"
    DELETE_FILE=$(execute "cat ${SNAP_LIST} | awk '{print \$1}' | uniq | head -1" "${SERVER1}" "SERVER1" "SKIP") 
    echo "Delete snapshot file: 
    ${DELETE_FILE}
    "
    execute "sudo ${PRDT} etcd-snapshot delete ${DELETE_FILE}" "${SERVER1}" "SERVER1"
    if [ "${SPLIT_INSTALL}" = true ]; then
        SNAP_LIST_2="${USER_HOME}/snap_list_${RANDOM}"
        execute "sudo ${PRDT} etcd-snapshot list | grep 'on-demand' &> ${SNAP_LIST_2}" "${SERVER2}" "SERVER2"
        DELETE_FILE_2=$(execute "cat ${SNAP_LIST_2} | awk '{print \$1}' | uniq | head -1" "${SERVER2}" "SERVER2" "SKIP") 
        echo "Delete snapshot file:
         ${DELETE_FILE_2}
         "
        execute "sudo ${PRDT} etcd-snapshot delete ${DELETE_FILE_2}" "${SERVER2}" "SERVER2"
    fi
    echo "=============================================
    Status of snapshot list AFTER DELETE
============================================="    
    echo "Check list to have: Remaining 2 on-demand and 2 cron snapshots with latest timestamps"
    list_snapshots
    if [ "${SPLIT_INSTALL}" = true ]; then
        list_snapshots "${SERVER2}" "SERVER2"
    fi  
fi

if [ "${CLUSTER_RESET_WITH_RESTORE}" = true ]; then
    echo "==============================================
            TEST: CLUSTER RESET WITH RESTORE FROM SNAPSHOT
            Steps: 
            1) Using the killall script Stop two server nodes (Server 2 and 3)
            2) Shut down the server on the remaining node - Server1
            3) Run cluster-reset
            4) Restart the server process
            5) Remove the db directories from other servers
            6) Restart the server process on the other servers.
            7) Deploy more workloads
            8) Check the nodeport service

=============================================="
    echo "STEP0: APPLY workload with ns clusterip; take snapshot; apply workload with ns clusterip-2"
    # Apply Workload 
    apply_workload "${SERVER1}" "SERVER1" "clusterip"
    # Take snapshot
    take_snapshot "${RESTORE_FROM_S3_OR_LOCAL}"
    # apply_workload new namespace
    apply_workload "${SERVER1}" "SERVER1" "clusterip-2"
    list_snapshots

    # Killall script for Server 2 and 3
    echo "========= STEP1: Kill All Script run for Servers 2 and 3 ========= "
    execute "sudo ${PRDT}-killall.sh" "${SERVER2}" "SERVER2"
    execute "sudo ${PRDT}-killall.sh" "${SERVER3}" "SERVER3"
    echo "Status should not be available - K3S cluster should be down"
    get_rke2_status "SKIP_SLEEP"
    
    # Shut down rke2 on server1
    echo "========= STEP2: Kill ${PRDT} server for SERVER1 ========= "
    stop "${SERVER1}" "server"

    # Run Cluster Reset
    echo "========= STEP3: CLUSTER RESET WITH RESTORE PATH ========="
    restore_cluster_from_snapshot "${RESTORE_FROM_S3_OR_LOCAL}"

    # Restart rke2 server1
    echo "========= STEP4: RESTART ${PRDT} SERVER1 ========="    
    start "${SERVER1}" "server"
    echo "Sleep for 60 seconds"; sleep 60
    get_rke2_status

    # Remove db directories - servers 2 and 3
    echo "========= STEP5: DELETE DB DIRECTORIES ========="     
    execute "sudo mv ${DB_PATH} ${DB_PATH_BACKUP}" "${SERVER2}" "SERVER2" 
    execute "sudo mv ${DB_PATH} ${DB_PATH_BACKUP}" "${SERVER3}" "SERVER3"

    # Restart servers 2 and 3 and agent 1
    echo "========= STEP6: RESTART Servers 2 and 3 ========="      
    start "${SERVER2}" "server"
    echo "Sleep for 60 seconds"; sleep 60
    start "${SERVER3}" "server"
    echo "Sleep for 60 seconds"; sleep 60
    stop_start "${AGENT1}" "agent"
    echo "Sleep for 60 seconds"; sleep 60    
    get_rke2_status
    echo "No resources will be listed: "
    get_pods_for_ns "clusterip" "${SERVER1}"
    echo "No resources will be listed: "    
    get_pods_for_ns "clusterip-2" "${SERVER1}"
    echo "Expect Pods to be listed for default namespace: "    
    get_pods_for_ns "default" "${SERVER1}"
    echo "========= STEP7: Deploy more workloads and verify status =========" 
    execute "${KUBECTL} apply -f ${WORKLOADS_GH_MORE}" "${SERVER1}" "SERVER1"
    verify_nodeport
    verify_nodeport "more"
    get_services
    get_ingress
fi



if [ "${INSTALL_RANCHER_MANAGER}" = true ]; then
    echo "=====================================
    TEST: INSTALL RANCHER MANAGER
====================================="
    install_helm
    install_rancher
fi

if [ "${CUSTOM_FAPOLICY_TEST}" = true ]; then
    echo "===========================================================
    TEST: CUSTOM: PRINT FAPOLICY FILE
==========================================================="
    if [ "${CUSTOM_INSTALL_CMD}" = true ]; then
        echo "Set: ${CUSTOM_INSTALL_STRING}"
    else
        echo "No Extra CMD ARGS for FAPOLICY was set"
    fi
    execute "sudo cat /etc/fapolicyd/rules.d/80-rke2.rules" "${SERVER1}" "SERVER1"
    execute "sudo systemctl status fapolicyd" "${SERVER1}" "SERVER1"
    if [ "${SPLIT_INSTALL}" = true ]; then
        execute "sudo cat /etc/fapolicyd/rules.d/80-rke2.rules" "${SERVER2}" "SERVER2"
        execute "sudo systemctl status fapolicyd" "${SERVER2}" "SERVER2"
    fi
fi


if [ "${CUSTOM_SELINUX_TEST}" = true ]; then
    echo "===========================================================
    TEST: CUSTOM: SELINUX CONTEXT VERIFICATION
==========================================================="
    execute "rpm -qa container-selinux rke2-server rke2-selinux" "${SERVER1}" "SERVER1"
    execute "sudo ls -laZ /usr/lib/systemd/system/rke2* | grep container_unit_file_t" "${SERVER1}" "SERVER1"
    execute "sudo ls -laZ /etc/systemd/system/rke2* | grep container_unit_file_t" "${SERVER1}" "SERVER1"
    execute "sudo ls -laZ /lib/systemd/system/rke2* | grep container_unit_file_t" "${SERVER1}" "SERVER1"
    execute "sudo ls -laZ /usr/local/lib/systemd/system/rke2* | grep container_unit_file_t" "${SERVER1}" "SERVER1"
    execute "sudo ls -laZ /usr/bin/rke2* | grep container_runtime_exec_t" "${SERVER1}" "SERVER1"
    execute "sudo ls -laZ /usr/local/bin/rke2* | grep container_runtime_exec_t" "${SERVER1}" "SERVER1"           
fi

if [ "${CUSTOM_TEST}" = true ]; then
    echo "===========================================================
    TEST: CUSTOM: ???
==========================================================="
    execute "command" "${SERVER1}" "SERVER1"
fi


execute "source ${USER_HOME}/rke2.source; setup"  # Outputs the setup details of SERVER1 where the test was run
if [ "${SPLIT_INSTALL}" = true ]; then
    execute "source ${USER_HOME}/rke2.source; setup" "${SERVER2}"
fi
