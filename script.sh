#!/bin/bash

PROJECT="k8-the-hard-way"

REGION="asia-south1"
ZONE="asia-south1-c"

NETWORK_NAME="$PROJECT-vpc-network"
SUBNET_NAME="$PROJECT-$REGION"
SUBNET_RANGE="10.240.0.0/24"
PUBLIC_IP="$PROJECT-lb-ip"

FIREWALL_RULE_INTERNAL="$PROJECT-allow-internal"
FIREWALL_RULE_EXTERNAL="$PROJECT-allow-external"
FIREWALL_RULE_HEALTH_CHECK="$PROJECT-allow-health-check"

FORWARDING_RULE="$PROJECT-forwarding-rule"
TARGET_POOL="$PROJECT-target-pool"
HTTP_HEALTH_CHECK="$PROJECT-http-health-check"

function cleanup {

	decomission_pod_network_route
	decomission_lb

	local existing_instances="$(gcloud compute instances list 2>&1)"
	local running_instances=""
	for i in 0 1; do

		if grep -q -E "controller-${i}" <<< "$existing_instances"; then
			running_instances="$running_instances controller-${i}"
		fi

		if grep -q -E "worker-${i}" <<< "$existing_instances"; then
			running_instances="$running_instances worker-${i}"
		fi
	done
	if [ -n "$running_instances" ]; then
		gcloud compute instances delete -q $running_instances
	fi

	local existing_firewall_rules="$(gcloud compute firewall-rules list --filter=network:$NETWORK_NAME 2>&1)"
	if grep -q "$FIREWALL_RULE_INTERNAL" <<< "$existing_firewall_rules"; then
		echo "deleting \"$FIREWALL_RULE_INTERNAL\""
		gcloud compute firewall-rules delete -q $FIREWALL_RULE_INTERNAL
	fi
	if grep -q "$FIREWALL_RULE_EXTERNAL" <<< "$existing_firewall_rules"; then
		echo "deleting \"$FIREWALL_RULE_EXTERNAL\""
		gcloud compute firewall-rules delete -q $FIREWALL_RULE_EXTERNAL
	fi

	local existing_subnets="$(gcloud compute networks subnets list --network $NETWORK_NAME 2>&1)"
	if grep -q -E "$NETWORK_NAME\s+$SUBNET_RANGE" <<<  $existing_subnets; then
		echo "deleting \"$SUBNET_NAME\""
		gcloud compute networks subnets delete -q $SUBNET_NAME
	fi


	local existing_networks="$(gcloud compute networks list 2>&1)"
	if grep -q "$NETWORK_NAME" <<< $existing_networks; then
		echo "deleting \"$NETWORK_NAME\""
		gcloud compute networks delete -q $NETWORK_NAME		
	fi

	local existing_addresses="$(gcloud compute addresses list --regions $REGION 2>&1)"
	if grep -q "$PUBLIC_IP" <<< "$existing_addresses"; then
		echo "deleting \"$PUBLIC_IP\""
		gcloud compute addresses delete -q "$PUBLIC_IP" 
	fi

}


function static_ip_exists {

	### make sure the network ip exists
	local existing_addresses="$(gcloud compute addresses list --regions $REGION 2>&1)"
	if grep -q "$PUBLIC_IP" <<< "$existing_addresses"; then
		echo "$PUBLIC_IP ip exists" 
	else
		echo ""
		echo "$PUBLIC_IP does not exist"
		echo "creating address $PUBLIC_IP"
		gcloud compute addresses create "$PUBLIC_IP" --region $REGION
		echo ""
	fi

}


function firewall_rule_exists {

	### make sure the firewall rule exists
	local existing_firewall_rules="$(gcloud compute firewall-rules list --filter=network:$NETWORK_NAME 2>&1)"

	if grep -q "$FIREWALL_RULE_INTERNAL" <<< "$existing_firewall_rules"; then
		echo "$FIREWALL_RULE_INTERNAL firewall rule exists"  
	else
		echo ""
		echo "$FIREWALL_RULE_INTERNAL does not exist"
		echo "creating firewall rule $FIREWALL_RULE_INTERNAL"
		echo ""
		gcloud compute firewall-rules create $FIREWALL_RULE_INTERNAL \
			--allow tcp,udp,icmp \
			--network "$NETWORK_NAME" \
			--source-ranges 10.240.0.0/24,10.200.0.0/16
		echo ""
	fi


	if grep -q "$FIREWALL_RULE_EXTERNAL" <<< "$existing_firewall_rules"; then
		echo "$FIREWALL_RULE_EXTERNAL firewall rule exists"  
	else
		echo ""
		echo "$FIREWALL_RULE_EXTERNAL does not exist"
		echo "creating firewall rule $FIREWALL_RULE_EXTERNAL"
		echo ""
		gcloud compute firewall-rules create $FIREWALL_RULE_EXTERNAL \
			--allow tcp:22,tcp:6443,icmp \
			--network "$NETWORK_NAME" \
			--source-ranges 0.0.0.0/0 
		echo ""
	fi

}


