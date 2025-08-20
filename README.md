# On-Prem GitOps App Platform (Mini)


## Cluster Bootstrap Notes
* I chose k3s to run a lightweight local Kubernetes cluster on my personal desktop, inside Windows Subsystem for Linux (WSL).

* At first, I tried using an nginx ingress controller with external-dns + lets-encrypt, but I switched to Tailscale because it provided simpler hooks for external access along with built-in TLS and DNS support.

#### Initial setup
I used a Makefile to automate the k3s provisioning and setup. I disabled Traefik since I didn’t want to use the ingress controller that comes bundled with k3s. In addition to the basic k3s setup, the Makefile includes steps to initialize the cluster:

* Load and install secrets from .secrets.env.example into k3s.

* Configure the kubeconfig in the user’s home directory for local API access.

* Install Argo CD in the k3s cluster, initializing it with a root project and application pointing to this public repository.

The Makefile provides commands to fully provision k3s and prepare it for Argo CD hand-off.

Prerequisites: `kubectl, cmake, curl`
```
cp .secrets.env.example .secrets.env
# Fill out .secrets.env with PAT token from github and OAUTH credentials from tailscale
make all
```

Once these steps were complete, the rest of the service deployments were managed by using GitOps going forward from the `gitops/apps` directory and committing to the `main` branch

## Simple-webapp
I made a simple python flask app with some basic instrumention for prometheus and the necessary readniess/liveness probes for k8s. I also added the `/info` path for the necessary requirements. Example json return from the python flask app running in my local k3s, networked via the tailscale operator.
The url is `https://simple-webapp.tail948a3d.ts.net/info` which is publicly accessible when k3s is spun up
* See source code at [apps/simple-webapp/app.py](apps/simple-webapp/app.py)
```
curl https://simple-webapp.tail948a3d.ts.net/info
{"app":"simple-webapp","build_sha":"sha256:b33c61641a24a56fff02ccec5d4e7809cd258a22185a4105c4c698be2d701126","timestamp":"2025-08-20T03:25:25.167367+00:00"}
```
#### Helm
I used a helm chart to ArgoCD deploy this simple-webapp from the directory gitops/helm/simple-webapp. Some key notes:
* I pinned the helm chart to use the `sha:` digest for pulling images
* I forced the container to use nonRoot and to run as a specific numeric user
* I removed the automounting of service account tokens and gave no RBAC to the service account
* I adjusted resources and requests on the deployments along with a default HPA setup (80% usage)

## Container Build
I set up automation to build the container image in the `apps/simple-webapp` directory, either locally with Docker or through a GitHub Actions workflow.

* The image is built with a non-privileged numeric user, which matches the user specified in the Helm chart deployment spec.
* the `.github/workflows/build.yaml` file contains the working automated builds
* This build pipeline performs trivy scanning (non blocking), basic test of spinning up and hiting the container with an API call, push image to GHCR
* leverages the `sha:` digest and commits it into the helm chart values, which then inturn updates the digest in k3s via gitops automatically

## Other Items of note
* Leveraged the Tailscale kubernetes operator (installed via ArgoCD) and configured tailscale to leverage magic DNS and TLS to allow for public access of the ingress
  * When my k3s cluster is spun up, the url is [https://simple-webapp.tail948a3d.ts.net/info](https://simple-webapp.tail948a3d.ts.net/info)
* I kept all my secrets local to my machine to initialize in k3s, and did not pass secrets via CI. This was the easiest way to prevent committing secrets but there are more mature way of doing this
* Added self hosted runners in the same k3s cluster by using the `actions-runner-controller` operator. This is working by having a ephermeral pods in k3s be a target for a GHA jobs. Confirmed working in my personal github account
  * found in `gitops/apps/self-hosted-runners.yaml` and `gitops/apps/arc-runners`
  * A dependency was `cert-manager` so that was also installed

# Architecture
<img src="diagram.png" alt="Architecture Diagram" width="600"/>

#### Logs
```
kubectl get all -n app
NAME                                 READY   STATUS    RESTARTS   AGE
pod/simple-webapp-58c9cb8f96-k7z6w   1/1     Running   0          12m

NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/simple-webapp   ClusterIP   10.43.113.139   <none>        8000/TCP   10h

NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/simple-webapp   1/1     1            1           10h

NAME                                       DESIRED   CURRENT   READY   AGE
replicaset.apps/simple-webapp-58c9cb8f96   1         1         1       12m

NAME                                                REFERENCE                  TARGETS                        MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/simple-webapp   Deployment/simple-webapp   cpu: 2%/80%, memory: 75%/80%   1         4         1          9h

NAMESPACE   NAME                MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
app         simple-webapp-pdb   2               N/A               0                     9h
```