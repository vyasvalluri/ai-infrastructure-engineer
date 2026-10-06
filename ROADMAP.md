# Roadmap

The sequence moves from foundational infrastructure toward operating and designing a complete AI platform. Kubernetes is used as an execution environment where needed, but is not taught as a separate course because the learner is covering it through KodeKloud.

| Phase | Module | Focus |
| --- | --- | --- |
| 0 | AI Factory fundamentals | Establish the end-to-end AI infrastructure mental model and its major layers. |
| 1 | Linux for AI infrastructure | Understand the host operating system, devices, processes, storage, and diagnostics. |
| 2 | Containers | Understand container images and runtime requirements for AI workloads. |
| 3 | GPU fundamentals | Learn GPU architecture, memory, execution, and infrastructure implications. |
| 4 | CUDA fundamentals | Connect GPU hardware to its programming and runtime stack. |
| 5 | NVIDIA GPU Operator | Understand cluster-level installation and lifecycle of GPU capabilities. |
| 6 | GPU scheduling + sharing + MIG | Place, partition, and share GPU capacity for different workloads. |
| 7 | NCCL + GPU networking | Understand GPU collectives and the network paths used by distributed AI. |
| 8 | DCGM + Prometheus + Grafana | Observe GPU health, utilization, and platform behavior. |
| 9 | vLLM | Explore high-throughput LLM inference and serving operations. |
| 10 | Triton | Explore model-serving patterns and inference workload operations. |
| 11 | KServe | Understand Kubernetes-native inference deployment and serving workflows. |
| 12 | Ray | Explore distributed compute and orchestration for AI workloads. |
| 13 | MLflow | Understand experiment tracking and model lifecycle management. |
| 14 | Kubeflow | Understand platform workflows for ML lifecycle orchestration. |
| 15 | Terraform | Automate repeatable infrastructure provisioning. |
| 16 | Ansible | Automate host and software configuration. |
| 17 | Mini AI Factory | Integrate platform components into an end-to-end portfolio project. |
| 18 | Troubleshooting | Diagnose failures across hardware, drivers, workloads, networking, and serving. |
| 19 | Architecture Design | Make and communicate system-level design and trade-off decisions. |
| 20 | Interview Preparation | Turn technical understanding and project work into interview-ready answers. |
| 21 | Career / Skill Matrix | Track capabilities and identify next steps toward platform architecture. |

## Completion Guidance

Progress is recorded in [PROGRESS.md](PROGRESS.md). A phase should be considered complete when its learning objectives, practical work, troubleshooting coverage, and interview/design questions are addressed as applicable to that phase. The Mini AI Factory should draw on earlier modules rather than introduce an unrelated technology track.