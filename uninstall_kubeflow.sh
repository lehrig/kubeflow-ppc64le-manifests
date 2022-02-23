###########################################################################################################################
# Kubeflow installation script
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
read -p "Selection [1|2]: " kubernetes_environment
case "$kubernetes_environment" in 
  1 ) kubernetes_environment_name="Red Hat OpenShift"
      alias docker="podman"
      ;;
  2 ) kubernetes_environment_name="Vanilla Kubernetes";;
  * ) echo -e "invalid - exiting"; exit;;
esac

echo -e ""
read -p "${BOLD}Cleanup your .bashrc by removing Kubeflow variables?${NORMAL} [y|n]: " clean_bashrc
case "$clean_bashrc" in
  y|Y ) ;;
  n|N ) ;;
  * ) echo -e "invalid - exiting";;
esac

echo -e ""
read -p "${BOLD}Delete KUBEFLOW_BASE_DIR (current value: "$(KUBEFLOW_BASE_DIR)") ?${NORMAL} [y|n]: " delete_base_dir
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
  * ) echo -e "invalid - exiting";;
esac

echo -e "${BOLD}====================================================${NORMAL}"
echo -e "${BOLD}Uninstall summary${NORMAL}"
echo -e "${BOLD}====================================================${NORMAL}"
echo -e "- ${BOLD}Kubernetes environment${NORMAL}: ${kubernetes_environment_name}"
echo -e "- ${BOLD}Cleanup .bashrc file${NORMAL}: ${clean_bashrc}"
echo -e "- ${BOLD}Delete Kubeflow resources${NORMAL}: yes"
echo -e "- ${BOLD}Delete KUBEFLOW_BASE_DIR (current value: "$(KUBEFLOW_BASE_DIR)")${NORMAL}: ${delete_base_dir}"
echo -e "${BOLD}====================================================${NORMAL}"
read -p "${BOLD}Proceed Kubeflow uninstall?${NORMAL} [y|n]: " proceed
case "$proceed" in
  y|Y ) ;;
  n|N ) echo -e "Kubeflow uninstall aborted."; exit;;
  * ) echo -e "invalid - exiting"; exit;;
esac

###########################################################################################################################
# 2. Uninstall
case "$kubernetes_environment" in
1 ) # OpenShift

oc delete --kustomize $KUBEFLOW_KUSTOMIZE
oc delete --kustomize $KUBEFLOW_KUSTOMIZE/servicemesh
oc delete --kustomize $KUBEFLOW_KUSTOMIZE/subscriptions
oc delete -f https://github.com/jetstack/cert-manager/releases/download/v1.5.4/cert-manager.yaml
#############################################
;;
2 ) # k8s
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

cat << POSTUNINSTALL
Kubeflow uninstalled successfully.
POSTUNINSTALL
