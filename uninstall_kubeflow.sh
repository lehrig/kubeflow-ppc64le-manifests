###########################################################################################################################
# Kubeflow uninstall script
#
# Author: Sebastian Lehrig
# License: Apache-2.0 License
###########################################################################################################################

###########################################################################################################################
# 1. Prerequisites
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BOLD}In which Kubernetes environment is Kubeflow installed?${NORMAL}
(1) Red Hat OpenShift
(2) Vanilla Kubernetes"
read -p "Selection [1]: " kubernetes_environment
kubernetes_environment=${kubernetes_environment:-1}
case "$kubernetes_environment" in 
  1 ) kubernetes_environment_name="Red Hat OpenShift"
      alias docker="podman"
      ;;
  2 ) kubernetes_environment_name="Vanilla Kubernetes";;
  * ) echo -e "invalid - exiting"; return;;
esac

echo -e ""
read -p "${BOLD}Cleanup your .bashrc by removing Kubeflow variables?${NORMAL} [y]: " clean_bashrc
clean_bashrc=${clean_bashrc:-y}
case "$clean_bashrc" in
  y|Y ) ;;
  n|N ) ;;
  * ) echo -e "invalid - exiting"; return;;
esac

echo -e ""
read -p "${BOLD}Delete KUBEFLOW_BASE_DIR (current value: "${KUBEFLOW_BASE_DIR}") ?${NORMAL} [y]: " delete_base_dir
delete_base_dir=${delete_base_dir:-y}
case "$delete_base_dir" in
  y|Y ) if [ -z "${KUBEFLOW_BASE_DIR+X}" ]
        then
          echo -e "${BOLD}${RED}Warning: ${KUBEFLOW_BASE_DIR} is unset!${NC}${NORMAL}"
        elif [ -z "$KUBEFLOW_BASE_DIR" ]
        then
          echo -e "${BOLD}${RED}Warning: ${KUBEFLOW_BASE_DIR} is set but empty!${NC}${NORMAL}"
        fi
	;;
  n|N ) ;;
  * ) echo -e "invalid - exiting"; return;;
esac

echo -e ""
read -p "${BOLD}Delete released persistent volumes?${NORMAL} [y]: " delete_released_pvs
delete_released_pvs=${delete_released_pvs:-y}
case "$delete_released_pvs" in
  y|Y ) ;;
  n|N ) ;;
  * ) echo -e "invalid - exiting"; return;;
esac

echo -e "${BOLD}====================================================${NORMAL}"
echo -e "${BOLD}Uninstall summary${NORMAL}"
echo -e "${BOLD}====================================================${NORMAL}"
echo -e "- ${BOLD}Kubernetes environment${NORMAL}: ${kubernetes_environment_name}"
echo -e "- ${BOLD}Cleanup .bashrc file${NORMAL}: ${clean_bashrc}"
echo -e "- ${BOLD}Delete Kubeflow resources${NORMAL}: y"
echo -e "- ${BOLD}Delete KUBEFLOW_BASE_DIR (current value: "${KUBEFLOW_BASE_DIR}")${NORMAL}: ${delete_base_dir}"
echo -e "- ${BOLD}Delete released persistent volumes${NORMAL}: ${delete_released_pvs}"
echo -e "${BOLD}====================================================${NORMAL}"
read -p "${BOLD}Proceed Kubeflow uninstall?${NORMAL} [y]: " proceed
proceed=${proceed:-y}
case "$proceed" in
  y|Y ) ;;
  n|N ) echo -e "Kubeflow uninstall aborted."; return;;
  * ) echo -e "invalid - exiting"; return;;
esac

###########################################################################################################################
# 2. Uninstall
echo -e "Initializing uninstall..."

case "$kubernetes_environment" in
1 ) # OpenShift
oc delete --all -A inferenceservices.serving.kserve.io 
oc delete validatingwebhookconfiguration validation.webhook.serving.knative.dev
oc delete --kustomize $KUBEFLOW_KUSTOMIZE
oc delete --kustomize $KUBEFLOW_KUSTOMIZE/servicemesh
# uninstall gpu operator and remote the associated resources
helm list --no-headers=true -n gpu-operator | awk '{print $1}' | xargs helm uninstall -n gpu-operator
#############################################
;;
2 ) # k8s
kubectl delete --all -A inferenceservices.serving.kserve.io
kubectl delete --kustomize $KUBEFLOW_KUSTOMIZE
;;
esac

case "$clean_bashrc" in
  y|Y ) sed -i '/###### BEGIN KUBEFLOW ######/,/###### END KUBEFLOW ######/d' /root/.bashrc
        ;;
  * ) ;;
esac

case "$delete_base_dir" in
  y|Y ) rm -rf $KUBEFLOW_BASE_DIR 
        ;;
  * ) ;;
esac

case "$delete_released_pvs" in
  y|Y ) kubectl get pv | grep Released | awk '$1 {print$1}' | while read vol; do kubectl delete pv/${vol}; done
        ;;
  * ) ;;
esac

cat << POSTUNINSTALL
Kubeflow uninstalled successfully.
POSTUNINSTALL
