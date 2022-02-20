# kubernetes the hardway
> https://github.com/kelseyhightower/kubernetes-the-hard-way/tree/master/docs


This is more like a scratch pad which i am planning to orgainse later

---
<br/>

### 1. Provisioning resources

1. create a vpc network (any region)
2. provision a subnet with large IP range 

    ```
        range 10.240.0.0/24
    ```

3. create firewall rule that allows internal communication accross all protocols

    ```
        allow tcp,udp,icmp 
        source-ranges 10.240.0.0/24,10.200.0.0/16
    ```

4. create firewall rule that allows external SSH, ICMP and HTTPS connections

    ```
        allow tcp:22,tcp:6443,icmp
        source-ranges 0.0.0.0/0
    ```

7. compute instances for controller nodes with private network ip

    ``` 
        private-network-ip 10.240.0.1${i} 
    ```

8. compute instances for worker nodes with private network ip

    ``` 
        private-network-ip 10.240.0.2${i} 
        metadata pod-cidr=10.200.${i}.0/24
    ```

    the meta-data pod-cidr is used later

---

### 2. generating certificates

- **admin certificate**
- **kubelet client certificate** - for each worker node

    kuberents uses Node Authorizer, that specifically authorises requests made by kubelets. All kubelets should identify themselves with group `system:node` and username of `system:node:<nodename>`
- **controller manager client certificate** - for each controller node
- **kube-proxy client certificate** 
- **scheduler client certificate**
- **kube-api-server certificate**
- **service account key pair** : controller-manager leverages a key pair to generate and sign service account tokens

kube api server is automatically assigned `kuberenetes` internal dns name which will be linked to first ip address from the address range

---

### 3. creating kubeconfig
kubeconfig files enable Kubernetes clients to locate and authenticate to the Kubernetes API Servers

in each kubeconfig file we need to specify the kube API-Server IP ( IP of external loadbalancer)

    
    - kubeconfig for kubelet in each worker node : point to load-balancer ip
    - kubeconfig for kube-proxy : point to load-balancer ip
    
    - kubeconfig for kube-controller-manager : point to localhost
    - kubeconfig for kube-scheduler : point to localhost
    
    - admin kubeconfig file

---
### 4. Data Encryption key
kuberenetes uses etcd for storing all key-value data. To improve security, we can encrypt this data at rest with an encryption key. 

create encrypt-config.yaml file

---
### 5. Install etcd
---
### 6. Install Controll Plane binaries

``` /etc/kubernetes/config``` - kubernetes config directory
- **kube-apiserver** : REST api endpoint for kuberenetes 
- **kube-controller-manager** : runs control loop - that constantly regulates the state of the system

    [replication controller, endpoints controller, namespace controller, service account controller]
- **kueb-scheduler** : it selects an optimal worker node.
    - scheduler finds feasible nodes and runs set of functions to score them and pics the node with top score. Then it notifies the api-server about its decision.

        [feasible nodes, unscheduled pods, binding process]

