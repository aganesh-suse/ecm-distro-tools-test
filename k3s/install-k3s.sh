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
            echo "======= Execute START ========"
            # echo "\`\`\`"
            echo "$ $1 On SERVER1: ${SERVER1}"
        fi    
        ssh -i "${PEM}" "${USER}"@"$SERVER1" "$1"
    else
        if [ -z $4 ]; then    
            echo "======= Execute START ========"
            # echo "\`\`\`"
            echo " $ $1 On $3: $2"
        fi    
        ssh -i "${PEM}" "${USER}"@"$2" "$1"
    fi
    if [ -z $4 ]; then 
        # echo "\`\`\`"
        echo "======= Execute DONE ========"
    fi
}

copy () {
    # $1 Local_Source_File_Path $2 Remote_Destination_File_Path $3 Node_IP $4 Node_Type(Optional)
    echo "Copy File from $1 to $2 on Node $4: $3"
    scp -i "${PEM}" "$1" "${USER}"@"$3":"$2"
}

ssh_keyscan () {
    if [ "${SSH_KEYSCAN}" = true ]; then
        if [ "${SERVER1}" ]; then
            ssh-keyscan -H "${SERVER1}" >> "${HOME}/.ssh/known_hosts"
        fi
        if [ "${SERVER2}" ]; then
            ssh-keyscan -H "${SERVER2}" >> "${HOME}/.ssh/known_hosts"
        fi
        if [ "${SERVER3}" ]; then
            ssh-keyscan -H "${SERVER3}" >> "${HOME}/.ssh/known_hosts"
        fi
        if [ "${AGENT1}" ]; then
            ssh-keyscan -H "${AGENT1}" >> "${HOME}/.ssh/known_hosts"
        fi
        if [ "${AGENT2}" ]; then
            ssh-keyscan -H "${AGENT2}" >> "${HOME}/.ssh/known_hosts"
        fi
    fi
}

prep_slemicro () {
    if [ "${PREP_SLEMICRO}" = true ]; then
        if echo "${OS_NAME}" | grep -q "slemicro"; then
            if [ "${SERVER1}" ];then
                echo "======Update SELINUX for SERVER1 ${SERVER1}========"
                execute "sudo transactional-update setup-selinux; sudo reboot" "${SERVER1}" "SERVER1"
                echo "========== SERVER1 DONE ==========================="
            fi
            if [ "${SERVER2}" ];then
                echo "======Update SELINUX for SERVER2 ${SERVER2}========"            
                execute "sudo transactional-update setup-selinux; sudo reboot" "${SERVER2}" "SERVER2"
                echo "========== SERVER2 DONE ==========================="                
            fi
            if [ "${SERVER3}" ];then
                echo "======Update SELINUX for SERVER3 ${SERVER3}========"            
                execute "sudo transactional-update setup-selinux; sudo reboot" "${SERVER3}" "SERVER3"
                echo "========== SERVER3 DONE ==========================="                
            fi
            if [ "${AGENT1}" ];then
                echo "======Update SELINUX for AGENT1 ${AGENT1}========"            
                execute "sudo transactional-update setup-selinux; sudo reboot" "${AGENT1}" "AGENT1"
                echo "========== AGENT1 DONE ==========================="                
            fi
            if [ "${AGENT2}" ];then
                echo "======Update SELINUX for AGENT2 ${AGENT2}========"            
                execute "sudo transactional-update setup-selinux; sudo reboot" "${AGENT2}" "AGENT2"
                echo "========== AGENT2 DONE ==========================="                
            fi
            echo "Sleep for 60 seconds - waiting for VM to come back on after reboot"; sleep 60                                 
        fi
    fi
}

apply_custom_workload () {
    # $1 Yaml_Path $2 Namespace $3 Node_IP $4 Node_Type(Optional) 
    execute "${KUBECTL} apply -f $1 -n $2" "$3" "$4"
}

which_k3s () {
    # $1 Node_IP $2 Node_Type
    K3S=$(execute "which k3s" "$1" "$2" "SKIP")
    echo "Using k3s path: ${K3S}"
}

which_k3s_uninstall () {
    if [ "${SERVER1}" ]; then
        K3S_UNINSTALL=$(execute "which k3s-uninstall.sh" "${SERVER1}" "SERVER1" "SKIP")
        echo "Using ${K3S_UNINSTALL} for k3s server uninstall"
    fi        
    if [ "${AGENT1}" ]; then
        K3S_AGENT_UNINSTALL=$(execute "which k3s-agent-uninstall.sh" "${AGENT1}" "AGENT1" "SKIP"  )
        echo "Using ${K3S_AGENT_UNINSTALL} for k3s agent uninstall"
    fi     
}

install_iptables () {
    if [ "${OS_NAME}" = "rhel" ] && [ "${IPTABLES}" = true ]; then
        echo "Install iptables on $2: $1"
        # execute "sudo dnf update -y" "$1"
        execute "sudo  dnf install iptables-services -y" "$1"
    fi    
}

install_iptables_all () {
    if [ "${IPTABLES}" = true ]; then
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
    fi              
}

install_etcdctl () {
    # $1 IP address $2 Node Type
    echo "INSTALL etcdctl for $2: $1"
    if [ "${OS_NAME}" = "ubuntu" ]; then
        execute "sudo apt-get update" "$1"
        execute "sudo -- apt install etcd-client" "$1"
        ETCDCTL="/usr/bin/etcdctl"
    else
        copy "${ETCDCTL_INSTALLER}" "${USER_HOME}/etcdctl_installer.sh" "$1"      
        execute "chmod +x ${USER_HOME}/etcdctl_installer.sh" "$1"
        execute "${USER_HOME}/etcdctl_installer.sh" "$1"
        execute "sudo cp /tmp/etcd-download-test/etcdctl /usr/bin" "$1"
        ETCDCTL="/tmp/etcd-download-test/etcdctl"
    fi
}

install_etcdctl_all () {
    if [ "${SECRETS_ENCRYPT_TEST}" = true ]; then
        if [ "${SERVER1}" ]; then
            install_etcdctl "${SERVER1}" "SERVER1"
        fi
        if [ "${SERVER2}" ]; then
            install_etcdctl "${SERVER2}" "SERVER2"
        fi
        if [ "${SERVER3}" ]; then
            install_etcdctl "${SERVER3}" "SERVER3"
        fi
        if [ "${AGENT1}" ]; then
            install_etcdctl "${AGENT1}" "AGENT1"
        fi
        if [ "${AGENT2}" ]; then
            install_etcdctl "${AGENT2}" "AGENT2"
        fi
    fi              
}

install_docker () {
    # $1 IP address $2 Node Type
    echo "Install Docker for $2: $1"
    DOCKER_EXISTS=$(docker -v &> /dev/null; echo $?)
    if [ "${DOCKER_EXISTS}" != 0 ]; then
        echo "docker does not exist in system. Going to install docker."
        if [ "${OS_NAME}" = "rhel" ]; then
            execute "sudo yum-config-manager     --add-repo     https://download.docker.com/linux/centos/docker-ce.repo" "$1"
            execute "sudo yum install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y" "$1"
            execute "sudo systemctl start docker" "$1"
            # ssh -i "${PEM}" "${USER}"@"$1" "sudo yum-config-manager     --add-repo     https://download.docker.com/linux/centos/docker-ce.repo"
            # ssh -i "${PEM}" "${USER}"@"$1" "sudo yum install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y"
            # ssh -i "${PEM}" "${USER}"@"$1" "sudo systemctl start docker"
        fi
        if [ "${OS_NAME}" = "ubuntu" ]; then
            execute "curl https://releases.rancher.com/install-docker/20.10.sh | sh" "$1"
        fi
        if [ "${OS_NAME}" = "sles" ]; then
            execute "sudo apt-get update" "$1"
            execute "sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common" "$1"
            execute "curl -fsSL https://download.docker.com/linux/sles/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg" "$1"
            execute "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/sles $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null" "$1"
            execute "sudo apt-get update" "$1"
            execute "sudo apt-get install -y docker-ce docker-ce-cli containerd.io" "$1"
            execute "sudo systemctl enable docker" "$1"
            execute "sudo systemctl start docker" "$1"


            # ssh -i "${PEM}" "${USER}"@"$1" "sudo apt-get update"
            # ssh -i "${PEM}" "${USER}"@"$1" "sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common"
            # ssh -i "${PEM}" "${USER}"@"$1" "curl -fsSL https://download.docker.com/linux/sles/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
            # ssh -i "${PEM}" "${USER}"@"$1" "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/sles $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
            # ssh -i "${PEM}" "${USER}"@"$1" "sudo apt-get update"
            # ssh -i "${PEM}" "${USER}"@"$1" "sudo apt-get install -y docker-ce docker-ce-cli containerd.io"
            # ssh -i "${PEM}" "${USER}"@"$1" "sudo systemctl enable docker"
            # ssh -i "${PEM}" "${USER}"@"$1" "sudo systemctl start docker"
        fi
    else
        echo "DOCKER EXISTS?: ${DOCKER_EXISTS}; Skipping docker install"
    fi
}

install_docker_all () {
    if [ "${DOCKER}" = true ]; then
        if [ "${SERVER1}" ]; then
            install_docker "${SERVER1}" "SERVER1"
        fi
        if [ "${SERVER2}" ]; then
            install_docker "${SERVER2}" "SERVER2"
        fi
        if [ "${SERVER3}" ]; then
            install_docker "${SERVER3}" "SERVER3"
        fi
        if [ "${AGENT1}" ]; then
            install_docker "${AGENT1}" "AGENT1"
        fi
        if [ "${AGENT2}" ]; then
            install_docker "${AGENT2}" "AGENT2"
        fi
    fi              
}

