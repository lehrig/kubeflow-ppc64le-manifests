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
      
      kubeadmin_file=/root/ocp4/auth/kubeadmin-password
      if [ ! -f "$kubeadmin_file" ]
      then
        kubeadmin_file=$(find /root -name "kubeadmin-password")  
        COUNT=$(echo "$kubeadmin_file" | wc -w)
        
	if [[ $COUNT -ne 1 ]]
        then
          echo -e "${BOLD}Failed finding a single kubeadmin-password file (found $COUNT)."
          echo -e "$Found these files:"
          echo "$kubeadmin_file" 
          read -p "${BOLD}Please enter file to be used: " kubeadmin_file
          
          if [ ! -f "$kubeadmin_file" ]
          then
            echo -e "The given kubeadmin-password file does not exist - exiting"; return;
          fi
        fi 
      fi
      
      oc whoami &> /dev/null

      if [[ $? -ne 0 ]]
      then
        echo "You did not log into the OpenShift api server, please login and re-run the script."
        return
      fi

      clusterDomain=$(oc get ingresses.config/cluster -o jsonpath={.spec.domain})
      echo -e ""
      read -p "${BOLD}Install OpenShift operators (Cert-Manager, Service Mesh (incl. Elasticsearch, Kiali, Jaeger), Namespace-Configuration, Serverless, Node Feature Discovery, GPU Operator, Grafana)?${NORMAL} [y]: " install_operators
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
read -p "${BOLD}Install Trino (connects multiple databases in a single SQL query)?${NORMAL} [y]: " install_trino
install_trino=${install_trino:-y}
case "$install_trino" in
  y|Y ) ;;
  n|N ) ;;
  * ) echo -e "invalid - exiting"; return;;
esac

echo -e ""
read -p "${BOLD}Create datalake namespace with exemplary databases & data (PostgreSQL, MongoDB, Apache Kafka)?${NORMAL} [y]: " create_datalake
create_datalake=${create_datalake:-y}
case "$create_datalake" in
  y|Y ) case "$kubernetes_environment" in
        1 ) ;;
        2 ) # Ask for Red Hat credentials
	    echo -e "Installing Apache Kafka via Red Hat AMQ Streams requires a Red Hat login; please provide your credentials."	
	    read -p "Red Hat user name: " redhat_user
            read -s -p "Red Hat password (input hidden): " redhat_pass
            ;;
        esac
        ;;
  n|N ) ;;
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
	  case "$kubernetes_environment" in
            1 ) kubernetes_environment_name="Red Hat OpenShift"
                logged_in=$(echo $docker_pass | podman login docker.io --username ${docker_user} --password-stdin)
		;;
	    2 ) logged_in=$(echo $docker_pass | docker login docker.io --username ${docker_user} --password-stdin)
		;;
	  esac
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
echo -e "- ${BOLD}kubeadmin_file${NORMAL}: ${kubeadmin_file}"
echo -e "- ${BOLD}Install OpenShift Operators${NORMAL}: ${install_operators}"
echo -e "- ${BOLD}clusterDomain${NORMAL}: ${clusterDomain}"
;;
2 ) # k8s
echo -e "- ${BOLD}externalIpAddress${NORMAL}: ${externalIpAddress}"
;;
esac
echo -e "- ${BOLD}Install Trino${NORMAL}: ${install_trino}"
echo -e "- ${BOLD}Create datalake namespace${NORMAL}: ${create_datalake}"
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

# get kustomize if not there
if ! command -v kustomize &> /dev/null
then
    echo "Kustomize not found - installing to /user/local/bin/..."
    kustomize_version=5.1.1
    curl --silent --location --remote-name "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${kustomize_version}/kustomize_v${kustomize_version}_linux_ppc64le.tar.gz"
    tar -xzvf kustomize_v${kustomize_version}_linux_ppc64le.tar.gz
    chmod a+x kustomize
    sudo mv kustomize /usr/local/bin/kustomize
    rm -f kustomize_v${kustomize_version}_linux_ppc64le.tar.gz
fi