function subnet_exists {

	### make sure the subnet exists
	local existing_subnets="$(gcloud compute networks subnets list --network $NETWORK_NAME 2>&1)"

	if grep -q -E "$NETWORK_NAME\s+$SUBNET_RANGE" <<<  $existing_subnets; then
		echo "$NETWORK_NAME $SUBNET_RANGE Subnet exists"
	else
		echo "$NETWORK_NAME $SUBNET_RANGE -- Subnet does not exist -- creating"
		gcloud compute networks subnets create $SUBNET_NAME \
			--network "$NETWORK_NAME" \
			--range "$SUBNET_RANGE"
	fi
}


function network_exists {

	###  make sure the network exists
	local existing_networks="$(gcloud compute networks list)"

	if grep -q "$NETWORK_NAME" <<< $existing_networks; then
		echo "$NETWORK_NAME Network exists"	
	else
		echo "\"$NETWORK_NAME\" does not exist -- creating"
		gcloud compute networks create "$NETWORK_NAME" --subnet-mode custom
	fi

}


function compute_instances_exist {

	local existing_instances="$(gcloud compute instances list 2>&1)"
	
	for i in 0 1; do

		if grep -q -E "controller-${i}" <<< $existing_instances; then
			echo "controller-${i} exists"
	 	else	
			echo "creating controller-${i}"
			gcloud compute instances create controller-${i} \
			    --async \
			    --boot-disk-size 200GB \
			    --can-ip-forward \
			    --image-family ubuntu-2004-lts \
			    --image-project ubuntu-os-cloud \
			    --machine-type e2-standard-2 \
			    --private-network-ip 10.240.0.1${i} \
			    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
			    --subnet $SUBNET_NAME \
			    --tags $PROJECT,controller
		fi


		if grep -q -E "worker-${i}" <<< $existing_instances; then
			echo "worker-${i} exists"
		else
			echo "creating worker-${i}"
			gcloud compute instances create worker-${i} \
			    --async \
			    --boot-disk-size 200GB \
			    --can-ip-forward \
			    --image-family ubuntu-2004-lts \
			    --image-project ubuntu-os-cloud \
			    --machine-type e2-standard-2 \
			    --metadata pod-cidr=10.200.${i}.0/24 \
			    --private-network-ip 10.240.0.2${i} \
			    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
			    --subnet $SUBNET_NAME \
			    --tags $PROJECT,worker
		fi

		echo ""
	done

}

function decomission_lb {

	local existing_forwarding_rule="$(gcloud compute forwarding-rules list 2>&1)"
	local existing_target_pool="$(gcloud compute target-pools list 2>&1)"
	local existing_firewall_rules="$(gcloud compute firewall-rules list --filter=network:$NETWORK_NAME 2>&1)"
	local existing_http_health_checks="$(gcloud compute http-health-checks list 2>&1)"

	if grep -q "$FORWARDING_RULE" <<< $existing_forwarding_rule; then
		echo "Deleting forwarding rule \"$FORWARDING_RULE\""
		gcloud compute forwarding-rules delete -q "$FORWARDING_RULE"
	fi

	if grep -q "$TARGET_POOL" <<< "$existing_target_pool"; then
		echo "Deleting target pool \"$TARGET_POOL\""
		gcloud compute target-pools delete -q $TARGET_POOL
	fi		

	if grep -q "$FIREWALL_RULE_HEALTH_CHECK" <<< "$existing_firewall_rules"; then
		echo "Deleting health check firewall rule \"$FIREWALL_RULE_HEALTH_CHECK\""
		gcloud compute firewall-rules delete -q $FIREWALL_RULE_HEALTH_CHECK
	fi

	if grep -q "$HTTP_HEALTH_CHECK" <<< "$existing_http_health_checks"; then
		echo "Deleting http health checks \"$HTTP_HEALTH_CHECK\""
		gcloud compute http-health-checks delete -q "$HTTP_HEALTH_CHECK"
	fi

}

