###########################################################################################################################
# Kubeflow installation script
#
# Author: Sebastian Lehrig
# License: Apache-2.0 License
###########################################################################################################################

###########################################################################################################################
# 1. Prerequisites
if [ -z "$KUBEFLOW_VERSION" ]
then
      kubeflow_version="main"
else
      kubeflow_version=$KUBEFLOW_VERSION
fi

BOLD=$(tput bold)
NORMAL=$(tput sgr0)
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BOLD}Which Kubernetes environment do you have admin access to?${NORMAL}
(1) Red Hat OpenShift
(2) Vanilla Kubernetes"
read -p "Selection [1]: " kubernetes_environment
kubernetes_environment=${kubernetes_environment:-1}
case "$kubernetes_environment" in 
  1 ) kubernetes_environment_name="Red Hat OpenShift"
      alias docker="podman"
      
      clusterDomain=$(oc get ingresses.config/cluster -o jsonpath={.spec.domain})
      echo -e ""
      read -p "${BOLD}Install OpenShift operators (Cert-Manager, Service Mesh (incl. Elasticsearch, Kiali, Jaeger), Namespace-Configuration, Serverless, Node Feature Discovery, GPU Operator)?${NORMAL} [y]: " install_operators
      install_operators=${install_operators:-y}
      case "$install_operators" in
        y|Y ) ;;
        n|N ) ;;
        * ) echo -e "invalid - exiting"; return;;
      esac
      ;;
  2 ) kubernetes_environment_name="Vanilla Kubernetes"
      externalIpAddress=$(hostname -i);;
  * ) echo -e "invalid - exiting"; return;;
esac

echo -e ""
read -p "${BOLD}To avoid toomanyrequests errors for Docker.io, do you want to store your Docker.io credentials?${NORMAL} [y]: " store_credentials
store_credentials=${store_credentials:-y}
case "$store_credentials" in 
  y|Y ) while true; do
          read -p "Docker.io user name: " docker_user
	  read -s -p "Docker.io password (input hidden): " docker_pass
	  echo -e "\nTrying to log-in..." 
	  logged_in=$(echo $docker_pass | docker login docker.io --username ${docker_user} --password-stdin)
          echo -e ""
	  echo -e "Debug: ${logged_in}"
	  if [[ "${logged_in}" == "Login Succeeded"* ]]
	  then
            echo -e "${GREEN}Success${NC}: Docker was able to login to docker.io using your credentials!"
	    break
          fi
	  echo -e "${RED}Failed${NC}: Docker was unable to login to docker.io using your credentials! Please verify you have used the correct ones and try again!"
	done
        ;;
  n|N ) ;;
  * ) echo -e "invalid - exiting"; return;;
esac

echo -e ""
read -p "${BOLD}Update your .bashrc file with Kubeflow variables (note: this is required if not already present)?${NORMAL} [y]: " update_bashrc
update_bashrc=${update_bashrc:-y}
case "$update_bashrc" in 
  y|Y ) ;;
  n|N ) ;;
  * ) echo -e "invalid - exiting"; return;;
esac

echo -e ""
read -p "${BOLD}Please enter your KUBEFLOW_BASE_DIR (directory where Kubeflow installation files will be stored) [default: /opt/kubeflow]: " kubeflow_base_dir
kubeflow_base_dir=${kubeflow_base_dir:-/opt/kubeflow}