# get helm if not there
if ! command -v helm &> /dev/null
then
   echo "Helm not found - installing to /user/local/bin/..."
   helm_version=3.11.2
   curl --silent --location --remote-name "https://get.helm.sh/helm-v${helm_version}-linux-ppc64le.tar.gz"
   tar --strip-components=1 -xzf helm-v${helm_version}-linux-ppc64le.tar.gz linux-ppc64le/helm
   chmod a+x helm
   sudo mv helm /usr/local/bin/helm
   rm -f helm-v${helm_version}-linux-ppc64le.tar.gz
fi

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
	kube_pw=$(cat $kubeadmin_file)
cat >> /root/.bashrc <<EOF
export CLUSTER_DOMAIN=$clusterDomain
export KUBEFLOW_KUSTOMIZE=$manifests/overlays/openshift
export KUBE_PW=$kube_pw
oc login -u kubeadmin -p $kube_pw --insecure-skip-tls-verify=true > /dev/null
EOF
            ;;
        2 ) # k8s
cat >> /root/.bashrc <<EOF
export EXTERNAL_IP_ADDRESS=$externalIpAddress
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
if [ -d "$MANIFESTS" ]; then
    echo "Warning: $MANIFESTS already exists; skipping git clone."
else
    git clone --branch $kubeflow_version https://github.com/lehrig/kubeflow-ppc64le-manifests.git $MANIFESTS
fi

###########################################################################################################################
# 3. Installation
case "$kubernetes_environment" in
1 ) # OpenShift

case "$install_operators" in
  y|Y ) # Install Cert Manager Operator
        # See: https://cert-manager.io/docs/installation/openshift/
        # TODO: Try from OperatorHub (when Kubeflow supports higher cert-manager versions)
	oc create namespace cert-manager
        oc apply -n cert-manager -f https://github.com/jetstack/cert-manager/releases/download/v1.5.4/cert-manager.yaml
        oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:cert-manager:cert-manager
        #oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:cert-manager:cert-manager-webhook
        oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:cert-manager:cert-manager-cainjector  

        # Install subscriptions (operators from OperatorHub)
        while ! kustomize build $KUBEFLOW_KUSTOMIZE/subscriptions | awk '!/well-defined/' | oc apply -f -; do echo -e "Retrying to apply resources for Cert Manager..."; sleep 10; done

        # Configure node feature discovery
        while ! kustomize build $KUBEFLOW_KUSTOMIZE/nfd | awk '!/well-defined/' | oc apply -f -; do echo -e "Retrying to apply resources for Node Feature Discovery..."; sleep 10; done

        # Install GPU Operator
        oc create namespace gpu-operator
        git clone -b ppc64le_v1.10.1 https://github.com/mgiessing/gpu-operator.git $GIT/gpu-operator
        sed -i 's/use_ocp_driver_toolkit: false/use_ocp_driver_toolkit: true/g' $GIT/gpu-operator/deployments/gpu-operator/values.yaml
        helm install -n gpu-operator --wait --generate-name $GIT/gpu-operator/deployments/gpu-operator

        # Configure Grafana
        # Note: Prometheus comes with OpenShift out-of-the-box
	oc apply -f $KUBEFLOW_KUSTOMIZE/grafana/enable-user-workload.yaml
        ;;
  * ) ;;
esac
# Configure service mesh
while ! kustomize build $KUBEFLOW_KUSTOMIZE/servicemesh | envsubst '${CLUSTER_DOMAIN}' | awk '!/well-defined/' | oc apply -f -; do echo -e "Retrying to apply resources for Service Mesh..."; sleep 10; done
oc wait --for=condition=available --timeout=600s deployment/istiod-kubeflow -n istio-system

# Deploy Kubeflow
while ! kustomize build $KUBEFLOW_KUSTOMIZE | awk '!/well-defined/' | oc apply -f -; do echo -e "Retrying to apply resources for Kubeflow..."; sleep 10; done

oc wait --for=condition=available --timeout=600s deployment/centraldashboard -n kubeflow

oc project kubeflow
#############################################
;;
2 ) # k8s

# Deploy Kubeflow
echo -e ""
echo -e "######################################################"
echo -e "# Initializing Kubeflow Installation; please wait... #"
echo -e "######################################################"
echo -e ""

while ! kustomize build $KUBEFLOW_KUSTOMIZE | envsubst '${EXTERNAL_IP_ADDRESS}' | awk '!/well-defined/' | kubectl apply -f -; do echo -e "Retrying to apply resources for Kubeflow..."; sleep 10; done