install_3rd_party_tools () {
    install_docker_all
    install_etcdctl_all
    install_iptables_all
}

start () {
    # $1 IP address $2 service type: server|agent 
    echo "START K3S Service for $1 $2"
    if [ "$2" = "agent" ]; then
        execute "timeout 2m sudo systemctl start k3s-$2" "$1"
    else
        execute "timeout 2m sudo systemctl start k3s" "$1"
    fi
}

stop () {    
    # $1 IP address $2 service type: server|agent
    echo "STOP K3S Service for $1 $2"
    if [ "$2" = "agent" ]; then
        execute "sudo systemctl stop k3s-$2" "$1"
    else
        execute "sudo systemctl stop k3s" "$1"
    fi
}

restart () {
    # $1 IP address $2 service type: server|agent   
    echo "RESTART K3S Service for $1 $2"     
    if [ "$2" = "agent" ]; then
        execute "timeout 2m sudo systemctl restart k3s-$2" "$1"
    else
        execute "timeout 2m sudo systemctl restart k3s" "$1"
    fi
}

stop_start () {
    # $1 IP address $2 service type: server|agent   
    stop "$1" "$2"
    start "$1" "$2"
    echo "Sleep for 10 seconds"; sleep 10
}

daemon_reload () {
    # $1 IP address $2 Node Type
    # echo "Running systemctl daemon-reload on $2: $1"
    execute "sudo systemctl daemon-reload" "$1" "$2"
    # ssh -i "${PEM}" "${USER}"@"$1" "sudo systemctl daemon-reload"
}

k3s_version () {
    # $1 IP address $2 Node Type: SERVER1|AGENT1
    echo "K3S Version on $2: $1"
    execute 'k3s -v' "$1" "$2"
    # ssh -i "${PEM}" "${USER}"@"$1" 'k3s -v'
}

