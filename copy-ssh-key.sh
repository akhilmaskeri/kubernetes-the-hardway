#!/bin/bash

PROJECT="k8-the-hard-way"
hosts=$(gcloud compute instances list --filter="tags.items=${PROJECT}" --format 'value(NAME)')
read -a hosts -d '\' <<< "$hosts"

id_rsa_pub="$(cat ~/.ssh/id_rsa.pub)"

for host in ${hosts[@]}; do
    gcloud compute ssh ${host} --command="echo \"$id_rsa_pub\" >> ~/.ssh/authorized_keys"
done