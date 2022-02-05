#!/bin/bash

instances="$(gcloud compute instances list --format 'value(NAME,EXTERNAL_IP)' 2>&1)"

controller=$(echo "$instances" | grep 'controller' | awk '{print $2}')
worker=$(echo "$instances" | grep 'worker' | awk '{print $2}')

read -a controller -d ' ' <<< "$controller"
read -a worker -d ' ' <<< "$worker"

if [ -f ./ansible_inventory ]; then
    rm ./ansible_inventory
fi

touch ./ansible_inventory

if [ -n "$controller" ]; then
    echo "[controller]" >> ./ansible_inventory
    for instance in ${controller[@]}; do
        echo "$instance ansible_user=$(whoami)" >> ./ansible_inventory
    done
    echo "" >> ./ansible_inventory
fi

if [ -n "$worker" ]; then
    echo "[worker]" >> ./ansible_inventory
    for instance in ${worker[@]}; do
        echo "$instance ansible_user=$(whoami)" >> ./ansible_inventory
    done
    echo "" >> ./ansible_inventory
fi