get_nodes () {
    # $1 IP address
    if [ -z "$1" ]; then
        execute "${KUBECTL} get nodes" "${SERVER1}" "SERVER1"
        # ssh -i "${PEM}" "${USER}"@"${SERVER1}" "${KUBECTL} get nodes"
    else
        execute "${KUBECTL} get nodes" "$1"
        # ssh -i "${PEM}" "${USER}"@"$1" "${KUBECTL} get nodes"
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

get_pods () {
    # $1 IP address
    if [ -z "$1" ]; then
        execute "${KUBECTL} get pods -A" "${SERVER1}" "SERVER1"
    else
        execute "${KUBECTL} get pods -A" "$1"
    fi
}

get_system_upgrade_pods () {
    # $1 IP address
    if [ -z "$1" ]; then
        get_pods_for_ns "system-upgrade" "${SERVER1}" "show_labels"
        # execute "${KUBECTL} get pods -n system-upgrade --show-labels" "${SERVER1}" "SERVER1" 
        # ssh -i "${PEM}" "${USER}"@"${SERVER1}" "${KUBECTL} get pods -n system-upgrade --show-labels"
    else
        get_pods_for_ns "system-upgrade" "$1" "show_labels"
        # execute "${KUBECTL} get pods -n system-upgrade --show-labels" "$1"
        # ssh -i "${PEM}" "${USER}"@"$1" "${KUBECTL} get pods -n system-upgrade --show-labels"
    fi
}

node_name_all_nodes () {
    if [ "${SERVER1}" ]; then
        # NODE_NAME_SERVER1="${CLUSTER_NAME}-server1"
        NODE_NAME_SERVER1="server1"
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
    stop_start_all_nodes
    execute "cat ${CONFIG_DIR}/config.yaml" "${SERVER1}" "SERVER1"
    get_nodes
    echo "=================================================="
}

get_node_names () {
    if [ "${NODE_NAME}" = false ]; then
        echo "Getting hostnames for nodes and assuming them as node names"
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
    else
        echo "Get Node names from the config.yaml file"
        if [ "${SERVER1}" ]; then
            HOSTNAME1=$(ssh -i "${PEM}" "${USER}"@"${SERVER1}" "grep node-name ${CONFIG_DIR}/config.yaml | awk '{ print \$2 }'")
            echo "SERVER1 ${SERVER1} hostname is set to node name: ${HOSTNAME1}"
        fi
        if [ "${SERVER2}" ]; then        
            HOSTNAME2=$(ssh -i "${PEM}" "${USER}"@"${SERVER2}" "grep node-name ${CONFIG_DIR}/config.yaml | awk '{ print \$2 }'")
            echo "SERVER2 ${SERVER2} hostname is set to node name: ${HOSTNAME2}"
        fi
        if [ "${SERVER3}" ]; then        
            HOSTNAME3=$(ssh -i "${PEM}" "${USER}"@"${SERVER3}" "grep node-name ${CONFIG_DIR}/config.yaml | awk '{ print \$2 }'")
            echo "SERVER3 ${SERVER3} hostname is set to node name: ${HOSTNAME3}"
        fi
        if [ "${AGENT1}" ]; then
            HOSTNAME_AGENT1=$(ssh -i "${PEM}" "${USER}"@"${AGENT1}" "grep node-name ${CONFIG_DIR}/config.yaml | awk '{ print \$2 }'")
            echo "AGENT1 ${AGENT1} hostname is ${HOSTNAME_AGENT1}"
        fi
        if [ "${AGENT2}" ]; then
            HOSTNAME_AGENT2=$(ssh -i "${PEM}" "${USER}"@"${AGENT2}" "grep node-name ${CONFIG_DIR}/config.yaml | awk '{ print \$2 }'")
            echo "AGENT2 ${AGENT2} hostname is ${HOSTNAME_AGENT2}"
        fi      
    fi
}

delete_node () {
    # $1 hostname of node to delete
    # $2 Node Type of ($1 - node_type_of_hostname)    
    # $3 IP address of node to run kubectl command on via ssh
    # $4 Node Type of ssh cmd node ($3 node_type_of_ssh_node)
    # Ex: delete_node $hostname node_type_of_hostname $ssh_ip_address node_type_of_ssh_node
    echo "DELETE NODE: $1 hostname of $2 ; execute cmd on node $3 which is: $4"
    execute "${KUBECTL} delete node $1" "$3"
    # ssh -i "${PEM}" "${USER}"@"$3" "${KUBECTL} delete node $1"
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


create_custom_dir () {
    # $1 IP Address $2 Node Type $3 Directory to create $4 Permissions
    echo "CREATE $3 directory on $2: $1"
    if [ -z "$4" ]; then
        execute "sudo mkdir -p $3" "$1"
        # ssh -i "${PEM}" "${USER}"@"$1" "sudo mkdir -p $3"
    else
        echo "SET directory permissions to: $4"
        execute "sudo mkdir -p -m $4 $3" "$1"
        # ssh -i "${PEM}" "${USER}"@"$1" "sudo mkdir -p -m $4 $3"
    fi     
}

create_k3s_config_directory () {
    # $1 IP Address $2 Node Type
    create_custom_dir "$1" "$2" "${CONFIG_DIR}"
    # echo "CREATE ${CONFIG_DIR} directory on $2: $1"
    # ssh -i "${PEM}" "${USER}"@"$1" 'sudo mkdir -p ${CONFIG_DIR}'
}

create_server_directory () {
    # $1 IP Address $2 Node Type    
    create_custom_dir "$1" "$2" "${DATADIR}/server"
}

create_log_directory () {
    # $1 IP Address $2 Node Type     
    create_custom_dir "$1" "$2" "${DATADIR}/server/logs" "700"
}

# create_directory () {
#     # $1 IP Address $2 Node Type
#     echo "CREATE ${CONFIG_DIR} directory on $2: $1"
#     ssh -i "${PEM}" "${USER}"@"$1" 'sudo mkdir -p ${CONFIG_DIR}'
# }

create_directory_all () {
    echo "CREATE ${CONFIG_DIR} directory structure"    
    if [ "${SERVER1}" ]; then
        create_k3s_config_directory "${SERVER1}" "SERVER1"
        if [ "${RESTRICTED}" = true ]; then
            create_server_directory "${SERVER1}" "SERVER1"
        fi
    fi
    if [ "${SERVER2}" ]; then
        create_k3s_config_directory "${SERVER2}" "SERVER2"
        if [ "${RESTRICTED}" = true ]; then
            create_server_directory "${SERVER2}" "SERVER2"
        fi
    fi
    if [ "${SERVER3}" ]; then
        create_k3s_config_directory "${SERVER3}" "SERVER3"
        if [ "${RESTRICTED}" = true ]; then
            create_server_directory "${SERVER3}" "SERVER3"
        fi        
    fi
    if [ "${AGENT1}" ]; then
        create_k3s_config_directory "${AGENT1}" "AGENT1"
    fi
    if [ "${AGENT2}" ]; then
        create_k3s_config_directory "${AGENT2}" "AGENT1"
    fi                
}


cleanup_configs () {
    echo "STAGE: Cleanup Pre-Existing Config files on local system"
    if [ "${REINSTALL}" = true ]; then
        rm -rf "${SERVER1_CONFIG}"
        rm -rf "${SERVER2_CONFIG}"
        rm -rf "${SERVER3_CONFIG}"
        rm -rf "${AGENT1_CONFIG}"
        rm -rf "${AGENT2_CONFIG}"
    fi
}

uninstall () {
    # $1 IP address $2 Node Type
    # Ex: uninstall "${SERVER1}" "SERVER1"
    # Ex: uninstall "${AGENT1}" "AGENT1"
    echo "===================================================
    UNINSTALL k3s on $2: $1
==================================================="
    if [ -z "${K3S_UNINSTALL}" ]; then
        which_k3s_uninstall
    fi    
    if echo "$2" | grep -q "server" || echo "$2" | grep -q "SERVER"; then
        execute "sudo ${K3S_UNINSTALL}" "$1"
        # ssh -i "${PEM}" "${USER}"@"$1" "sudo ${K3S_UNINSTALL}"
    else
        execute "sudo ${K3S_AGENT_UNINSTALL}" "$1"
        # ssh -i "${PEM}" "${USER}"@"$1" "sudo ${K3S_AGENT_UNINSTALL}"
    fi
    echo "==================================================="     
}

create_local_configs () {
    echo "CREATE Local Copy of CONFIGS for servers and agents"
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

etcd () {
    # $1 server1_config(etcd only); $2 server2_config(control plane only)
    if [ "${ETCD}" = true ]; then
        # Server 1 Configs: 
        echo "DISABLE apiserver, controller-manager and scheduler in SERVER1"
        echo "disable-apiserver: true
disable-controller-manager: true
disable-scheduler: true
node-taint:
- node-role.kubernetes.io/etcd:NoExecute" >> "$1"        
        # Server 2 Configs:
        echo "DISABLE etcd in SERVER2"
        echo "disable-etcd: true
node-taint:
- node-role.kubernetes.io/control-plane:NoSchedule" >> "$2"        
    fi
    if [ "${ETCD_SNAPSHOT_TEST}" = true ] || [ "${ETCD_SNAPSHOT_RETENTION_UPDATE_NODE_NAMES}" = true ]  ; then
        # || [ "${CLUSTER_RESET_WITH_RESTORE}" = true ]
        # SERVER1 - etcd only; SERVER2: control plane only; SERVER3 both etcd and control plane
        echo "etcd-snapshot-retention: ${ETCD_SNAPSHOT_RETENTION_VALUE}
etcd-snapshot-schedule-cron: \"* * * * *\"
etcd-s3: true
etcd-s3-access-key: ${S3_ACCESS_KEY}
etcd-s3-secret-key: ${S3_SECRET_KEY}
etcd-s3-bucket: ${S3_BUCKET}
etcd-s3-folder: ${S3_FOLDER_1}
etcd-s3-region: ${S3_REGION}
" >> "${SERVER1_CONFIG}"
        if [ "${SPLIT_INSTALL}" = true ]; then
            echo "etcd-snapshot-retention: ${ETCD_SNAPSHOT_RETENTION_VALUE}
etcd-snapshot-schedule-cron: \"* * * * *\"
etcd-s3: true
etcd-s3-access-key: ${S3_ACCESS_KEY}
etcd-s3-secret-key: ${S3_SECRET_KEY}
etcd-s3-bucket: ${S3_BUCKET}
etcd-s3-folder: ${S3_FOLDER_2}
etcd-s3-region: ${S3_REGION}
" >> "${SERVER2_CONFIG}"
        fi
# #         echo "etcd-snapshot-retention: ${ETCD_SNAPSHOT_RETENTION_VALUE}
# # etcd-snapshot-schedule-cron: \"* * * * *\"
# # etcd-s3: true
# # etcd-s3-access-key: ${S3_ACCESS_KEY}
# # etcd-s3-secret-key: ${S3_SECRET_KEY}
# # etcd-s3-bucket: ${S3_BUCKET}
# # etcd-s3-folder: ${S3_FOLDER_3}
# # etcd-s3-region: ${S3_REGION}
# # " >> "${SERVER3_CONFIG}"
    fi
 
#     if [ "${ETCD_SNAPSHOT_RETENTION_UPDATE_NODE_NAMES}" = true ]; then
#         echo "etcd-snapshot-retention: ${ETCD_SNAPSHOT_RETENTION_VALUE}
# etcd-snapshot-schedule-cron: \"* * * * *\"
# etcd-s3: true
# etcd-s3-access-key: ${S3_ACCESS_KEY}
# etcd-s3-secret-key: ${S3_SECRET_KEY}
# etcd-s3-bucket: ${S3_BUCKET}
# etcd-s3-folder: ${S3_FOLDER_1}
# etcd-s3-region: ${S3_REGION}
# " >> "${SERVER1_CONFIG}"
#     fi   
}

selinux () {
    # $1 config_file
    if [ "${SELINUX}" = true ]; then
        echo "selinux: true" >> "$1"
    fi
}

prefer_bundled_bin () {
    # $1 config_file    
    if [ "${PREFER_BUNDLED_BIN}" = true ]; then
        echo "prefer-bundled-bin: true" >> "$1"
    fi    
}

docker () {
    # $1 config_file    
    if [ "${DOCKER}" = true ]; then
        echo "docker: true" >> "$1"
    fi      
}

protect_kernel () {
    # $1 IP address $2 config_file $3 NodeType
    if [ "${PROTECT_KERNEL}" = true ]; then
        echo "protect-kernel-defaults: true" >> "$2"
        # echo "Copy ${KUBELET_CONF_KERNEL_PARAMS} onto node $1"
        copy "${KUBELET_CONF_KERNEL_PARAMS}" "${USER_HOME}/90-kubelet.conf" "$1"
        # scp -i "${PEM}" "${KUBELET_CONF_KERNEL_PARAMS}" "${USER}"@"$1":"${USER_HOME}"/90-kubelet.conf
        execute "sudo cp ${USER_HOME}/90-kubelet.conf /etc/sysctl.d/90-kubelet.conf" "$1"
        # ssh -i "${PEM}" "${USER}"@"$1" "sudo cp ${USER_HOME}/90-kubelet.conf /etc/sysctl.d/90-kubelet.conf"
        execute "sudo sysctl -p /etc/sysctl.d/90-kubelet.conf" "$1"
        # ssh -i "${PEM}" "${USER}"@"$1" "sudo sysctl -p /etc/sysctl.d/90-kubelet.conf"
    fi
}

pod_security () {
    # $1 IP address $2 config_file $3 Node type
    create_server_directory "$1" "$3"
    # scp -i "${PEM}" "${POD_SECURITY_YAML}" "${USER}"@"$1":"${USER_HOME}"/psa.yaml
    copy "${POD_SECURITY_YAML}" "${USER_HOME}/psa.yaml" "$1"
    execute "sudo cp ${USER_HOME}/psa.yaml ${DATADIR}/server/psa.yaml" "$1"
    # ssh -i "${PEM}" "${USER}"@"$1" "sudo cp ${USER_HOME}/psa.yaml ${DATADIR}/server/psa.yaml"
    if [ "${POD_SECURITY}" = true ]; then
        echo "kube-apiserver-arg:
- \"admission-control-config-file=${DATADIR}/server/psa.yaml\"" >> "$2"
    fi
}

audit () {
    # $1 IP address $2 config_file $3 node type
    if [ "${AUDIT}" = true ]; then
        create_server_directory "$1" "$3"     
        create_log_directory "$1" "$3"       
        # scp -i "${PEM}" "${AUDIT_FILE}" "${USER}"@"$1":"${USER_HOME}"/audit.yaml
        copy "${AUDIT_FILE}" "${USER_HOME}/audit.yaml" "$1"
        execute "sudo cp ${USER_HOME}/audit.yaml ${DATADIR}/server/audit.yaml" "$1"
        # ssh -i "${PEM}" "${USER}"@"$1" "sudo cp ${USER_HOME}/audit.yaml ${DATADIR}/server/audit.yaml"
        if [ "${POD_SECURITY}" = false ]; then
            echo "kube-apiserver-arg:" >> "$2"
        fi
        echo "- 'audit-log-path=${DATADIR}/server/logs/audit.log'
- 'audit-policy-file=${DATADIR}/server/audit.yaml'" >> "$2"        
    fi
}

secrets_encrypt () {
    if [ "${SECRETS_ENCRYPT}" = true ]; then
        echo "secrets-encryption: true" >> "$1"
    fi
}

tls_san () {
    # $1 Node IP $2 Config_File
    if [ "${TLS_SAN}" = true ]; then
        echo "tls-san: \"$1.nip.io\"" >> "$2"
    fi
}

write_kubeconfig_mode () {
    if echo "$1" | grep -q  "server"; then
        echo "write-kubeconfig-mode: \"0644\"" >> "$1"
    fi
}

node_external_ip () {
    # $1 Node IP $2 Config File
    if [ "${NODE_EXTERNAL_IP}" = true ]; then
        echo "node-external-ip: $1" >> "$2"
    fi
}

node_label () {
    # $1 config_file
    if echo "$1" | grep -q "server"; then
        echo "node-label:
- k3s-upgrade=server" >> "$1"
    else
        echo "node-label:
- k3s-upgrade=agent" >> "$1"
    fi
}

edit_local_configs () {
    # $1 Node IP address $2 Config_File $3 Node Type
    # etcd "${SERVER1_CONFIG}" "${SERVER2_CONFIG}"
    echo "EDIT Local Configs: Node Type: $3 IP: $1 Config File: $2"
    node_external_ip "$1" "$2"
    node_label "$2"
    selinux "$2"
    protect_kernel "$1" "$2" "$3"
    docker "$2"  
}


edit_server_only_configs () {
    # Node IP address $1 Config_File $2 Node Type $3    
    echo "Edit SERVER config files: Node Type: $3 IP: $1  Config File: $2 "    
    tls_san "$1" "$2"
    write_kubeconfig_mode "$2"
    pod_security "$1" "$2" "$3"
    audit "$1" "$2" "$3"
    prefer_bundled_bin "$2"
    secrets_encrypt "$2"    
}

edit_secondary_node_configs () {
    echo "EDIT server key/value to point to etcd server in config file"
    if [ -z "${AGENT2}" ] && [ "${SPLIT_INSTALL}" = false ]; then
        # If agent2 is present, server2 is a main server
        # If agent2 is not present, server2 is a secondary server
        if [ -z "${PRIVATE_IP}" ]; then
            echo "server: https://${SERVER1}:${PORT}" >> "${SERVER2_CONFIG}"
        else
            echo "server: https://${PRIVATE_IP}:${PORT}" >> "${SERVER2_CONFIG}"
        fi
    fi
    if [ "${SERVER3}" ]; then
        if [ -z "${PRIVATE_IP}" ]; then
            echo "server: https://${SERVER1}:${PORT}" >> "${SERVER3_CONFIG}"
        else
            echo "server: https://${PRIVATE_IP}:${PORT}" >> "${SERVER3_CONFIG}"
        fi
    fi
    if [ "${AGENT1}" ]; then
        echo "server: https://${SERVER1}:${PORT}" >> "${AGENT1_CONFIG}"
    fi
    if [ "${AGENT2}" ]; then
        echo "server: https://${SERVER2}:${PORT}" >> "${AGENT2_CONFIG}"
    fi
}

cluster_init () {
    # if [ -z "${AGENT2}" ] && [ "${SERVER3}" ]; then
    echo "cluster-init: true" >> "${SERVER1_CONFIG}"
    if [ "${SPLIT_INSTALL}" = true ]; then
        echo "cluster-init: true" >> "${SERVER2_CONFIG}"        
    fi
}

node_name () {
    # $1 Node_Name $2 Server_Config_File
    if [ "${NODE_NAME}" = true ]; then
        echo "node-name: \"$1\"" >> "$2"
    fi
}

copy_over_config () {
    # $1 Node IP address $2 Config_File $3 Node Type
    echo "Copy Config: Node IP: $1: Copy config file: $2  Node Type: $3"
    copy "$2" "${USER_HOME}/config.yaml" "$1"  # Copy yaml_file from local machine to remote user home dir
    execute "sudo cp ${USER_HOME}/config.yaml ${CONFIG_DIR}/config.yaml" "$1"  # Copy within remote dirs: user home dir to config dir
    echo "==============================================
    CONFIG YAML CONTENT: $3 
=============================================="
    execute "cat ${CONFIG_DIR}/config.yaml" "$1"
    echo "=============================================="
}

copy_over_files () {
    # $1 Node IP address $2 Config_File $3 Node Type
    echo "COPY over source_files, installers, yamls, configs: Node IP: $1: Copy config file: $2  Node Type: $3"
    copy "${SOURCE}" "${USER_HOME}/k3s.source" "$1"
    copy "${SOURCE2}" "${USER_HOME}/aliases.sh" "$1"
    # copy "${ETCDCTL_INSTALLER}" "${USER_HOME}/etcdctl_installer.sh" "$1"
    if [ "${POD_SECURITY}" = true ]; then
        copy "${POD_SECURITY_YAML}" "${USER_HOME}/pod-security.yaml" "$1"
    fi
    if [ "${AUDIT}" = true ]; then
        copy "${AUDIT_YAML}" "${USER_HOME}/audit.yaml" "$1"
    fi   
    copy_over_config "$1" "$2" "$3"
}

copy_over_test_yamls () {
    # These yamls can remain on server1 (or server2 in case of split install) only

    copy "${CLUSTERIP_YAML}" "${USER_HOME}/clusterip.yaml" "${SERVER1}" "SERVER1"
    if [ "${CUSTOM_WORKLOAD}" = true ]; then
        copy "${CUSTOM_WORKLOAD_YAML}" "${CUSTOM_WORKLOAD_DESTINATION_FILE_PATH}" "${SERVER1}" "SERVER1"
    fi     
    # copy "${WEB_YAML}" "${USER_HOME}/web.yaml" "${SERVER1}" "SERVER1"
    if [ "${SPLIT_INSTALL}" = true ] && [ "${SERVER2}" ]; then
        copy "${CLUSTERIP_YAML}" "${USER_HOME}/clusterip.yaml" "${SERVER2}" "SERVER2"
        # copy "${WEB_YAML}" "${USER_HOME}/web.yaml" "${SERVER2}" "SERVER1"
        if [ "${CUSTOM_WORKLOAD}" = true ]; then
            copy "${CUSTOM_WORKLOAD_YAML}" "${CUSTOM_WORKLOAD_DESTINATION_FILE_PATH}" "${SERVER2}" "SERVER2"
        fi 
    fi 
    if [ "${SUC_UPGRADE}" = true ]; then
        if [ "${CIS}" = true ] && [ "${POD_SECURITY_TYPE}" = "restricted" ]; then
            copy "${SU_NS_PRIVILEGE_YAML}" "${USER_HOME}/su_ns_privilege.yaml" "${SERVER1}" "SERVER1"
        fi
    fi
}

options () {
    # $1 commit or version? $2 version_value or commit_value $3 Node IP address $4 server or agent
    # Ex: install_k3s version v1.24.5+k3s1 3.1.1.1 server     
    # options to pass onto k3s server should go here.
    OPTIONS="- $4"
    if [ "${DOCKER}" = true ] && [ "$4" = "server" ]; then
        OPTIONS="${OPTIONS} --docker"
    fi
    echo "Options value: ${OPTIONS}"
}

cmd () {
    # $1 commit or version? $2 version_value or commit_value $3 Node IP address $4 server or agent $5 "SKIP_ENABLE"
    # Ex: cmd version v1.24.5+k3s1 3.1.1.1 server
    # EX: cmd version v1.24.5+k3s1 3.1.1.1 server SKIP_ENABLE
    # Any vars needed to install k3s go here
    if [ "$1" = "commit" ]; then
        CMD="INSTALL_K3S_COMMIT='$2'"
    else
        CMD="INSTALL_K3S_VERSION='$2'"
    fi
    if [ "$5" = "SKIP_ENABLE" ]; then
        CMD="${CMD} INSTALL_K3S_SKIP_ENABLE=true"
    fi
    if [ "${OS_NAME}" = "rhel" ] || [ "${OS_NAME}" = "slemicro" ]; then
        if echo "$2" | grep -q  "rc"; then
            CMD="${CMD} INSTALL_K3S_CHANNEL=testing"
        fi
    fi

    echo "CMD at function end: ${CMD}"   
}

install_k3s () {
    # $1 commit|version $2 version_value|commit_value $3 node_ip_address $4 server|agent $5 "SKIP_ENABLE"
    # Ex: install_k3s version v1.24.5+k3s1 3.1.1.1 server
    # Ex: install_k3s version v1.24.5+k3s1 3.1.1.1 server SKIP_ENABLE
    echo "========================================================================================
    INSTALL/UPGRADE K3S with options: $1 $2 $3 $4
    ssh -i ${PEM} ${USER}@$3
========================================================================================"
    CMD=""
    OPTIONS=""
    options "$1" "$2" "$3" "$4"    
    cmd "$1" "$2" "$3" "$4" "$5"
    if [ "${EXEC}" = true ]; then
        CMD="${CMD} INSTALL_K3S_EXEC='$4'"
        EXECUTE="sudo ${CMD} sh -s"
    else
        EXECUTE="sudo ${CMD} sh -s ${OPTIONS}"
    fi
    execute "curl -sfL https://get.k3s.io | ${EXECUTE}" "$3"
    echo "===================INSTALL DONE==============================="
}

install_suc () {
    echo "===================
    INSTALL SUC
==================="
    execute "${KUBECTL} apply -f ${SYSTEM_UPGRADE_CRD}" "${SERVER1}" "SERVER1"
    if [ "${CIS}" = true ]; then
        copy "${SU_NS_PRIVILEGE_YAML}" "${USER_HOME}/su_ns_privilege.yaml" "${SERVER1}" "SERVER1"
        execute "${KUBECTL} apply -f ${USER_HOME}/su_ns_privilege.yaml" "${SERVER1}" "SERVER1"
    fi
}

# Test Related Functions

apply_workload () {
    # $1 Node_IP_Address $2 Node_Type for logging $3 namespace to deploy the workload on, Ex: clusterip-2
    # We are using clusterip.yaml for this. 
    # Note: clusterip.yaml was already copied over in copy_over_files funtion
    echo "======================
    APPLY WORKLOAD
======================"
    if [ -z "$3" ]; then
        if [ "${CIS}" = true ]; then
            NAMESPACE="clusterip"
        else
            NAMESPACE="default"
        fi
    else
        NAMESPACE="$3"
    fi   
    if [ -z "$1" ]; then
        NODE="${SERVER1}"
        NODE_TYPE="SERVER1"
    else
        NODE="$1"
        NODE_TYPE="$2"
    fi
    echo "Start a workload (clusterip.yaml) on ${NODE_TYPE}: ${NODE}"
    execute "${KUBECTL} apply -f ${USER_HOME}/clusterip.yaml -n ${NAMESPACE}" "${NODE}" "${NODE_TYPE}"
    execute "${KUBECTL} apply -f ${WORKLOADS_GH}" "${NODE}" "${NODE_TYPE}"
    if [ "${CUSTOM_WORKLOAD}" = true ]; then
        execute "${KUBECTL} apply -f ${CUSTOM_WORKLOAD_DESTINATION_FILE_PATH}" "${NODE}" "${NODE_TYPE}" 
    fi    
    # execute "${KUBECTL} apply -f ${USER_HOME}/web.yaml -n kube-system" "${NODE}" "${NODE_TYPE}"
    get_pods_for_ns "${NAMESPACE}" "${NODE}" "show_labels"
}

create_auto_upgrade_plan () {
    cp "${AUTO_UPGRADE_PLAN_YAML}" "${AUTO_UPGRADE_PLAN_YAML_FILE}"
    sed -i -re "s/upgrade_version/${VERSION2}/g" "${AUTO_UPGRADE_PLAN_YAML_FILE}"
    copy "${AUTO_UPGRADE_PLAN_YAML_FILE}" "${USER_HOME}/plan.yaml" "${SERVER1}" "SERVER1"
}

apply_auto_upgrade_plan () {
    create_auto_upgrade_plan
    execute "${KUBECTL} apply -f ${USER_HOME}/plan.yaml; ${KUBECTL} get plans -n system-upgrade > plans; ${KUBECTL} get jobs -n system-upgrade > jobs" "${SERVER1}" "SERVER1"
}    

get_nodes_pods_status () {
    echo "Sleep for 60 seconds"; sleep 60
    get_nodes
    get_pods
}

update_secondary_server_ip () {
    if [ "${PRIVATE_IP}" ]; then
        execute "sudo sed -i -re 's/${PRIVATE_IP}/${SERVER1}/g' \"${CONFIG_DIR}/config.yaml\"" "${SERVER2}" "SERVER2"
        execute "sudo sed -i -re 's/${PRIVATE_IP}/${SERVER1}/g' \"${CONFIG_DIR}/config.yaml\"" "${SERVER3}" "SERVER3"
        stop_start "${SERVER2}" "server"
        stop_start "${SERVER3}" "server"
    fi  
}

install_k3s_on_all_nodes () {
    # Ex: install_k3s_on_all_nodes commit commit_id 
    # $1 commit|version $2 commit_id|version_number 
    if [ "${SERVER1}" ]; then
        echo "INSTALL $1: $2 on SERVER1 ${SERVER1}"
        install_k3s "$1" "$2" "${SERVER1}" "server"
        stop_start "${SERVER1}" "server"
        echo "======== K3S Version on SERVER1: ${SERVER1}: "
        k3s_version "${SERVER1}" "SERVER1"
        echo "======== CONFIG YAML on SERVER1: ${SERVER1}: : "
        execute "cat ${CONFIG_DIR}/config.yaml" "${SERVER1}" "SERVER1"
    fi
    if [ "${SERVER2}" ]; then
        echo "INSTALL $1: $2 on SERVER2 ${SERVER2}"
        install_k3s "$1" "$2" "${SERVER2}" "server"
        stop_start "${SERVER2}" "server"
        echo "======= K3S Version on SERVER2: ${SERVER2}: "
        k3s_version "${SERVER2}" "SERVER2"
        echo "======= CONFIG YAML on SERVER2: ${SERVER2}: "
        execute "cat ${CONFIG_DIR}/config.yaml" "${SERVER2}" "SERVER2"        
    fi
    if [ "${SERVER3}" ]; then
        echo "INSTALL $1: $2 on SERVER3 ${SERVER3}"
        install_k3s "$1" "$2" "${SERVER3}" "server"       
        stop_start "${SERVER3}" "server"
        echo "======= K3S Version on SERVER3: ${SERVER3}: "    
        k3s_version "${SERVER3}" "SERVER3"
        echo "======= CONFIG YAML on SERVER3: ${SERVER3}: "
        execute "cat ${CONFIG_DIR}/config.yaml" "${SERVER3}" "SERVER3"       
    fi
    if [ "${AGENT1}" ]; then
        echo "INSTALL $1: $2 on AGENT1 ${AGENT1}"
        install_k3s "$1" "$2" "${AGENT1}" "agent"    
        stop_start "${AGENT1}" "agent"
        echo "======== K3S Version on AGENT1: ${AGENT1}: "
        k3s_version "${AGENT1}" "AGENT1"
        echo "======== CONFIG YAML on AGENT1: ${AGENT1}: "
        execute "cat ${CONFIG_DIR}/config.yaml" "${AGENT1}" "AGENT1"        
    fi
    update_secondary_server_ip
    get_k3s_status
}

install_k3s_on_setup1 () {
    # SERVER1 and AGENT1 will be installed here: 
    # Ex: install_k3s_on_setup1 commit commit_id 
    # $1 commit|version $2 commit_id|version_number 
    if [ "${SERVER1}" ]; then
        echo "INSTALL $1: $2 on SERVER1 ${SERVER1}"
        install_k3s "$1" "$2" "${SERVER1}" "server"
        stop_start "${SERVER1}" "server"
        k3s_version "${SERVER1}" "SERVER1"
    fi
    if [ "${AGENT1}" ]; then
        echo "INSTALL $1: $2 on AGENT1 ${AGENT1}"
        install_k3s "$1" "$2" "${AGENT1}" "agent"    
        stop_start "${AGENT1}" "agent"
        k3s_version "${AGENT1}" "AGENT1"
    fi      
}

install_k3s_on_setup2 () {
    # SERVER2 and AGENT2 will be installed here: 
    # Ex: install_k3s_on_setup2 commit commit_id 
    # $1 commit|version $2 commit_id|version_number 
    if [ "${SERVER2}" ]; then
        echo "INSTALL $1: $2 on SERVER2 ${SERVER2}"
        install_k3s "$1" "$2" "${SERVER2}" "server" 
        stop_start "${SERVER2}" "server"
        k3s_version "${SERVER2}" "SERVER2"
    fi
    if [ "${AGENT2}" ]; then
        echo "INSTALL $1: $2 on AGENT2 ${AGENT2}"
        install_k3s "$1" "$2" "${AGENT2}" "agent"
        stop_start "${AGENT2}" "agent"
        k3s_version "${AGENT2}" "AGENT2"
    fi  
}

update_server1_config () {
    echo "Update the config.yaml of server1 ${SERVER1} to point to server3 ${SERVER3}"
    echo "server: https://${SERVER3}:${PORT}" >> "${SERVER1_CONFIG}"
    echo "SERVER1 ${SERVER1}: Copy over ${SERVER1_CONFIG}"
    copy "${SERVER1_CONFIG}" "${USER_HOME}/config.yaml" "${SERVER1}" "SERVER1"
    execute "sudo cp ${USER_HOME}/config.yaml ${CONFIG_DIR}/config.yaml" "${SERVER1}" "SERVER1"
}

replace_server2 () {
    # $1 commit|version $2 commit_id|version_id
    echo "Replacing SERVER2: Delete node, stop k3s, install new version/commit, start k3s"
    delete_node "${HOSTNAME2}" "SERVER2" "${SERVER1}" "SERVER1"
    get_nodes
    stop "${SERVER2}" "server"
    install_k3s "$1" "$2" "${SERVER2}" "server"
    start "${SERVER2}" "server"
    echo "Sleep for 10 seconds"; sleep 10
    get_nodes    
}

replace_server3 () {
    # $1 commit|version $2 commit_id|version_id
    echo "Replacing SERVER3: Delete node, stop k3s, install new version/commit, start k3s"    
    delete_node "${HOSTNAME3}" "SERVER3" "${SERVER1}" "SERVER1"
    get_nodes
    stop "${SERVER3}" "server"
    install_k3s "$1" "$2" "${SERVER3}" "server"
    start "${SERVER3}" "server"
    echo "Sleep for 10 seconds"; sleep 10
    get_nodes    
}

replace_server1 () {
    # $1 commit|version $2 commit_id|version_id
    echo "Replacing SERVER1: Delete node, stop k3s, edit config - point to server3, install new version/commit, start k3s"
    echo "NOTE: server3 - should be etcd (and control plane node) - Since we updated the server1 config to point to server3)"   
    delete_node "${HOSTNAME1}" "SERVER1" "${SERVER2}" "SERVER2"
    get_nodes "${SERVER3}"
    stop "${SERVER1}" "server"
    update_server1_config
    install_k3s "$1" "$2" "${SERVER1}" "server"
    start "${SERVER1}" "server"
    echo "Sleep for 10 seconds"; sleep 10
    get_nodes "${SERVER3}"   
}

replace_agent1 () {
    # $1 commit|version $2 commit_id|version_id
    echo "Replace AGENT2: Delete node, stop k3s-agent, install new version, start k3s-agent"
    delete_node "${HOSTNAME_AGENT1}" "AGENT1" "${SERVER2}" "SERVER2"
    get_nodes
    stop "${AGENT1}" "agent"
    install_k3s "$1" "$2" "${AGENT1}" "agent"
    start "${AGENT1}" "agent"
    echo "Sleep for 10 seconds"; sleep 10
    get_nodes    
}

replace_nodes () {
    # $1 commit|version $2 commit_id|version_id    
    replace_server2 "$1" "$2"
    replace_server3 "$1" "$2"
    replace_server1 "$1" "$2"
    replace_agent1 "$1" "$2"
}

certificate_rotate () {
    # $1 IP Address $2 Node_Type
    if [ -z "${K3S}" ]; then
        which_k3s "${SERVER1}"
    fi 
    echo "Rotate Certificate for $2: $1"
    ssh -i "${PEM}" "${USER}"@"$1" "sudo ${K3S} --debug certificate rotate > cert_rotate_output"
}

display_identical_files () {
    # $1 IP address $2 
    echo "Get identical files for: $2: $1"
    TLS_DIR=$(ssh -i "${PEM}" "${USER}"@"$1" "sudo ls -lt ${DATADIR}/server/ | grep tls | awk {'print \$9'} | sed -n '2 p'")
    echo "TLS_DIR : ${TLS_DIR}"    
    ssh -i "${PEM}" "${USER}"@"$1" "sudo diff -sr ${DATADIR}/server/tls/ ${DATADIR}/server/${TLS_DIR}/ | grep -i identical | awk '{print \$2}' | xargs basename -a | awk 'BEGIN{print \"Identical Files:  \"}; {print \$1}'"
}

hexdump () {
    # $1 IP address
    echo "SERVER1 ${SERVER1} Hexdump: "
    execute "sudo ETCDCTL_API=3 ${ETCDCTL} --cert ${DATADIR}/server/tls/etcd/server-client.crt --key ${DATADIR}/server/tls/etcd/server-client.key --endpoints https://127.0.0.1:2379 --cacert ${DATADIR}/server/tls/etcd/server-ca.crt get /registry/secrets/default/secret1 | hexdump -C" "${SERVER1}" "SERVER1"
    execute "sudo ETCDCTL_API=3 ${ETCDCTL} --cert ${DATADIR}/server/tls/etcd/server-client.crt --key ${DATADIR}/server/tls/etcd/server-client.key --endpoints https://127.0.0.1:2379 --cacert ${DATADIR}/server/tls/etcd/server-ca.crt get /registry/secrets/default/secret1 | hexdump -C | grep $(date +'%m-%d')" "${SERVER1}" "SERVER1"
}

create_secret () {
    # $1 Ip address $2 node type
    echo "Create Secret: SERVER1 ${SERVER1} "
    execute "${KUBECTL} create secret generic secret1 -n default --from-literal=mykey=mydata" "${SERVER1}" "SERVER1"
}

secret_encrypt_status () {
    # $1 IP address $2 node type
    if [ -z "${K3S}" ]; then
        which_k3s "${SERVER2}"
    fi
    echo "SECRET_ENCRYPT: SERVER2 ${SERVER2} Get Status"
    execute "sudo ${K3S} secrets-encrypt status > status" "${SERVER2}" "SERVER2"
}
secret_encrypt_prepare () {
    # $1 IP address $2 node type
    if [ -z "${K3S}" ]; then
        which_k3s "${SERVER2}"
    fi
    echo "SECRET_ENCRYPT: SERVER2 ${SERVER2} Run Prepare"
    execute "sudo ${K3S} secrets-encrypt prepare" "${SERVER2}" "SERVER2"
}
secret_encrypt_rotate () {
    # $1 IP address $2 node type
    if [ -z "${K3S}" ]; then
        which_k3s "${SERVER2}"
    fi
    echo "SECRET_ENCRYPT: SERVER2 ${SERVER2} Run rotate"
    execute "sudo ${K3S} secrets-encrypt rotate" "${SERVER2}" "SERVER2"
    echo "Sleep for 5 seconds"; sleep 5
}
secret_encrypt_reencrypt () {
    # $1 IP address $2 node type
    if [ -z "${K3S}" ]; then
        which_k3s "${SERVER2}"
    fi
    echo "SECRET_ENCRYPT: SERVER2 ${SERVER2} Run reencrypt"
    execute "sudo ${K3S} secrets-encrypt reencrypt" "${SERVER2}" "SERVER2" 
    echo "Sleep for 15 seconds"; sleep 15
}

get_node_count () {
    NODE_COUNT=$(ssh -i "${PEM}" "${USER}"@"${SERVER1}" "${KUBECTL} get nodes | grep -v NAME | wc -l")
    echo "Node Count Value was ${NODE_COUNT}"
}

restart_all_nodes () {
    echo "Restart k3s server/agent services on all nodes"
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

get_k3s_status () {
    # $1 Node_IP $2 "SKIP_SLEEP" string. If passed, sleep will be skipped. 
    # No input to method call, we will first sleep for 60 seconds. 
    echo "======================
    GET K3S STATUS
======================"
    if [ -z "$2" ]; then
        echo "Sleep for 60 seconds before get k3s status"; sleep 60
    else
        if echo "$2" | grep -q "SKIP"; then
            echo "SKIP sleep before get k3s status"
        else
            echo "Sleep for $2 seconds before get k3s status"; sleep "$2"
        fi 
    fi
    get_nodes "$1"
    get_pods "$1"
}

# take_snapshot () {
#     if [ -z "${S3_BUCKET}" ] || [ -z "${S3_ACCESS_KEY}" ] || [ -z "${S3_SECRET_KEY}" ]; then
#         echo "FATAL: Please set environment variables: S3_BUCKET, S3_ACCESS_KEY, S3_SECRET_KEY . Exiting."
#         exit
#     fi
#     echo "Take Snapshot in folder ${S3_FOLDER} for S3 Bucket: ${S3_BUCKET}"
#     TAKE_SNAPHOT_OUT_FILE="${USER_HOME}/snapshot_output_${RANDOM}"
#     # Double check we dont have s3 info in config.yaml already
#     ETCD_S3_IN_CONFIG_YAML=$(execute "grep etcd-s3 ${CONFIG_DIR}/config.yaml; echo \$?" "${SERVER1}" "SERVER1" "SKIP_LOG")
#     echo "ETCD_S3_IN_CONFIG_YAML: ${ETCD_S3_IN_CONFIG_YAML}"
#     if [ "${ETCD_S3_IN_CONFIG_YAML}" = 1 ]; then
#         execute "sudo ${PRDT} etcd-snapshot save --s3 --s3-bucket=${S3_BUCKET} --s3-folder=${S3_FOLDER} --s3-region=${S3_REGION} --s3-access-key=${S3_ACCESS_KEY} --s3-secret-key=\"${S3_SECRET_KEY}\" 2>&1 | tee -a ${TAKE_SNAPHOT_OUT_FILE}"
#     else
#         execute "sudo ${PRDT} etcd-snapshot save 2>&1 | tee -a ${TAKE_SNAPHOT_OUT_FILE}" 
#     fi
#     # execute "sudo k3s etcd-snapshot save --s3 --s3-bucket=${S3_BUCKET} --s3-folder=${S3_FOLDER} --s3-region=${S3_REGION} --s3-access-key=${S3_ACCESS_KEY} --s3-secret-key=\"${S3_SECRET_KEY}\" &> ${TAKE_SNAPHOT_OUT_FILE}"
#     # execute "cat ${TAKE_SNAPHOT_OUT_FILE}"
#     CLUSTER_RESET_RESTORE_PATH=$(execute "grep \"S3 upload complete for\"  \"${TAKE_SNAPHOT_OUT_FILE}\" | awk '{ print \$7}' | sed 's/\"//g'" "${SERVER1}" "SERVER1" "SKIP_LOG")
#     echo "Etcd Snapshot Path: ${CLUSTER_RESET_RESTORE_PATH}"
# }

# restore_cluster_from_snapshot () {
#     if [ -z "${CLUSTER_RESET_RESTORE_PATH}" ]; then
#         # If a snapshot file name not found already, take snapshot and get the same, before running restore.
#         take_snapshot
#     fi
#     if [ -z "${TOKEN}" ]; then
#         echo "FATAL: Please set environment variables: TOKEN . Exiting."
#         exit
#     fi
#     RESTORE_OUT_FILE="${USER_HOME}/cluster_reset_output${RANDOM}"
#     execute "sudo ${PRDT} server --cluster-reset --etcd-s3 \
# --cluster-reset-restore-path=${CLUSTER_RESET_RESTORE_PATH} \
# --etcd-s3-bucket=${S3_BUCKET} --etcd-s3-folder=${S3_FOLDER} --etcd-s3-region=${S3_REGION} \
# --etcd-s3-access-key=${S3_ACCESS_KEY} --etcd-s3-secret-key=\"${S3_SECRET_KEY}\" \
# --token=${TOKEN} --debug 2>&1 | tee -a ${RESTORE_OUT_FILE}"
#     # execute "cat ${RESTORE_OUT_FILE}"
# }

take_snapshot () {
    # $1 snapshot_type: local | s3
    echo "====================
    TAKE SNAPSHOT
===================="
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
        execute "sudo ${PRDT} etcd-snapshot save --s3 --s3-bucket=${S3_BUCKET} \
--s3-folder=${S3_FOLDER} \
--s3-region=${S3_REGION} \
--s3-access-key=${S3_ACCESS_KEY} \
--s3-secret-key=\"${S3_SECRET_KEY}\" --debug 2>&1 | tee -a ${OUT_FILE}"
    else
        execute "sudo ${PRDT} etcd-snapshot save --debug 2>&1 | tee -a ${OUT_FILE}"
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
    # execute "${KUBECTL} get cm -n kube-system ${PRDT}-etcd-snapshots" "${NODE_IP}" "${NODE_TYPE}"
    echo "CM Data:"; execute "${KUBECTL} get cm -n kube-system ${PRDT}-etcd-snapshots | grep etcd | awk '{print \$2}'" "${NODE_IP}" "${NODE_TYPE}"
    execute "${KUBECTL} get cm -n kube-system  | grep etcd " "${NODE_IP}" "${NODE_TYPE}"    
    echo "===================================LIST SNAPSHOTS OUTPUTS DONE==========================================="
    compare_list_snapshots_values 
}

stop_all_nodes () {
    stop  "${SERVER1}" "server"
    stop  "${SERVER2}" "server"
    stop  "${SERVER3}" "server"
    stop  "${AGENT1}" "agent"    
}

stop_start_all_nodes () {
    stop_start  "${SERVER1}" "server"
    stop_start  "${SERVER2}" "server"
    stop_start  "${SERVER3}" "server"
    stop_start  "${AGENT1}" "agent"    
}

restart_all_nodes () {
    restart  "${SERVER1}" "server"
    restart  "${SERVER2}" "server"
    restart  "${SERVER3}" "server"
    restart  "${AGENT1}" "agent"    
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
}

uninstall_all_nodes () {
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
        cluster_init
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

install_actions () {
    echo "==============================================
        STAGE: INSTALL ACTIONS
=============================================="
    if [ "${SPLIT_INSTALL}" = false ]; then
        if [ "${VERSION}" ]; then
            install_k3s_on_all_nodes "version" "${VERSION}"        
        else
            install_k3s_on_all_nodes "commit" "${COMMIT}"
        fi
    else
        if [ "${VERSION}" ]; then
            install_k3s_on_setup1 "version" "${VERSION}"
        else
            install_k3s_on_setup1 "commit" "${COMMIT}"
        fi
        if [ "${VERSION2}" ]; then
            install_k3s_on_setup2 "version" "${VERSION2}"
        else
            install_k3s_on_setup2 "commit" "${COMMIT2}"
        fi        
    fi
}

post_install_actions () {
    echo "=========================================================
    STAGE: POST INSTALL - GET STATUS, APPLY WORKLOAD
========================================================="    
    get_nodes "${SERVER1}"
    get_pods "${SERVER1}"
    if [ "${SPLIT_INSTALL}" = true ]; then 
        get_nodes "${SERVER2}"
        get_pods "${SERVER2}"
    fi
    if [ "${APPLY_WORKLOAD}" = true ]; then
        apply_workload "${SERVER1}" "SERVER1"
        if [ "${SPLIT_INSTALL}" = true ] ; then
            apply_workload "${SERVER2}" "SERVER2"
        fi
    fi
}

reinstall () {
    if [ "${REINSTALL}" = true ]; then    
        cleanup_configs
        uninstall_all_nodes
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

#############################################################################
#   INSTALL STARTS HERE
ssh_keyscan
prep_slemicro
install_3rd_party_tools
reinstall

# Tests begin

copy_over_test_yamls

if [ "${SUC_UPGRADE}" = true ]; then
    echo "==============================================
                TEST: SUC UPGRADE 
=============================================="
    echo "STEPS:
    1. Install System Upgrade Controller
    2. Apply clusterip workload
    3. Apply upgrade plan.yaml
    4. Get Status of nodes and pods 3 times with 1 min sleep"
    VERSION2=$(echo "${VERSION2}" | sed 's/+/-/g' )
    echo "VERSION2 id now: ${VERSION2}"
    install_suc
    echo "Sleep for 10 seconds"; sleep 10
    # shellcheck disable=SC2119
    apply_workload
    apply_auto_upgrade_plan
    get_nodes_pods_status
    get_nodes_pods_status
    get_nodes_pods_status
fi

if [ "${MANUAL_UPGRADE}" = true ]; then
    echo "==============================================
            TEST: MANUAL_UPGRADE 
=============================================="
    EXEC=true
    apply_workload
    if [ "${COMMIT2}" ]; then
        install_k3s_on_all_nodes "commit" "${COMMIT2}"
    else
        install_k3s_on_all_nodes "version" "${VERSION2}"
    fi
    get_nodes_pods_status
    echo "Expect Pods running for default namespace:"    
    get_pods_for_ns "default" "${SERVER1}" 
fi

if [ "${NODE_REPLACEMENT}" = true ]; then
    echo "==============================================
            TEST: NODE REPLACEMENT
=============================================="
    apply_workload    
    get_node_names
    if [ "${COMMIT2}" ]; then 
        replace_nodes "commit" "${COMMIT2}"
    else
        replace_nodes "version" "${VERSION2}"
    fi
    get_nodes_pods_status
    echo "Expect Pods running for default namespace:"    
    get_pods_for_ns "default" "${SERVER1}"     
fi

if [ "${CERT_ROTATE}" = true ]; then
    echo "==============================================
            TEST: CERTIFICATE ROTATE
=============================================="
    echo "Steps: 
1. Stop k3s service 
2. Perform certificate rotate
3. Start k3s service
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
    get_nodes_pods_status    
fi

if [ "${SECRETS_ENCRYPT_TEST}" = true ]; then
    echo "==============================================
            TEST: SECRETS ENCRYPT
=============================================="
    get_node_names
    delete_node "${HOSTNAME3}" "SERVER3" "${SERVER1}" "SERVER1"
    install_etcdctl "${SERVER1}"
    hexdump  # Displays empty value
    create_secret
    hexdump  # Displays the hexdump
    secret_encrypt_status
    secret_encrypt_prepare
    restart_all_nodes
    secret_encrypt_rotate
    restart_all_nodes
    secret_encrypt_reencrypt
    restart_all_nodes
    hexdump  # Displays hexdump with timestamp
    echo "NOTE: Expect (1 node lesser than the previous post-install output) 2 servers and 1 agent below:"
    get_nodes_pods_status    
fi

if [ "${DOCKER_CRI}" = true ]; then
    echo "==============================================
            TEST: DOCKER CRI
=============================================="
    # shellcheck disable=SC2119
    apply_workload
    get_nodes_pods_status
    echo "Expect Pods running for default namespace:"    
    get_pods_for_ns "default" "${SERVER1}"   
fi

if [ "${CLUSTER_RESET}" = true ]; then
    echo "==============================================
            TEST: CLUSTER RESET
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
    # Killall script for Server 2 and 3
    echo "========= STEP1: Kill All Script run for Servers 2 and 3 ========= "
    execute "sudo ${PRDT}-killall.sh" "${SERVER2}" "SERVER2"
    execute "sudo ${PRDT}-killall.sh" "${SERVER3}" "SERVER3"
    echo "Status should not be available - K3S cluster should be down"
    get_k3s_status "SKIP_SLEEP"
    # Shut down k3s on server1
    echo "========= STEP2: Kill ${PRDT} server for SERVER1 ========= "
    stop "${SERVER1}" "server"
    # Run Cluster Reset
    echo "========= STEP3: CLUSTER RESET ========="
    execute "sudo ${PRDT} server --cluster-reset" "${SERVER1}" "SERVER1"
    # Restart k3s server1
    echo "========= STEP4: RESTART ${PRDT} SERVER1 ========="    
    start "${SERVER1}" "server"
    echo "Sleep for 60 seconds"; sleep 60
    get_k3s_status
    # Remove db directories 
    echo "========= STEP5: DELETE DB DIRECTORIES ========="     
    execute "sudo mv ${DB_PATH} ${DB_PATH_BACKUP}" "${SERVER2}" "SERVER2" 
    execute "sudo mv ${DB_PATH} ${DB_PATH_BACKUP}" "${SERVER3}" "SERVER3"
    # Restart servers 2 and 3
    echo "========= STEP6: RESTART Servers 2 and 3 ========="      
    start "${SERVER2}" "server"
    echo "Sleep for 60 seconds"; sleep 60
    start "${SERVER3}" "server"
    echo "Sleep for 60 seconds"; sleep 60
    stop_start "${AGENT1}" "agent"
    echo "Sleep for 60 seconds"; sleep 60    
    get_k3s_status
    echo "No resources will be listed: "
    get_pods_for_ns "clusterip" "${SERVER1}"
    echo "No resources will be listed: "    
    get_pods_for_ns "clusterip-2" "${SERVER1}"
    echo "Expect Pods to be listed for default namespace: "    
    get_pods_for_ns "default" "${SERVER1}"
    echo "========= STEP7: Deploy more workloads and verify status =========" 
    execute "${KUBECTL} apply -f ${WORKLOADS_GH_MORE}" "${SERVER1}" "SERVER1"
    verify_nodeport
    get_services
    get_ingress
fi


if [ "${CLUSTER_RESET_WITH_RESTORE}" = true ]; then
    echo "==============================================
            TEST: CLUSTER RESET WITH RESTORE FROM SNAPSHOT
            (Using killall script and db delete)
            Steps: 
            1) Using the killall script Stop two server nodes (Server 2 and 3)
            2) Shut down the server on the remaining node - Server1
            3) Run cluster-reset with restore from s3 or local snapshot
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
    get_k3s_status "SKIP_SLEEP"
    
    # Shut down k3s on server1
    echo "========= STEP2: Kill ${PRDT} server for SERVER1 ========= "
    stop "${SERVER1}" "server"
    # Run Cluster Reset

    echo "========= STEP3: CLUSTER RESET WITH RESTORE PATH ========="
    # execute "sudo ${PRDT} server --cluster-reset" "${SERVER1}" "SERVER1"
    restore_cluster_from_snapshot "${RESTORE_FROM_S3_OR_LOCAL}"
    # Restart k3s server1
    echo "========= STEP4: RESTART ${PRDT} SERVER1 ========="    
    start "${SERVER1}" "server"
    echo "Sleep for 60 seconds"; sleep 60
    get_k3s_status
    # Remove db directories 
    echo "========= STEP5: DELETE DB DIRECTORIES ========="     
    execute "sudo mv ${DB_PATH} ${DB_PATH_BACKUP}" "${SERVER2}" "SERVER2" 
    execute "sudo mv ${DB_PATH} ${DB_PATH_BACKUP}" "${SERVER3}" "SERVER3"
    # Restart servers 2 and 3
    echo "========= STEP6: RESTART Servers 2 and 3 ========="      
    start "${SERVER2}" "server"
    echo "Sleep for 60 seconds"; sleep 60
    start "${SERVER3}" "server"
    echo "Sleep for 60 seconds"; sleep 60
    stop_start "${AGENT1}" "agent"
    echo "Sleep for 60 seconds"; sleep 60    
    get_k3s_status
    echo "No resources will be listed: "
    get_pods_for_ns "clusterip" "${SERVER1}"
    echo "No resources will be listed: "    
    get_pods_for_ns "clusterip-2" "${SERVER1}"
    echo "Expect Pods to be listed for default namespace: "    
    get_pods_for_ns "default" "${SERVER1}"
    echo "========= STEP7: Deploy more workloads and verify status =========" 
    execute "${KUBECTL} apply -f ${WORKLOADS_GH_MORE}" "${SERVER1}" "SERVER1"
    verify_nodeport
    get_services
    get_ingress
fi

if [ "${CLUSTER_RESET_RESTORE_PATH_TEST}" = true ]; then
    echo "========================================================
    TEST: CLUSTER RESET RESTORE PATH (ETCD SNAPSHOT) 
    Using UNINSTALL k3s cluster for getting a new VM.
    Steps:
    1) Create workload with namespace 'clusterip'
    2) Take Snapshot to s3
    3) Deploy more workloads - with namespace 'clusterip-2'
    4) Stop all nodes in cluster
    5) Create a new VM: UNINSTALL server1 and install with skip_enable service
    6) Restore from the saved snapshot and start server1
    7) Delete the db on server 2 and 3; Restart services and let them join server1
    8) Check if pods are running for namespace 'clusterip' and NOT running for 'clusterip-2' namespace
    9) Create more workloads and check if they work fine. 