echo -e ""
echo -e "${BOLD}====================================================${NORMAL}"
echo -e "${BOLD}Installation summary${NORMAL}"
echo -e "${BOLD}====================================================${NORMAL}"
echo -e "- ${BOLD}Kubeflow${NORMAL}: ${kubeflow_version}"
echo -e "- ${BOLD}Kubernetes environment${NORMAL}: ${kubernetes_environment_name}"
case "$kubernetes_environment" in
1 ) # OpenShift
echo -e "- ${BOLD}Install OpenShift Operators${NORMAL}: ${install_operators}"
echo -e "- ${BOLD}clusterDomain${NORMAL}: ${clusterDomain}"
;;
2 ) # k8s
echo -e "- ${BOLD}externalIpAddress${NORMAL}: ${externalIpAddress}"
;;
esac
echo -e "- ${BOLD}Store Docker.io credentials${NORMAL}: ${store_credentials}"
echo -e "- ${BOLD}Update .bashrc file${NORMAL}: ${update_bashrc}"
echo -e "- ${BOLD}KUBEFLOW_BASE_DIR${NORMAL}: ${kubeflow_base_dir}"
echo -e "${BOLD}====================================================${NORMAL}"
read -p "${BOLD}Proceed Kubeflow installation?${NORMAL} [y]: " proceed
proceed=${proceed:-y}
case "$proceed" in
  y|Y ) ;;
  n|N ) echo -e "Kubeflow installation aborted."; return;;
  * ) echo -e "invalid - exiting"; return;;
esac

###########################################################################################################################
# 2. Prepare Installation
case "$store_credentials" in 
  y|Y ) case "$kubernetes_environment" in
        1 ) # Add docker.io account settings into OpenShift secret 
            oc get secret/pull-secret -n openshift-config --template='{{index .data ".dockerconfigjson" | base64decode}}' > dockerconfig.json
            oc registry login --registry="docker.io" --auth-basic="$docker_user:$docker_pass" --to=dockerconfig.json
            oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=dockerconfig.json
            rm -f dockerconfig.json
	    ;;
        2 ) # Add docker.io as imagePullSecret to default serviceaccount 
            kubectl create secret docker-registry myregistrykey --docker-server=docker.io --docker-username=$docker_user --docker-password=$docker_pass
            kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "myregistrykey"}]}'
            ;;
        esac 	 
        ;;
  * ) ;;
esac

case "$update_bashrc" in
  y|Y )
git=$kubeflow_base_dir/git
manifests=$git/kubeflow-ppc64le-manifests

cat >> /root/.bashrc <<EOF
###### BEGIN KUBEFLOW ######
# clusterDomain equals oc get ingresses.config/cluster -o jsonpath={.spec.domain}
export KUBEFLOW_BASE_DIR=$kubeflow_base_dir
export GIT=$git
export MANIFESTS=$manifests
EOF
	case "$kubernetes_environment" in
        1 ) # OpenShift
	kube_pw=$(cat $(find /root -name "kubeadmin-password"))
cat >> /root/.bashrc <<EOF
export clusterDomain=$clusterDomain
export KUBEFLOW_KUSTOMIZE=$manifests/overlays/openshift
export KUBE_PW=$kube_pw
oc login -u kubeadmin -p $kube_pw --insecure-skip-tls-verify=true
EOF
            ;;
        2 ) # k8s
cat >> /root/.bashrc <<EOF
export externalIpAddress=$externalIpAddress
export KUBEFLOW_KUSTOMIZE=$manifests/overlays/k8s
EOF
            ;;
        esac
cat >> /root/.bashrc <<EOF
###### END KUBEFLOW ######
EOF
	source /root/.bashrc
        ;;
  * ) ;;
esac

# Get manifests
git clone --branch $kubeflow_version https://github.com/lehrig/kubeflow-ppc64le-manifests.git $MANIFESTS

###########################################################################################################################
# 3. Installation
case "$kubernetes_environment" in
1 ) # OpenShift