# Ensure istio is up and side-cars are injected into kubeflow namespace afterwards (by restarting pods)
kubectl wait --for=condition=available --timeout=600s deployment/istiod -n istio-system
kubectl delete pod --all -n kubeflow
kubectl delete pod --all -n kubeflow-admin-example-com
kubectl delete pod --all -n kubeflow-user-example-com
kubectl wait --for=condition=available --timeout=600s deployment/centraldashboard -n kubeflow
;;
esac

#############################################
# Datalake
case "$create_datalake" in
  y|Y ) DATALAKE_NAMESPACE=datalake
	DATALAKE_USER=uptake
	DATALAKE_PASS=marten-mole

	POSTGRESQL_SERVICE=postgresql
	POSTGRESQL_DATABASE=stock-prices
	POSTGRESQL_VOLUME_CAPACITY=10Gi

	MONGODB_SERVICE=mongodb
	MONGODB_DATABASE=weather
	MONGODB_VOLUME_CAPACITY=10Gi

	KAFKA_CLUSTER=stock-weather-streams

        kubectl create namespace $DATALAKE_NAMESPACE

	case "$kubernetes_environment" in
        1 ) # Openshift 
	    # Install PostgreSQL Template
	    oc project datalake
	    oc process -n openshift postgresql-persistent -p DATABASE_SERVICE_NAME=$POSTGRESQL_SERVICE -p POSTGRESQL_USER=$DATALAKE_USER -p POSTGRESQL_PASSWORD=$DATALAKE_PASS -p POSTGRESQL_DATABASE=$POSTGRESQL_DATABASE -p VOLUME_CAPACITY=$POSTGRESQL_VOLUME_CAPACITY | oc create -f -

            # Install Red Hat AMQ Streams Operator (based on Strimzi Operator for Apache Kafka Streaming support)
            cat <<EOF | kubectl apply -n openshift-operators -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    operators.coreos.com/amq-streams.openshift-operators: ""
  name: amq-streams
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: amq-streams
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
            oc project kubeflow
            ;;
        2 ) # Vanilla Kubernetes 
	    # Save Red Hat subscription in secret
	    #TODO LEHRIG
	    kubectl create -n $DATALAKE_NAMESPACE secret docker-registry redhat-registry --docker-username=$redhat_user --docker-password=$redhat_pass --docker-server=registry.redhat.io
	     
	    # Install PostgreSQL based on modified PostgreSQL Template 
            # See: https://github.com/sclorg/postgresql-container/blob/master/examples/postgresql-persistent-template.json
	    cat <<EOF | kubectl -n ${DATALAKE_NAMESPACE} apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${POSTGRESQL_SERVICE}
  labels: 
    name: ${POSTGRESQL_SERVICE}
stringData:
  database-name: ${POSTGRESQL_DATABASE}
  database-password: ${DATALAKE_PASS}
  database-user: ${DATALAKE_USER}
  database-db: ${DATALAKE_USER}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${POSTGRESQL_SERVICE}
  labels: 
    name: ${POSTGRESQL_SERVICE}
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: ${POSTGRESQL_VOLUME_CAPACITY}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${POSTGRESQL_SERVICE}
  labels: 
    name: ${POSTGRESQL_SERVICE}
spec:
  replicas: 1
  selector:
    matchLabels:
      name: ${POSTGRESQL_SERVICE}
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        name: ${POSTGRESQL_SERVICE}
    spec:
      containers:
      - env:
        - name: POSTGRES_USER #DATALAKE_USER
          valueFrom:
            secretKeyRef:
              key: database-user
              name: ${POSTGRESQL_SERVICE}
        - name: POSTGRES_PASSWORD #DATALAKE_PASS
          valueFrom:
            secretKeyRef:
              key: database-password
              name: ${POSTGRESQL_SERVICE}
        - name: POSTGRES_DB #POSTGRESQL_DATABASE
          valueFrom:
            secretKeyRef:
              key: database-name
              name: ${POSTGRESQL_SERVICE}
        # for docker image only
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        # registry.redhat.io/rhscl/postgresql-12-rhel7
        image: registry.hub.docker.com/ppc64le/postgres # https://hub.docker.com/r/ppc64le/postgres
        imagePullPolicy: IfNotPresent
        name: ${POSTGRESQL_SERVICE}
        ports:
          - containerPort: 5432
            protocol: TCP
        securityContext:
          privileged: false
        volumeMounts:
        - mountPath: /var/lib/postgresql/data #/var/lib/psql/data
          name: ${POSTGRESQL_SERVICE}-data
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      imagePullSecrets:
        - name: redhat-registry
      volumes:
      - name: ${POSTGRESQL_SERVICE}-data
        persistentVolumeClaim:
          claimName: ${POSTGRESQL_SERVICE}