========================================================"
    echo "====== STEP1: Create workload with clusterip namespace ======"
    apply_workload "${SERVER1}" "SERVER1" "clusterip"
    echo "====== STEP2: Take Snapshot ======"
    take_snapshot    
    echo "====== STEP3: Apply workload with clusterip-2 namespace ======"
    apply_workload "${SERVER1}" "SERVER1" "clusterip-2"
    echo "====== STEP4: Stop all nodes in cluster ======"
    stop_all_nodes
    echo "====== STEP5: Create new VM: Uninstall and install with skip enable service option"
    uninstall "${SERVER1}" "SERVER1"
    echo "Sleep 60"; sleep 60
    execute "sudo apt install net-tools" "${SERVER1}" "SERVER1"
    execute "netstat | grep 6443; sudo netstat | grep 6443" "${SERVER1}" "SERVER1"
    install_k3s "version" "${VERSION}" "${SERVER1}" "server" "SKIP_ENABLE"
    execute "netstat | grep 6443; sudo netstat | grep 6443" "${SERVER1}" "SERVER1"
    echo "====== STEP6: Restore from saved snapshot ======"
    restore_cluster_from_snapshot
    echo "====== STEP6a: Start K3S Service on SERVER1 ======"
    start "${SERVER1}" "server"
    echo "Sleep for 60 seconds"; sleep 60
    get_k3s_status
    echo "====== STEP7: Delete db on server2 and 3; and start them back up to join server1"
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
    get_k3s_status
    echo "====== STEP8: Expect Pods running for clusterip namespace ======"
    get_pods_for_ns "clusterip" "${SERVER1}"
    echo "====== STEP8a: No resources/pods should be running for clusterip-2 namespace:"
    get_pods_for_ns "clusterip-2" "${SERVER1}"
    echo "Expect Pods running for default namespace:"    
    get_pods_for_ns "default" "${SERVER1}"
    echo "========= STEP9: Deploy more workloads and verify status =========" 
    execute "${KUBECTL} apply -f ${WORKLOADS_GH_MORE}" "${SERVER1}" "SERVER1"
    verify_nodeport
    get_services
    get_ingress    