case "$install_operators" in
  y|Y ) # Install Cert Manager Operator
        # See: https://cert-manager.io/docs/installation/openshift/
        # TODO: Try from OperatorHub (when Kubeflow supports higher cert-manager versions)
        oc new-project cert-manager
        oc apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.4/cert-manager.yaml

        # Install subscriptions (operators from OperatorHub)
        while ! oc kustomize $KUBEFLOW_KUSTOMIZE/subscriptions | oc apply --kustomize $KUBEFLOW_KUSTOMIZE/subscriptions; do echo -e "Retrying to apply resources for Cert Manager..."; sleep 10; done

        # Configure node feature discovery
        while ! oc kustomize $KUBEFLOW_KUSTOMIZE/nfd | oc apply --kustomize $KUBEFLOW_KUSTOMIZE/nfd; do echo -e "Retrying to apply resources for Node Feature Discovery..."; sleep 10; done

        # Install GPU operator
        oc new-project gpu-operator
        git clone -b ppc64le_v1.9.0 https://github.com/mgiessing/gpu-operator.git $GIT/gpu-operator
        sed -i 's/use_ocp_driver_toolkit: false/use_ocp_driver_toolkit: true/g' $GIT/gpu-operator/deployments/gpu-operator/values.yaml
        helm install --wait --generate-name $GIT/gpu-operator/deployments/gpu-operator
        ;;
  * ) ;;
esac

# Configure service mesh
while ! oc kustomize $KUBEFLOW_KUSTOMIZE/servicemesh | oc apply --kustomize $KUBEFLOW_KUSTOMIZE/servicemesh; do echo -e "Retrying to apply resources for Service Mesh..."; sleep 10; done

# Deploy Kubeflow
while ! oc kustomize $KUBEFLOW_KUSTOMIZE | oc apply --kustomize $KUBEFLOW_KUSTOMIZE; do echo -e "Retrying to apply resources for Kubeflow..."; sleep 10; done

oc project kubeflow
#############################################
;;
2 ) # k8s

# Deploy Kubeflow
while ! kubectl kustomize $KUBEFLOW_KUSTOMIZE | kubectl apply --kustomize $KUBEFLOW_KUSTOMIZE; do echo -e "Retrying to apply resources for Kubeflow..."; sleep 10; done
;;
esac

###########################################################################################################################
# 4. Post-installation cleanup & configuration

# cache-deployer and cache-server not supported yet (are optional anyways)
kubectl delete deployment cache-deployer-deployment cache-server -n kubeflow

case "$kubernetes_environment" in
1 ) # OpenShift

# Required by visualization server
# TODO: only 1 of these is required...
oc adm policy add-scc-to-user privileged -z ml-pipeline-visualizationserver -n kubeflow
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:kubeflow:ml-pipeline-visualizationserver

# Required for training operator (regular TFJob & Katib)
# TODO: Find out which concrete role needs to be set to spawn training pods (--> https://ibm-systems-power.slack.com/archives/CEA8J8WQ6/p1644315444602459)
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:kubeflow:training-operator

# HTPasswd & Default User
# See: https://computingforgeeks.com/manage-openshift-okd-cluster-users-using-htpasswd-identity-provider/
yum -y install httpd-tools
htpasswd -c -B -b $KUBEFLOW_BASE_DIR/ocp_users.htpasswd user@example.com 12341234
oc create secret generic htpass-secret \
  --from-file=htpasswd=$KUBEFLOW_BASE_DIR/ocp_users.htpasswd \
  -n openshift-config
oc apply -f $KUBEFLOW_KUSTOMIZE/servicemesh/htpasswd-oauth.yaml

# Expose minio
oc expose service -n kubeflow minio-service

# Get UI address
# TODO: Get rid of insecure routes
export KUBEFLOW_URL=$(oc get routes -n istio-system secure-kubeflow -o jsonpath='http://{.spec.host}/')
;;
2 ) # k8s
# Get UI address
# see: https://istio.io/latest/docs/tasks/traffic-management/ingress/ingress-control/
export HTTPS_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
export KUBEFLOW_URL=https://$externalIpAddress:$HTTPS_INGRESS_PORT
;;
esac

cat << POSTINSTALL
Kubeflow deployed successfully.

Next:
1. Go to: $KUBEFLOW_URL
2. If a custom certificate (e.g, istio-ingressgateway.istio-system.svc) certificate as trusted (or type "thisisunsafe" into your browser)
3. Login using the default account:
  - Username: user@example.com
  - Password: 12341234
POSTINSTALL
