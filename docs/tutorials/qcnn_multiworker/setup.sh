# Copyright 2021 The TensorFlow Quantum Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

#!/usr/bin/env bash

# Update the configuration section prior to running commands in this script.
#
# Usage:
#   setup.sh infra - Sets up the Google Cloud infrastructure for the tutorial.
#   setup.sh fill  - Fills in templated parameters in tutorial files using
#                    values set in this script.

### BEGIN configuration

CLUSTER_NAME="qcnn-multiworker"
PROJECT="some-gcp-project"
NUM_NODES=2
SERVICE_ACCOUNT_NAME="qcnn-sa"

ZONE="us-west1-a"
GCS_REGION="us-west1"
# Bucket name must be globally unique.
BUCKET_NAME="some-gcp-project-qcnn-multinode"
LOGDIR_NAME="qcnn-logdir"
IMAGE_REGISTRY="gcr.io\/${PROJECT}\/qcnn:latest"

### END configuration

# Set up Google Cloud infrastructure
infra () {
  gcloud config set project ${PROJECT}

  gcloud container clusters create ${CLUSTER_NAME}   \
    --workload-pool=${PROJECT}.svc.id.goog   \
    --num-nodes=${NUM_NODES}   \
    --zone=${ZONE}

  gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME}
  gcloud iam service-accounts add-iam-policy-binding   \
    --role roles/iam.workloadIdentityUser   \
    --member "serviceAccount:${PROJECT}.svc.id.goog[default/${SERVICE_ACCOUNT_NAME}]"   \
    ${SERVICE_ACCOUNT_NAME}@${PROJECT}.iam.gserviceaccount.com

  gsutil mb -p ${PROJECT} -l ${GCS_REGION} -b on gs://${BUCKET_NAME}
  gsutil iam ch serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT}.iam.gserviceaccount.com:roles/storage.admin gs://${BUCKET_NAME}

  kubectl apply -f https://raw.githubusercontent.com/kubeflow/tf-operator/v1.0.1-rc.1/deploy/v1/tf-operator.yaml
}

# Fill in templated parameters.
fill_parameters () {
  sed -i -- "s/<image_registry>/${IMAGE_REGISTRY}/g" Makefile
  find . -type f -name "*.yaml" -exec sed -i "s/<project>/${PROJECT}/g" {} +
  find . -type f -name "*.yaml" -exec sed -i "s/<bucket_name>/${BUCKET_NAME}/g" {} +
  find . -type f -name "*.yaml" -exec sed -i "s/<service_account>/${SERVICE_ACCOUNT_NAME}/g" {} +
  find . -type f -name "*.yaml" -exec sed -i "s/<image_registry>/${IMAGE_REGISTRY}/g" {} +
  find . -type f -name "*.yaml" -exec sed -i "s/<logdir_name>/${LOGDIR_NAME}/g" {} +
}

case $1 in
  "infra" )
    infra;;
  "fill" )
    fill_parameters;;
esac