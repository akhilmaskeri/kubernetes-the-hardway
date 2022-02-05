#!/bin/bash

if [ ! -d ./ssl/ ]; then
    echo "./ssl/ folder does not exists"
    echo "please run the create-certificate.sh script"
    exit 1
fi

pushd ./ssl/

ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

for i in 0 1; do
    instance="controller-${i}"
    gcloud compute scp encryption-config.yaml ${instance}:~/
done