---
apiVersion: v1
kind: Service
metadata:
  annotations:
  name: ${POSTGRESQL_SERVICE}
  labels: 
    name: ${POSTGRESQL_SERVICE}
spec:
  ports:
  - port: 5432
    protocol: TCP
    targetPort: 5432
  selector:
    name: ${POSTGRESQL_SERVICE}
  sessionAffinity: None
  type: ClusterIP
EOF

            # Install Red Hat AMQ Streams manually (inspired by OpenShift installation; requires Red Hat subscription)
	    AMQ_STREAMS_INSTALLER=amq-streams-installer.zip
            wget https://ibm.box.com/shared/static/6ccbwncple6sngpiq3b890n8xqfq00c2.zip -O $AMQ_STREAMS_INSTALLER
            unzip $AMQ_STREAMS_INSTALLER
            mkdir amq-streams-installer
            mv examples amq-streams-installer
            mv install amq-streams-installer
	    rm -f $AMQ_STREAMS_INSTALLER
            sed -i 's/namespace: .*/namespace: ${DATALAKE_NAMESPACE}/' amq-streams-installer/install/cluster-operator/*RoleBinding*.yaml
	    echo -e "imagePullSecrets:\n  - name: redhat-registry" >> amq-streams-installer/install/cluster-operator/010-ServiceAccount-strimzi-cluster-operator.yaml
	    kubectl apply -n ${DATALAKE_NAMESPACE} -f amq-streams-installer/install/cluster-operator
            rm -rf amq-streams-installer
            
	    kubectl patch serviceaccount -n ${DATALAKE_NAMESPACE} default -p '{"imagePullSecrets": [{"name": "redhat-registry"}]}'
            kubectl create clusterrolebinding -n ${DATALAKE_NAMESPACE} default-pod --clusterrole cluster-admin --serviceaccount=datalake:strimzi-cluster-operator
            ;;
        esac

	# Install MongoDB
        cat <<EOF | kubectl apply -n $DATALAKE_NAMESPACE -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${MONGODB_SERVICE}
  labels: 
    name: ${MONGODB_SERVICE}
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: ${MONGODB_VOLUME_CAPACITY}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${MONGODB_SERVICE}
  labels:
    name: ${MONGODB_SERVICE}
spec:
  replicas: 1
  selector:
    matchLabels:
      name: ${MONGODB_SERVICE}
  template:
    metadata:
      labels:
        name: ${MONGODB_SERVICE}
    spec:
      containers:
      - name: ${MONGODB_SERVICE}
        image: ibmcom/mongodb-ppc64le:latest
        ports:
        - containerPort: 27017
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          value: admin
        - name: MONGO_INITDB_ROOT_PASSWORD
          value: admin
        volumeMounts:
        - mountPath: /data/db
          name: mongodb-volume
      volumes:
      - name: mongodb-volume
        persistentVolumeClaim:
          claimName: ${MONGODB_SERVICE}
---
apiVersion: v1
kind: Service
metadata:
  labels:
    name: ${MONGODB_SERVICE}
  name: ${MONGODB_SERVICE}
spec:
  ports:
  - port: 27017
    protocol: TCP
    targetPort: 27017
  selector:
    name: ${MONGODB_SERVICE}
EOF

        # Create Kafka resources
        cat <<EOF | kubectl apply -n $DATALAKE_NAMESPACE -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
 name: ${KAFKA_CLUSTER}
spec:
  kafka:
    config:
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
      default.replication.factor: 3
      min.insync.replicas: 2
      inter.broker.protocol.version: '3.1'
    storage:
      type: ephemeral
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
    version: 3.1.0
    replicas: 3
  entityOperator:
    topicOperator: {}
    userOperator: {}
  zookeeper:
    storage:
      type: ephemeral
    replicas: 3
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: stockdata
  labels:
    strimzi.io/cluster: ${KAFKA_CLUSTER}
spec:
  partitions: 10
  replicas: 3
  config:
    retention.ms: 604800000
    segment.bytes: 1073741824
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: weatherdata
  labels:
    strimzi.io/cluster: ${KAFKA_CLUSTER}
spec:
  partitions: 10
  replicas: 3
  config:
    retention.ms: 604800000
    segment.bytes: 1073741824
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaBridge
metadata:
  name: kafka-bridge
  labels:
    strimzi.io/cluster: ${KAFKA_CLUSTER}
spec:
  replicas: 1
  bootstrapServers: '${KAFKA_CLUSTER}-kafka-bootstrap:9092'
  http:
    port: 8090
EOF

	####################
        # Initialize Data Basis

	# Initialize PostgreSQL
	DATA_FILE=HistoricalDataApple.csv
        wget https://ibm.box.com/shared/static/89i7cxkeok6ndd0kh6q2ycvviip94eby.csv -O $DATA_FILE
        sed -i 's/\$//g' $DATA_FILE
        cat > init-stock-prices.sql <<EOF
CREATE TABLE IF NOT EXISTS public.applehistory
(
    "Date" date NOT NULL,
    "Close" real,
    "Volume" bigint,
    "Open" real,
    "High" real,
    "Low" real,
    CONSTRAINT "appleHistory_pkey" PRIMARY KEY ("Date")
);
\copy public.applehistory FROM '/tmp/$DATA_FILE' WITH (FORMAT csv, HEADER true, DELIMITER ',');
EOF
        sleep 120s
        POSTGRESQL_POD=$(kubectl get po -n $DATALAKE_NAMESPACE -l name=$POSTGRESQL_SERVICE -o jsonpath={..metadata.name})
	echo $POSTGRESQL_POD
	kubectl cp -n $DATALAKE_NAMESPACE $DATA_FILE "$POSTGRESQL_POD:/tmp/"
	kubectl cp -n $DATALAKE_NAMESPACE init-stock-prices.sql "$POSTGRESQL_POD:/tmp/"
	kubectl exec -n $DATALAKE_NAMESPACE $POSTGRESQL_POD -- psql -U $DATALAKE_USER -d $POSTGRESQL_DATABASE -a -f /tmp/init-stock-prices.sql

        rm -f $DATA_FILE init-stock-prices.sql

	# Initialize MongoDB
        WEATHER_FILE=weather_ny_2012-2022.csv
        wget https://ibm.box.com/shared/static/3tgm9bwxsl8tjezk0jgfjvk48cma46li.csv -O $WEATHER_FILE
	SCHEMA_FILE=mongo-schema-definition.json
        cat > $SCHEMA_FILE <<EOF
{
    "table": "weatherny",
    "fields": [
        {"name": "_id",
         "type": "date",
         "hidden": false },
        {"name": "AWND",
         "type": "DOUBLE",
         "hidden": false },
        {"name": "PGTM",
         "type": "DOUBLE",
         "hidden": false },
        {"name": "PRCP",
         "type": "DOUBLE",
         "hidden": false },
        {"name": "SNOW",
         "type": "DOUBLE",
         "hidden": false },
        {"name": "SNWD",
         "type": "DOUBLE",
         "hidden": false },
        {"name": "TAVG",
         "type": "DOUBLE",
         "hidden": false },
        {"name": "TMAX",
         "type": "DOUBLE",
         "hidden": false },
        {"name": "TMIN",
         "type": "DOUBLE",
         "hidden": false }
    ]
}
EOF
        # Each database has to have a dedicated user
        MONGO_USER_FILE=create-mongo-user.mongodb
        cat > $MONGO_USER_FILE <<EOF
db.createUser(
  {
    user: "${DATALAKE_USER}",
    pwd: "${DATALAKE_PASS}",
    roles: [ { role: "dbOwner", db: "${MONGODB_DATABASE}" } ]
  }
)
EOF
        DATABASE_TOOLS=database_tools.tgz
	wget https://fastdl.mongodb.org/tools/db/mongodb-database-tools-ubuntu1804-ppc64le-100.6.1.tgz -O $DATABASE_TOOLS
	kubectl -n $DATALAKE_NAMESPACE wait --for=condition=available --timeout=60s deploy/mongodb
	MONGODB_POD=$(kubectl get po -n $DATALAKE_NAMESPACE -l name=$MONGODB_SERVICE -l app=$MONGODB_SERVICE -o jsonpath={..metadata.name})
	sleep 30s
	echo $MONGODB_POD
        kubectl cp -n $DATALAKE_NAMESPACE $DATABASE_TOOLS "$MONGODB_POD":/tmp/
        kubectl cp -n $DATALAKE_NAMESPACE $SCHEMA_FILE "$MONGODB_POD":/tmp/
	kubectl cp -n $DATALAKE_NAMESPACE $WEATHER_FILE "$MONGODB_POD":/tmp/
        kubectl cp -n $DATALAKE_NAMESPACE $MONGO_USER_FILE "$MONGODB_POD":/tmp/
        echo "copied files to mongodb pod"
        kubectl exec -n $DATALAKE_NAMESPACE $MONGODB_POD -- bash -c "mkdir -p /tmp/mongodb && tar --strip-components=1 -zxf /tmp/${DATABASE_TOOLS} -C /tmp/mongodb && /tmp/mongodb/bin/mongoimport -d ${MONGODB_DATABASE} -c weatherny --type csv --columnsHaveTypes --file /tmp/${WEATHER_FILE} --headerline --username admin --password admin --authenticationDatabase admin && /tmp/mongodb/bin/mongoimport -d ${MONGODB_DATABASE} -c schemadef --file /tmp/${SCHEMA_FILE} --username admin --password admin --authenticationDatabase admin && mongo -u admin -p admin --authenticationDatabase admin ${MONGODB_DATABASE} /tmp/${MONGO_USER_FILE}"
	echo "added mongo file"
	rm -f $WEATHER_FILE $SCHEMA_FILE $MONGO_USER_FILE $DATABASE_TOOLS
        
        cat <<EOF | kubectl apply -n $DATALAKE_NAMESPACE -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: weatherproducer
spec:
  successfulJobsHistoryLimit: 1
  schedule: "45 0 * * *"       
  startingDeadlineSeconds: 200  
  jobTemplate:                  
    spec:
      template:
        metadata:
          name: weatherproducer
          labels:               
            parent: "cronjobweatherproducer"
        spec:
          containers:
          - name: weatherproducer
            image: quay.io/nataliejann/kafkaproducers:weatherproducer
            imagePullPolicy: Always
          restartPolicy: OnFailure
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: stockproducer
spec:
  successfulJobsHistoryLimit: 1
  schedule: "0 16 * * *"       
  startingDeadlineSeconds: 200  
  jobTemplate:                  
    spec:
      template:
        metadata:
          name: stockproducers
          labels:               
            parent: "cronjobstockproducer"
        spec:
          containers:
          - name: stockproducer
            image: quay.io/nataliejann/kafkaproducers:stockproducer
            imagePullPolicy: Always
          restartPolicy: OnFailure
---
apiVersion: batch/v1
kind: Job
metadata:
  name: weather-history-producer
  labels:
    app: weather-history-producer
spec:
  template:
    metadata:
      labels:
        app: weather-history-producer
    spec:
      containers:
      - name: weather-history-producer
        image: quay.io/nataliejann/kafkaproducers:weatherhistoryproducer
      restartPolicy: OnFailure
---
apiVersion: batch/v1
kind: Job
metadata:
  name: stock-history-producer
  labels:
    app: stock-history-producer
spec:
  template:
    metadata:
      labels:
        app: stock-history-producer
    spec:
      containers:
      - name: stock-history-producer
        image: quay.io/nataliejann/kafkaproducers:stockhistoryproducer
      restartPolicy: OnFailure
EOF
	;;
  * ) ;;
esac

###########################################################################################################################
# 4. Install Trino
case "$install_trino" in
  y|Y ) kubectl create namespace trino
	
	TRINO_GIT=$GIT/charts
	TRINO_CHARTS=$TRINO_GIT/charts
	
	if [ -d "$TRINO_GIT" ]; then
            echo "Warning: $TRINO_GIT already exists; skipping git clone."
        else
            git clone https://github.com/trinodb/charts.git $TRINO_GIT
        fi

        cat >> trino-catalogs.txt <<EOF
additionalCatalogs:
  kafka: |
    connector.name=kafka
    kafka.table-names=trinostock, trinoweather
    kafka.nodes=${KAFKA_CLUSTER}-kafka-bootstrap.${DATALAKE_NAMESPACE}:9092
    kafka.hide-internal-columns=false
    kafka.table-description-supplier=FILE
    kafka.table-description-dir=/etc/trino/schemas
    kafka.timestamp-upper-bound-force-push-down-enabled=true  
  mongodb: |
    connector.name=mongodb
    mongodb.connection-url=mongodb://${DATALAKE_USER}:${DATALAKE_PASS}@${MONGODB_SERVICE}.${DATALAKE_NAMESPACE}:27017/?authSource=${MONGODB_DATABASE}
    mongodb.schema-collection=schemadef
  postgresql: |
    connector.name=postgresql
    connection-url=jdbc:postgresql://${POSTGRESQL_SERVICE}.${DATALAKE_NAMESPACE}:5432/${POSTGRESQL_DATABASE}
    connection-user=${DATALAKE_USER}
    connection-password=${DATALAKE_PASS}
    decimal-mapping=allow_overflow
    decimal-rounding-mode=HALF_UP
EOF
        sed -i "/additionalCatalogs: {}/r trino-catalogs.txt" $TRINO_CHARTS/trino/values.yaml
        sed -i "/additionalCatalogs: {}/d" $TRINO_CHARTS/trino/values.yaml
        rm -f trino-catalogs.txt

	cat >> trino-kafka-table.txt <<'EOF'
  tableDescriptions:
    stockdata.json: |-
      {
        "tableName": "trinostock",
        "topicName": "stockdata",
        "dataFormat": "json",
        "message": {
          "dataFormat": "json",
          "fields": [
            {
                "name": "date",
                "mapping": "date",
                "type": "DATE",
                "dataFormat": "iso8601"
            },
            {
                "name": "apple_price",
                "mapping": "apple_price",
                "type": "DOUBLE"
            },
            {
                "name": "volume",
                "mapping": "volume",
                "type": "BIGINT"
            },
            {
                "name": "low",
                "mapping": "low",
                "type": "DOUBLE"
            },
            {
                "name": "high",
                "mapping": "high",
                "type": "DOUBLE"
            },
            {
                "name": "open",
                "mapping": "open",
                "type": "DOUBLE"
            }
          ]
        }
      }
    weatherdata.json: |-
      {
        "tableName": "trinoweather",
        "topicName": "weatherdata",
        "dataFormat": "json",
        "message": {
          "dataFormat": "json",
          "fields": [
            {
                "name": "STATION",
                "mapping": "STATION",
                "type": "VARCHAR"
            },
            {
                "name": "AWND",
                "mapping": "AWND",
                "type": "DOUBLE"
            },
            {
                "name": "PRCP",
                "mapping": "PRCP",
                "type": "DOUBLE"
            },
            {
                "name": "SNOW",
                "mapping": "SNOW",
                "type": "DOUBLE"
            },
            {
                "name": "SNWD",
                "mapping": "SNWD",
                "type": "DOUBLE"
            },
            {
                "name": "TAVG",
                "mapping": "TAVG",
                "type": "DOUBLE"
            },{
                "name": "TMIN",
                "mapping": "TMIN",
                "type": "DOUBLE"
            },
            {
                "name": "TMAX",
                "mapping": "TMAX",
                "type": "DOUBLE"
            },
            {
                "name": "DATE",
                "mapping": "DATE",
                "type": "DATE",
                "dataFormat": "iso8601"
            }
          ]
        }
      }
EOF
        sed -i "/  tableDescriptions: {}/r trino-kafka-table.txt" $TRINO_CHARTS/trino/values.yaml
        sed -i "/  tableDescriptions: {}/d" $TRINO_CHARTS/trino/values.yaml
        rm -f trino-kafka-table.txt
        # sed -i "s/    dataDir: \/data\/trino/    dataDir: \/data\/trino\/data:z/g" $TRINO_CHARTS/trino/values.yaml

        # cat >> trino-node-properties.txt <<EOF
  # nodeSelector:
    # worker_type: baremetal_worker
    # or
    # feature.node.kubernetes.io/cpu-cpuid.ARCH_3_00: true
# EOF

        # sed -i "/  nodeSelector: {}/r trino-node-properties.txt" $TRINO_CHARTS/trino/values.yaml
	# sed -i "/  nodeSelector: {}/d" $TRINO_CHARTS/trino/values.yaml
        # rm -f trino-node-properties.txt

        # See https://stackoverflow.com/a/75757959 and uncomment the 27 lines below if Trino is deployed to multiple machines, e.g. when using the nodeSelector above
	# cat >> trino-config-properties.txt <<EOF
# additionalConfigProperties:
  #   - node.internal-address-source=IP_ENCODED_AS_HOSTNAME
# EOF
        # sed -i "/additionalConfigProperties: {}/r trino-config-properties.txt" $TRINO_CHARTS/trino/values.yaml
	# sed -i "/additionalConfigProperties: {}/d" $TRINO_CHARTS/trino/values.yaml
        # rm -f trino-config-properties.txt

 	# cat <<EOF | kubectl -n trino apply -f -
# apiVersion: v1
# kind: Service
# metadata:
  # labels:
    # app: trino
  # name: ip
  # namespace: trino
# spec:
  # clusterIP: None # this makes it headless.
  # ports:
    # - name: http
      # port: 8080
      # protocol: TCP
      # targetPort: http
  # selector:
    # app: trino
  # type: ClusterIP
# EOF
	

	helm upgrade --install -n trino trino $TRINO_CHARTS/trino
	 case "$kubernetes_environment" in
        1 ) # OpenShift
            oc adm policy add-scc-to-user anyuid -z default -n trino
	    ;;
        2 ) # k8s
            ;;
        esac
        ;;
  * ) ;;
esac

###########################################################################################################################
# 5. Post-installation cleanup & configuration
case "$kubernetes_environment" in
1 ) # OpenShift

# Required by visualization server
# TODO: only 1 of these is required...
oc adm policy add-scc-to-user privileged -z ml-pipeline-visualizationserver -n kubeflow
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:kubeflow:ml-pipeline-visualizationserver

# Required for training operator (regular TFJob & Katib)
# TODO: Find out which concrete role needs to be set to spawn training pods (--> https://ibm-systems-power.slack.com/archives/CEA8J8WQ6/p1644315444602459)
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:kubeflow:training-operator

# Required by tensorboard controller
# TODO: only 1 of these is required...
oc adm policy add-scc-to-user privileged -z tensorboard-controller-controller-manager -n kubeflow
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:kubeflow:tensorboard-controller-controller-manager

# HTPasswd & Default User
# See: https://computingforgeeks.com/manage-openshift-okd-cluster-users-using-htpasswd-identity-provider/
yum -y install httpd-tools
htpasswd -c -B -b $KUBEFLOW_BASE_DIR/ocp_users.htpasswd admin@example.com 12341234
htpasswd -Bb $KUBEFLOW_BASE_DIR/ocp_users.htpasswd user@example.com 12341234
oc create secret generic htpass-secret \
  --from-file=htpasswd=$KUBEFLOW_BASE_DIR/ocp_users.htpasswd \
  -n openshift-config
oc patch oauth cluster --type=merge -p '{"spec":{"identityProviders": [{"htpasswd": {"fileData": {"name": "htpass-secret"}}, "mappingMethod": "claim", "name": "Local Password","type":"HTPasswd"}]}}'

# Get UI address
# TODO: Get rid of insecure routes
export KUBEFLOW_URL=$(oc get routes -n istio-system secure-kubeflow -o jsonpath='http://{.spec.host}/')
;;
2 ) # k8s

# Add docker.io as imagePullSecret to default-editor serviceaccount 
case "$store_credentials" in 
  y|Y ) kubectl create secret docker-registry myregistrykey --docker-server=docker.io --docker-username=$docker_user --docker-password=$docker_pass
        kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "myregistrykey"}]}'
	
        kubectl create secret docker-registry myregistrykey -n kubeflow-admin-example-com --docker-server=docker.io --docker-username=$docker_user --docker-password=$docker_pass
        kubectl patch serviceaccount default-editor -n kubeflow-admin-example-com -p '{"imagePullSecrets": [{"name": "myregistrykey"}]}'

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

Next:
1. Go to: $KUBEFLOW_URL
2. If a custom certificate (e.g, istio-ingressgateway.istio-system.svc) certificate as trusted (or type "thisisunsafe" into your browser)
3. Login using the admin or example user:
  - Username: admin@example.com | user@example.com
  - Password: 12341234
POSTINSTALL
