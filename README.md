### Learning Material is following this youtube [video](https://www.youtube.com/watch?v=2T86xAtR6Fo)

# Kubernetes (K8s) Architecture & Concepts

## Introduction
Kubernetes (often abbreviated as K8s) is an open-source container orchestration platform designed to automate the deployment, scaling, and management of containerized applications. It groups containers that make up an application into logical units for easy management and discovery.

## Cluster Architecture
A Kubernetes cluster consists of a set of worker machines, called **nodes**, that run containerized applications. Every cluster has at least one worker node.

![Kubernetes Architecture](Learning_Marerail/K8S.architectur.webp)

The cluster is divided into two main parts:
1.  **Control Plane**: The brain of the cluster. It manages the worker nodes and the Pods in the cluster. In production environments, the control plane usually runs across multiple computers and a cluster usually runs multiple nodes, providing fault-tolerance and high availability.
2.  **Data Plane (Worker Nodes)**: These are the machines (VMs or physical servers) where your actual applications (workloads) run.

## Kubernetes Components
The following diagram illustrates the internal components that make up the Control Plane and the Data Plane.

![Kubernetes Components](Learning_Marerail/k8s.components.webp)

### Control Plane Components
The Control Plane's components make global decisions about the cluster (for example, scheduling), as well as detecting and responding to cluster events (for example, starting up a new pod when a deployment's replicas field is unsatisfied).

*   **kube-apiserver (API Server)**: The front end for the Kubernetes control plane. It exposes the Kubernetes API. All external communication (CLI, UI) and internal communication between components goes through the API server.
*   **etcd**: Consistent and highly-available key value store used as Kubernetes' backing store for all cluster data. It is the "source of truth" for the cluster state.
*   **kube-scheduler (sched)**: Watches for newly created Pods with no assigned node, and selects a node for them to run on based on resource availability and constraints.
*   **kube-controller-manager (c-m)**: Runs controller processes. Logically, each controller is a separate process, but to reduce complexity, they are all compiled into a single binary and run in a single process. Examples include:
    *   *Node Controller*: Notices and responds when nodes go down.
    *   *Replication Controller*: Maintains the correct number of pods.
*   **cloud-controller-manager (c-c-m)**: Embeds cloud-specific control logic. It lets you link your cluster into your cloud provider's API (like AWS, Azure, GCP) and separates the components that interact with that cloud platform from components that only interact with your cluster.

### Data Plane (Node) Components
Node components run on every node, maintaining running pods and providing the Kubernetes runtime environment.

*   **kubelet**: An agent that runs on each node in the cluster. It makes sure that containers are running in a Pod. It takes a set of PodSpecs and ensures that the containers described in those PodSpecs are running and healthy.
*   **kube-proxy (k-proxy)**: A network proxy that runs on each node in your cluster. It maintains network rules on nodes. These network rules allow network communication to your Pods from network sessions inside or outside of your cluster.
*   **Container Runtime**: The software that is responsible for running containers.

## Cloud Provider Integration
When Kubernetes runs on a cloud provider (like AWS, Azure, or Google Cloud), it can integrate deeply with the underlying infrastructure to provision and manage resources automatically. This is primarily handled by the **Cloud Controller Manager (CCM)**.

### How it works
The CCM separates the Kubernetes control loop from the specific API implementation of a cloud provider. This allows cloud providers to release features at their own pace.

### Key Integration Points
1.  **Load Balancers**: When you define a Kubernetes Service with `type: LoadBalancer`, the CCM communicates with the cloud provider's API to provision a native cloud Load Balancer (e.g., AWS ELB, Azure Load Balancer) that routes traffic to your pods.
2.  **Storage (Persistent Volumes)**: Through the **CSI (Container Storage Interface)**, Kubernetes can dynamically provision cloud-native storage. For instance, requesting a PersistentVolumeClaim (PVC) can automatically create an AWS EBS volume or a Google Persistent Disk and attach it to the correct node.
3.  **Node Lifecycle**:
    *   **Node Controller**: Checks if a node has been deleted in the cloud when it stops sending heartbeats.
    *   **Cluster Autoscaler**: Although often a separate component, it works closely with the cloud provider to add or remove worker nodes (VMs) based on the resource demands of your pods.
4.  **Networking (Routes)**: The Route Controller configures routes in the cloud provider's network infrastructure so that containers on different nodes can communicate with each other.

## Ecosystem & Standards

### CNCF (Cloud Native Computing Foundation)
The **CNCF** is a vendor-neutral home for many of the fastest-growing open source projects, including Kubernetes, Prometheus, and Envoy. It fosters the cloud-native ecosystem and ensures that the technology remains accessible and sustainable.

### Container Runtime & CRI
Kubernetes doesn't run containers directly; it relies on a **Container Runtime**. To make it easy to swap different runtimes, Kubernetes uses the **Container Runtime Interface (CRI)**.
*   **Example**: **containerd** is a popular industry-standard container runtime with an emphasis on simplicity, robustness, and portability. Other examples include CRI-O and Docker Engine (via shim).

### CNI (Container Network Interface)
**CNI** consists of a specification and libraries for writing plugins to configure network interfaces in Linux containers, along with a number of supported plugins. Kubernetes uses CNI plugins to handle networking tasks like assigning IP addresses to Pods and setting up routes.
*   **Examples**: Calico, Flannel, Cilium, Weave Net.

### CSI (Container Storage Interface)
**CSI** is a standard for exposing arbitrary block and file storage systems to containerized workloads on Container Orchestration Systems (COs) like Kubernetes. It allows third-party storage providers to deploy plugins exposing new storage systems in Kubernetes without having to touch the core Kubernetes code.
*   **Examples**: AWS EBS CSI driver, Azure Disk CSI driver, Ceph CSI.

---

## Project READMEs
- [p1/README.md](p1/README.md)
- [p2/README.MD](p2/README.MD)