function lb_exists {

	KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe ${PUBLIC_IP} \
		--region $REGION \
		--format 'value(address)')

	local existing_forwarding_rule="$(gcloud compute forwarding-rules list 2>&1)"
	local existing_target_pool="$(gcloud compute target-pools list 2>&1)"
	local existing_firewall_rules="$(gcloud compute firewall-rules list --filter=network:$NETWORK_NAME 2>&1)"
	local existing_http_health_checks="$(gcloud compute http-health-checks list 2>&1)"

	if grep -q "$HTTP_HEALTH_CHECK" <<< "$existing_http_health_checks"; then
		echo "http health check \"$HTTP_HEALTH_CHECK\" exists"
	else
		echo "Creating health check \"$HTTP_HEALTH_CHECK\" ..."
		gcloud compute http-health-checks create $HTTP_HEALTH_CHECK \
			--description "Kubernetes Health Check" \
			--host "kubernetes.default.svc.cluster.local" \
			--request-path "/healthz"
	fi

	if grep -q "$FIREWALL_RULE_HEALTH_CHECK" <<< "$existing_firewall_rules"; then
		echo "Firewall rule \"$FIREWALL_RULE_HEALTH_CHECK\" exists"
	else
		echo "Creating firewall-rule \"$FIREWALL_RULE_HEALTH_CHECK\" ..."
		gcloud compute firewall-rules create $FIREWALL_RULE_HEALTH_CHECK \
			--network $NETWORK_NAME \
			--source-ranges 209.85.152.0/22,209.85.204.0/22,35.191.0.0/16 \
			--allow tcp
	fi

	if grep -q "$TARGET_POOL" <<< "$existing_target_pool"; then
		echo "Http Target Pool \"$TARGET_POOL\" exists"
	else
		echo "Creating target-pool \"$TARGET_POOL\"..."
		gcloud compute target-pools create $TARGET_POOL \
			--http-health-check $HTTP_HEALTH_CHECK

		gcloud compute target-pools add-instances $TARGET_POOL \
			--instances controller-0,controller-1
		
	fi		

	if grep -q "$FORWARDING_RULE" <<< "$existing_forwarding_rule"; then
		echo "Forwarding rule \"$FORWARDING_RULE\" exists"
	else
		echo "Creating forwarding-rules \"$FORWARDING_RULE\"..."
		gcloud compute forwarding-rules create $FORWARDING_RULE \
			--address ${KUBERNETES_PUBLIC_ADDRESS} \
			--ports 6443 \
			--region $REGION \
			--target-pool $TARGET_POOL
	fi

}

function provision_pod_network_route {


	for i in 0 1; do
		gcloud compute routes create $PROJECT-route-10-200-${i}-0-24 \
			--network $NETWORK_NAME \
			--next-hop-address 10.240.0.2${i} \
			--destination-range 10.200.${i}.0/24
	done

}

function decomission_pod_network_route {
	for i in $(seq 0 1); do
		gcloud compute routes delete -q $PROJECT-route-10-200-${i}-0-24
	done
}


function wait_till_ssh {

	# check if all are accessible through ssh
	external_ip="$(gcloud compute instances list --format 'value(EXTERNAL_IP)')"
	read -a external_ip -d '\n' <<< "$external_ip"

	accessible=0
	for IP in ${external_ip[@]}; do

		while true; do		
			if nc -w 1 -z $IP 22 2>&1; then
				accessible=$((accessible+1))
				break
			else
				echo "$IP not reachable"
				sleep 2
			fi
		done
		
	done

	if [ "$accessible" -eq "${#external_ip[@]}" ]; then
		echo "All instances are accessible by ssh"
	fi

}

function print_help {
	echo "options"
	echo "    -provision       to create the cluster"
	echo "    -copy-keys       to copy certificates to instances"
	echo "    -decommission    to remove the cluster"
}

if [ "$#" -gt "0" ]; then

	option=$1

	if [ "$option" == "-provision" ]; then

		network_exists
		subnet_exists
		firewall_rule_exists
		static_ip_exists
		compute_instances_exist

	elif [ "$option" == "-provision_lb" ]; then
		lb_exists

	elif [ "$option" == "-decomission_lb" ]; then
		decomission_lb

	elif [ "$option" == "-copy-keys" ]; then

		wait_till_ssh

		if [ -d ./ssl ]; then
			rm -rf ./ssl/
		fi

		bash create-certificate.sh
		bash create-encryption-key.sh
		bash create-kubeconfig.sh

		bash copy-ssh-key.sh
		bash generate-inventory.sh

	elif [ "$option" == "-bootstrap" ]; then

		export ANSIBLE_HOST_KEY_CHECKING=False
		
		rm ~/.ssh/known_hosts

		provision_lb

		ansible-playbook -i ansible_inventory playbooks/bootstrap-etcd.yaml
		ansible-playbook -i ansible_inventory playbooks/bootstrap-controllers.yaml
		ansible-playbook -i ansible_inventory playbooks/bootstrap-workers.yaml

	elif [ "$option" == "-provision_pod_route" ]; then
		provision_pod_network_route

	elif [ "$option" == "-decomission_pod_route" ]; then
		decomission_pod_network_route

	elif [ "$option" == "-decommission" ]; then
		echo "Decommissioning"
		cleanup
	else
		print_help
	fi

else
	print_help
fi
