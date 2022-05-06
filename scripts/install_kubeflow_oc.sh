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

echo -e "${BOLD}You need to be logged in to your cluster with cluster-admin permissions"${NORMAL}


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
      read -p "${BOLD}Install OpenShift operators (Cert-Manager, Service Mesh (incl. Elasticsearch, Kiali, Jaeger), Namespace-Configuration, Serverless, Node Feature Discovery)?${NORMAL} [y]: " install_operators
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
read -p "${BOLD}Please enter your KUBEFLOW_BASE_DIR (directory where Kubeflow installation files will be stored) [default: $HOME/kubeflow]: " kubeflow_base_dir
kubeflow_base_dir=${kubeflow_base_dir:-$HOME/kubeflow}

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

manifests=$kubeflow_base_dir/git/kubeflow-ppc64le-manifests
case "$kubernetes_environment" in
1 ) # OpenShift
  export clusterDomain=$clusterDomain
  export KUBEFLOW_KUSTOMIZE=$manifests/overlays/openshift
  export MANIFESTS=$kubeflow_base_dir/git/kubeflow-ppc64le-manifests
  ;;
2 ) # k8s
  export externalIpAddress=$externalIpAddress
  export KUBEFLOW_KUSTOMIZE=$manifests/overlays/k8s
  ;;
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
        ;;
  * ) ;;
esac

#remove htpasswd in order to prevent oauth override
sed -i '' "s/- htpasswd-oauth.yaml/# - htpasswd-oauth.yaml/g" $KUBEFLOW_KUSTOMIZE/servicemesh/kustomization.yaml

# Configure service mesh
while ! oc kustomize $KUBEFLOW_KUSTOMIZE/servicemesh | oc apply --kustomize $KUBEFLOW_KUSTOMIZE/servicemesh; do echo -e "Retrying to apply resources for Service Mesh..."; sleep 10; done
oc wait --for=condition=available --timeout=600s deployment/istiod-kubeflow -n istio-system

# Deploy Kubeflow
while ! oc kustomize $KUBEFLOW_KUSTOMIZE | oc apply --kustomize $KUBEFLOW_KUSTOMIZE; do echo -e "Retrying to apply resources for Kubeflow..."; sleep 10; done

oc wait --for=condition=available --timeout=600s deployment/centraldashboard -n kubeflow

oc project kubeflow
#############################################
;;
2 ) # k8s

# Deploy Kubeflow
while ! kubectl kustomize $KUBEFLOW_KUSTOMIZE | kubectl apply --kustomize $KUBEFLOW_KUSTOMIZE; do echo -e "Retrying to apply resources for Kubeflow..."; sleep 10; done

# Ensure instio is up and side-cars are injected into kubeflow namespace afterwards (by restarting pods)
kubectl wait --for=condition=available --timeout=600s deployment/istiod -n istio-system
kubectl delete pod --all -n kubeflow
kubectl delete pod --all -n kubeflow-user-example-com
kubectl wait --for=condition=available --timeout=600s deployment/centraldashboard -n kubeflow
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

# Get UI address
# TODO: Get rid of insecure routes
export KUBEFLOW_URL=$(oc get routes -n istio-system secure-kubeflow -o jsonpath='http://{.spec.host}/')
;;
2 ) # k8s

# Add docker.io as imagePullSecret to default-editor serviceaccount 
case "$store_credentials" in 
  y|Y ) kubectl create secret docker-registry myregistrykey --docker-server=docker.io --docker-username=$docker_user --docker-password=$docker_pass
        kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "myregistrykey"}]}'
	
	kubectl create secret docker-registry myregistrykey -n kubeflow-user-example-com --docker-server=docker.io --docker-username=$docker_user --docker-password=$docker_pass
	kubectl patch serviceaccount default-editor -n kubeflow-user-example-com -p '{"imagePullSecrets": [{"name": "myregistrykey"}]}'
        ;;
  * ) ;;
esac

# Get UI address
# see: https://istio.io/latest/docs/tasks/traffic-management/ingress/ingress-control/
export HTTPS_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
export KUBEFLOW_URL=https://$externalIpAddress:$HTTPS_INGRESS_PORT
;;
esac

cat << POSTINSTALL
Kubeflow deployed successfully.

YOU MUST CREATE A HTPASSWD USER AS THIS IS CURRENTLY THE ONLY IDENTITY PROVIDER THAT HAS NAMESPACE CONFIGURATION ENABLED!

Check the docs:
https://docs.openshift.com/container-platform/4.8/authentication/identity_providers/configuring-htpasswd-identity-provider.html

# a) Get current users:
oc get secret htpass-secret -ojsonpath={.data.htpasswd} -n openshift-config | base64 --decode > users.htpasswd

# b)[Linux/Mac]Create a user:
htpasswd -bB users.htpasswd <username> <password>
# for example:
htpasswd -bB users.htpasswd user@example.com 12341234

# c) Replace old secret with updated one:
oc create secret generic htpass-secret --from-file=htpasswd=users.htpasswd --dry-run=client -o yaml -n openshift-config | oc replace -f -

Next:
1. Go to: $KUBEFLOW_URL
2. If a custom certificate (e.g, istio-ingressgateway.istio-system.svc) certificate as trusted (or type "thisisunsafe" into your browser)
3. Login with your htpasswd user
POSTINSTALL
