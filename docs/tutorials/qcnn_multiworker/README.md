# QCNN Multi-Worker Training on Kubernetes

## Setup

The following variables are used in commands below:
* `${CLUSTER_NAME}`: your Kubernetes cluster name on Google Kubernetes Engine.
* `${PROJECT}`: your Google Cloud project ID.
* `${NUM_NODES}`: the number of VMs in your cluster. I used 3 in my experiments, but less should work as well.
* `${LOCATION}`: Google Cloud location for Google Cloud Storage bucket. This is recommended to be the same default location in your `gcloud` setup, as part of the Google Kubernetes Engine setup procedure.
* `${BUCKET_NAME}`: Name of the Google Cloud Storage bucket for storing training output. Example: `qcnn-multiworker`.

---

* Set parameters in Kubernetes YAML files
  * Look for parameters surrounded by `<>` in
    * `Makefile`
    * `common/sa.yaml`
    * `training/qcnn.yaml`
    * `inference/qcnn_inference.yaml`
* Set up Google Container Registry: https://cloud.google.com/container-registry/docs/quickstart
  * This is for storing Docker images. Other non-Google container registries recognized by Docker works as well.
* Google Kubernetes Engine (GKE) setup: follow the quick start guide and stop before “Creating a GKE Cluster”: https://cloud.google.com/kubernetes-engine/docs/quickstart#local-shell
* Create a GKE cluster
  * `gcloud container clusters create ${CLUSTER_NAME} --workload-pool=${PROJECT}.svc.id.goog --num-nodes=${NUM_NODES}`
* Workload identity IAM commands:
  * This feature enables the binding between Kubernetes service accounts and Google Cloud service accounts.
  * `gcloud iam service-accounts create qcnn-sa`
  * `gcloud iam service-accounts add-iam-policy-binding   --role roles/iam.workloadIdentityUser   --member "serviceAccount:${PROJECT}.svc.id.goog[default/qcnn-sa]"   qcnn-sa@${PROJECT}.iam.gserviceaccount.com`
* Google Cloud Storage commands
  * This is for storing training output.
  * Install gsutil: `gcloud components install gsutil`
  * Create bucket: `gsutil mb -p ${PROJECT} -l ${LOCATION} -b on gs://${BUCKET_NAME}`
* Give service account Cloud Storage permissions: `gsutil iam ch serviceAccount:qcnn-sa@${PROJECT}.iam.gserviceaccount.com:roles/storage.admin gs://${BUCKET_NAME}`
* Install `tf-operator` from Kubeflow: `kubectl apply -f https://raw.githubusercontent.com/kubeflow/tf-operator/v1.0.1-rc.1/deploy/v1/tf-operator.yaml`

### Billable Resources
* Container Registry ([pricing](https://cloud.google.com/container-registry/pricing))
* Kubernetes Engine ([pricing](https://cloud.google.com/kubernetes-engine/pricing))
  * Kubernetes Engine follows Compute Engine [pricing] for VMs in the cluster. Specifically, the following pricing is relevant for this tutorial:
    * [VM instance pricing](https://cloud.google.com/compute/vm-instance-pricing)
    * [Network pricing](https://cloud.google.com/vpc/network-pricing)
    * [Disk and image pricing](https://cloud.google.com/compute/disks-image-pricing)
* Cloud Storage ([pricing](https://cloud.google.com/storage/pricing))


## Run Training

* `make training`
  * This builds the Docker image, uploads it to the Google Container Registry, and deploys the setup to your GKE cluster.
* (optional) Check TFJob deployment status: `kubectl describe tfjob qcnn`
  * Within the `Status` section, it should eventually say `TFJobCreated` and `TFJobRunning`
* Check worker and Tensorboard pod status: `kubectl get pods`
  * There should be 3 containers: `qcnn-tensorboard-<some_suffix>`, `qcnn-worker-0`, and `qcnn-worker-1`.
  * They should all eventually be in `Running` status. If the status is either `ContainerCreating` or `CrashloopBackoff`, something is wrong.
* Check worker logs: `kubectl logs -f qcnn-worker-0`.
  * Ctrl-C to terminate the log stream.
  * Logs should show progress bars for training epochs, profiler start & end, and eventually writing model weights to a file at the end.
* Access Tensorboard
  * Get the IP of the Tensorboard instance
    * `kubectl get svc tensorboard-service`
    * The IP is under `EXTERNAL-IP`.
    * If the IP is `<pending>`, the load balancer is still being provisioned. Watch the status by running `kubectl get svc tensorboard-service -w`. Eventually the IP should show up.
  * In a browser, go to `<ip>:5001` to access the Tensorboard UI.
  
## Run Inference

* `make inference`
  * This builds the Docker image, uploads it to the Google Container Registry, and deploys the inference job to your GKE cluster.
* Check inference pod status: `kubectl get pods`
  * There should be 1 container: `qcnn-inference-<some_suffix>`.
* Check inference logs to verify inference results: `kubectl logs -f qcnn-inference-<some_suffix>`.

## Cleanup

Cleanup can be done on an as-needed basis.

### Cleaning up billable resources
* `make delete-training` and `make delete-inference`.
  * Removes Kubernetes deployments.
* [Delete Container Registry images](https://cloud.google.com/container-registry/docs/managing#deleting_images)
* [Delete Cloud Storage data](https://cloud.google.com/storage/docs/deleting-objects)
* Delete GKE cluster: `gcloud container clusters delete ${CLUSTER_NAME}`


### Other Cleanup
* Delete docker images: `make remove-images`
  * The next new build of container images will be slow.
* [Delete the Google Cloud service account](https://cloud.google.com/iam/docs/creating-managing-service-accounts#deleting).