fi

if [ "${RESTART_SERVICES}" = true ]; then
    echo "===============================
    TEST: RESTART SERVICES
==============================="
    stop_start_all_nodes
    echo "Sleep for 60"; sleep 60
    get_k3s_status
    echo "Sleep for 60"; sleep 60
    get_k3s_status
    echo "Sleep for 60"; sleep 60
    apply_workload "${SERVER1}" "SERVER1" "clusterip"    
    echo "Expect Pods running for clusterip namespace:"
    get_pods_for_ns "clusterip" "${SERVER1}"
fi

if [ "${ETCD_SNAPSHOT_RETENTION_UPDATE_NODE_NAMES}" = true ]; then
    echo "==============================================
        ETCD SNAPSHOT RETENTION TEST
        Tests covered: 
        1) Take snapshots using cron and retention configs. (Take and Retain 2 snapshots)
        2) Rename the nodes, and test the retention still works - repeat step twice.
=============================================="
    echo "Sleep 2m"; sleep 2m
    list_snapshots
    # execute "sudo ls -lrt /var/lib/rancher/k3s/server/db/snapshots" "${SERVER1}" "SERVER1"
    # execute "sudo k3s etcd-snapshot list" "${SERVER1}" "SERVER1"    
    SUFFIX_1="${RANDOM}"
    SUFFIX_2="${RANDOM}"    
    update_node_name "${SUFFIX_1}"
    delete_old_node_names "${NODE_NAME_SERVER1}" "${NODE_NAME_SERVER2}" "${NODE_NAME_SERVER3}" "${NODE_NAME_AGENT1}" "update"
    echo "Sleep 3m"; sleep 3m
    list_snapshots    
    # execute "sudo ls -lrt /var/lib/rancher/k3s/server/db/snapshots" "${SERVER1}" "SERVER1"
    # execute "sudo k3s etcd-snapshot list" "${SERVER1}" "SERVER1"   
    update_node_name "${SUFFIX_2}"
    delete_old_node_names "${NODE_NAME_SERVER1}-${SUFFIX_1}" "${NODE_NAME_SERVER2}-${SUFFIX_1}" "${NODE_NAME_SERVER3}-${SUFFIX_1}" "${NODE_NAME_AGENT1}-${SUFFIX_1}"   
    echo "Sleep 3m"; sleep 3m
    list_snapshots  
    # execute "sudo ls -lrt /var/lib/rancher/k3s/server/db/snapshots" "${SERVER1}" "SERVER1"
    # execute "sudo k3s etcd-snapshot list" "${SERVER1}" "SERVER1"  
    # get_k3s_status "${SERVER1}" "SKIP_SLEEP"
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
    # get_k3s_status "${SERVER1}" "SKIP_SLEEP"
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

