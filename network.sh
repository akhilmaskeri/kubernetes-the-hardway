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

	local existing_firewall_rules="$(gcloud compute firewall-rules list --filter=network:$NETWORK_NAME)"
	if grep -q "$FIREWALL_RULE_INTERNAL" <<< "$existing_firewall_rules"; then
		yes | gcloud compute firewall-rules delete $FIREWALL_RULE_INTERNAL
	fi
	if grep -q "$FIREWALL_RULE_EXTERNAL" <<< "$existing_firewall_rules"; then
		yes | gcloud compute firewall-rules delete $FIREWALL_RULE_EXTERNAL
	fi


	local existing_subnets="$(gcloud compute networks subnets list --network $NETWORK_NAME)"
	if grep -q -E "$NETWORK_NAME\s+$SUBNET_RANGE" <<<  $existing_subnets; then
		yes | gcloud compute networks subnets delete $SUBNET_NAME
	fi


	local existing_networks="$(gcloud compute networks list)"
	if grep -q "$NETWORK_NAME" <<< $existing_networks; then
		yes | gcloud compute networks delete $NETWORK_NAME		
	fi

	local existing_addresses="$(gcloud compute addresses list --regions $REGION)"
	if grep -q "$PUBLIC_IP" <<< "$existing_addresses"; then
		yes | gcloud compute addresses delete "$PUBLIC_IP" 
	fi

}


function static_ip_exists {

	local existing_addresses="$(gcloud compute addresses list --regions $REGION)"
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

	### check if the firewall rule exists
	local existing_firewall_rules="$(gcloud compute firewall-rules list --filter=network:$NETWORK_NAME)"

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

	### check if the subnet exists
	local existing_subnets="$(gcloud compute networks subnets list --network $NETWORK_NAME)"

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

	###  check if the network exists
	local existing_networks="$(gcloud compute networks list)"

	if grep -q "$NETWORK_NAME" <<< $existing_networks; then
		echo "$NETWORK_NAME Network exists"	
	else
		echo "\"$NETWORK_NAME\" does not exist -- creating"
		gcloud compute networks create "$NETWORK_NAME" --subnet-mode custom
	fi

}


#network_exists
#subnet_exists
#firewall_rule_exists
#static_ip_exists

#cleanup
