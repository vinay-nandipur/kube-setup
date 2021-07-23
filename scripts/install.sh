
#!/usr/bin/env bash

get_script_dir () {
      SOURCE="${BASH_SOURCE[0]}"
      # While $SOURCE is a symlink, resolve it
      while [ -h "$SOURCE" ]; do
         DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
         SOURCE="$( readlink "$SOURCE" )"
         # If $SOURCE was a relative symlink (so no "/" as prefix, need to resolve it relative to the symlink base directory
         [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
      done
      DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
      echo "$DIR"
    }

directory_path="$(get_script_dir)"

tput setaf 6; echo "====================Installing Kind Tool...===================="

os_type=$(uname -a 2>&1)

if [[ "$os_type" == *"Darwin"* ]]
then
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-darwin-amd64
  chmod +x ./kind
  sudo mv ./kind /usr/local/bin/kind
else
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
  chmod +x ./kind
  mv ./kind /usr/bin/kind
fi

kind_status=$(kind version 2>&1)

if [[ "$kind_status" == *"darwin/amd64"* ]]
then
  tput setaf 2; echo "====================Kind Tool Installation Completed!===================="
else
  tput setaf 1; echo "====================Kind Tool Installation Failed!===================="
  exit 1
fi

tput setaf 6; echo "====================Creating Kind Kubernetes Cluster...===================="

kind create cluster --config $directory_path/../configs/multi-node.yaml

cluster_status=$(kind get clusters 2>&1)

if [[ "$cluster_status" == *"No kind clusters found"* ]]
then
  tput setaf 1; echo "====================Kind Kubernetes Cluster Creation Failed!===================="
  exit 1
else
  tput setaf 2; echo "====================Kind Kubernetes Cluster Creation Completed!===================="
fi

tput setaf 6; echo "====================Installing HELM...===================="

curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

helm_status=$(helm version 2>&1)

if [[ "$helm_status" == *"version.BuildInfo"* ]]
then
  tput setaf 2; echo "====================HELM Installation Completed!===================="
else
  tput setaf 1; echo "====================HELM Installation Failed!===================="
  exit 1
fi

tput setaf 6; echo "====================Installing kubectl...===================="

os_type=$(uname -a 2>&1)

if [[ "$os_type" == *"Darwin"* ]]
then
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl.sha256"
  validation=$(echo "$(<kubectl.sha256)  kubectl" | shasum -a 256 --check 2>&1)
  if [[ "$validation" == *"OK"* ]]
  then
    chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
  fi
else
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
  validation=$(echo "$(<kubectl.sha256) kubectl" | sha256sum --check 2>&1)
  if [[ "$validation" == *"OK"* ]]
  then
    chmod +x kubectl
    mkdir -p ~/.local/bin/kubectl
    mv ./kubectl ~/.local/bin/kubectl
    touch ~/.bash_profile
    echo "export PATH=$PATH:~/.local/bin/kubectl" > ~/.bash_profile
    source ~/.bash_profile
  fi
fi

kubectl_status=$(kubectl version --client 2>&1)

if [[ "$kubectl_status" == *"Client Version"* ]]
then
  tput setaf 2; echo "====================kubectl Installation Completed!===================="
else
  tput setaf 1; echo "====================kubectl Installation Failed!===================="
  exit 1
fi

tput setaf 6; echo "====================Installing Concourse-CI...===================="

helm repo add concourse https://concourse-charts.storage.googleapis.com/
helm repo update
kubectl create namespace concourse
helm install local-concourse -n concourse concourse/concourse
tput setaf 3; echo "====================Waiting for Concourse-CI PODS to be ready...===================="
kubectl wait pod -l app=local-concourse-web -n concourse --for condition=ready --timeout=100s
export POD_NAME=$(kubectl get pods --namespace concourse -l "app=local-concourse-web" -o jsonpath="{.items[0].metadata.name}")
nohup /bin/bash -c "kubectl port-forward --namespace concourse $POD_NAME 8080:8080 &"

concourse_status=$(lsof -iTCP -sTCP:LISTEN -n -P | grep 8080 2>&1)

if [[ "$concourse_status" == *"8080"* ]]
then
  tput setaf 2; echo "====================Concourse CI Server Setup Completed!===================="
else
  tput setaf 1; echo "====================Concourse CI Server Setup Failed!===================="
  exit 1
fi