if [ "${FLANNEL_TEST}" = true ]; then
    echo "============================
    FLANNEL VERSION TEST
============================"
    execute "/var/lib/rancher/k3s/data/current/bin/flannel -v" "${SERVER1}" "SERVER1"
fi


if [ "${INSTALL_RANCHER_MANAGER}" = true ]; then
    echo "=====================================
    TEST: INSTALL RANCHER MANAGER
====================================="
    install_helm
    install_rancher
fi

if [ "${STARGZ_LOGS}" = true ];then
    execute "sudo grep snapshotter /var/lib/rancher/k3s/agent/containerd/containerd.log | grep stargz" "${SERVER1}" "SERVER1"
    execute "sudo cat /var/lib/rancher/k3s/agent/etc/containerd/config.toml | grep snapshotter" "${SERVER1}" "SERVER1"
    execute "sudo grep snapshotter /var/lib/rancher/k3s/agent/containerd/containerd.log | grep stargz" "${SERVER2}" "SERVER2"
    execute "sudo cat /var/lib/rancher/k3s/agent/etc/containerd/config.toml | grep snapshotter" "${SERVER2}" "SERVER2"    
fi

if [ "${CUSTOM_TEST}" = true ]; then
    echo "=========================================
    CUSTOM TEST: 
    Stop all k3s services
    Get kubelet output from journal logs
========================================="
    stop_all_nodes
    # execute "journalctl -xeu k3s | grep 'Running kubelet'" "${SERVER1}" "SERVER1"
    # execute "journalctl -xeu k3s | grep 'Running kubelet'" "${SERVER2}" "SERVER2"    
fi

if [ "${SANITY_TEST}" = true ]; then
    echo "=========================================
    SANITY TEST: 
    K3S Cluster Status
    Apply workload
    Test workloads
========================================="
    execute "${KUBECTL} apply -f ${WORKLOADS_GH_MORE}" "${SERVER1}" "SERVER1"
    verify_nodeport
    verify_nodeport "30097"
    get_services
    get_ingress
fi

execute "source ${USER_HOME}/k3s.source; setup"  # Outputs the setup details of SERVER1 where the test was run
if [ "${SPLIT_INSTALL}" = true ]; then
    execute "source ${USER_HOME}/k3s.source; setup" "${SERVER2}"
fi

if [ "${TEARDOWN}" = true ]; then
    cleanup_configs
    if [ "${SUC_UPGRADE}" = true ]; then
        rm -rf ${AUTO_UPGRADE_PLAN_YAML_FILE}
    fi
fi
