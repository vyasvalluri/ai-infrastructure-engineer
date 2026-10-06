# Architecture

## System Model

The repository uses this end-to-end model to connect platform, compute, networking, serving, lifecycle, and automation topics:

```text
                              USERS
                                |
                                v
                         +--------------+
                         | AI PLATFORM  |
                         +--------------+
                                |
                                v
                         +--------------+
                         | Kubernetes   |
                         +--------------+
                                |
                                v
                         GPU SCHEDULING
                                |
                                v
                    NVIDIA GPU Operator
                         /          \
                        v            v
               GPU SOFTWARE     OBSERVABILITY
                    |             DCGM
                   CUDA             |
                    |          Prometheus
              NVIDIA Driver        |
                    |           Grafana
                    v
                   GPU
               /         \
            NVLink       PCIe

     GPU NETWORK: InfiniBand or RoCE -> NCCL -> Distributed AI

     AI SERVING: vLLM | Triton | KServe
     DISTRIBUTED COMPUTE: Ray
     ML LIFECYCLE: MLflow | Kubeflow
     AUTOMATION: Terraform | Ansible
```

## Architectural Layers

| Layer | Concern | Representative technologies |
| --- | --- | --- |
| User and platform | Provide a usable, governed interface to AI capabilities. | AI platform |
| Orchestration | Schedule and operate workloads on cluster resources. | Kubernetes, GPU scheduling |
| GPU enablement | Expose drivers, device plugins, and GPU capabilities to workloads. | NVIDIA GPU Operator, NVIDIA driver, CUDA |
| Compute and interconnect | Execute single-node and distributed GPU work. | GPU, NVLink, PCIe, InfiniBand, RoCE, NCCL |
| Serving | Deploy and serve inference workloads. | vLLM, Triton, KServe |
| Distributed workloads | Coordinate distributed compute and ML lifecycle workflows. | Ray, MLflow, Kubeflow |
| Observability | Measure health, utilization, and service behavior. | DCGM, Prometheus, Grafana |
| Infrastructure automation | Provision infrastructure and configure hosts. | Terraform, Ansible |

## Key Flows

1. The platform submits a workload to the orchestrator; scheduling assigns available GPU capacity.
2. The GPU software stack makes hardware capabilities available to the workload, from driver and CUDA layers down to GPU devices and interconnects.
3. Distributed workloads use the available GPU network and NCCL for collective communication.
4. Serving systems expose model inference, while Ray and ML lifecycle tools support broader workload workflows.
5. DCGM metrics flow into Prometheus and Grafana to support operational visibility.
6. Terraform and Ansible automate infrastructure provisioning and host configuration around the platform.

## Scope Boundary

Kubernetes is an assumed platform substrate, not a standalone course in this repository. Explanations should cover only what a particular AI infrastructure topic requires and include: “Kubernetes fundamentals are covered separately through KodeKloud.” The project centers on AI infrastructure and platform engineering, not ML research or generic AI application development.