#! /bin/bash
pod_name="ibm-vpc-block-csi-controller"
echo $pod_name
##Check if pods are running
is_running=`kubectl get pods -n kube-system | grep $pod_name | awk '{print $1}'`
if [[ -z $is_running ]] ; then
    echo "vpc csi driver does not exist, Please check if the addon enabled by running `ibmcloud ks cluster addon ls --cluster <cluster-id>`"
    exit
fi
##Replace secrets
echo $(kubectl get secret storage-secret-store -n kube-system -oyaml | grep " slclient.toml: " | awk -F' ' '{ print $2 }') | base64 --decode > /tmp/sl.txt
if [[ ! -z "`uname | grep -i darwin`" ]] ; then
    sed -i ' ' '/.*PassthroughSecret.*/d;/.*API.*/d' /tmp/sl.txt
else
    sed -i '/.*PassthroughSecret.*/d;/.*API.*/d' /tmp/sl.txt
fi
#cat /tmp/sl.txt
if [[ ! -z "`base64 --help | grep wrap`" ]] ; then
    newvalue=`cat /tmp/sl.txt |base64 -w 0`
else
    newvalue=`cat /tmp/sl.txt |base64`
fi
kubectl patch secret -n kube-system storage-secret-store --type='json' -p='[{"op" : "replace" ,"path" : "/data/slclient.toml" ,"value" : '"$newvalue"'}]'
rm /tmp/sl.txt
##Restart Pods
if [[ ! -z $is_running ]] ; then
    kubectl delete pod $is_running -n kube-system
fi
sleep 10
totalAttempt=10
attempt=0
while [[ $attempt -lt $totalAttempt ]]
do
    pod_status=`kubectl get pods -n kube-system | grep $pod_name | awk '{print $3}'`
    echo $pod_status
    if [[ $pod_status == "Running" ]] ; then
         echo "$pod_name restart successful"
         current_keys=`kubectl get secret storage-secret-store -n kube-system -oyaml | grep " slclient.toml: " | awk -F' ' '{ print $2 }' | base64 -d | grep -i PassthroughSecret`
 if [[ ! -z "$current_keys" ]] ; then
                echo "Secret has been overridden while execution of the script, Please re run the script"
         fi
         break
    fi
    attempt=$(($attempt+1))
    echo $attempt
    sleep 10
done
