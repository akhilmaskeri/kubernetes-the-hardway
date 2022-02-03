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

function cleanup {

	local existing_instances="$(gcloud compute instances list 2>&1)"
	local running_instances=""
	for i in 0 1 2; do

		if grep -q -E "controller-${i}" <<< "$existing_instances"; then
			running_instances="$running_instances controller-${i}"
		fi

		if grep -q -E "worker-${i}" <<< "$existing_instances"; then
			running_instances="$running_instances worker-${i}"
		fi
	done
	if [ -n "$running_instances" ]; then
		gcloud compute instances delete $running_instances
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

	local existing_instances=$(gcloud compute instances list)
	
	for i in 0 1 2; do

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

	done

}

# network_exists
# subnet_exists
# firewall_rule_exists
# static_ip_exists
# compute_instances_exist

# cleanup

function print_help {
	echo "options"
	echo "    -create    to create the cluster"
	echo "    -remove    to remove the cluster"
}

if [ "$#" -eq "1" ]; then
	option=$1
	if [ "$option" == "-create" ]; then
		network_exists
		subnet_exists
		firewall_rule_exists
		static_ip_exists
		compute_instances_exist
	elif [ "$option" == "-remove" ]; then
		echo "Cleaning up"
		cleanup
	else
		print_help
	fi
else
	print_help
fi
