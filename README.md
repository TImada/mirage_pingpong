# mirage_pingpong
A ping-pong latency measurement tool on MirageOS

## Description
This tool can measure the TCP network latency(round trip time) between two different MirageOS programs.

## Requirement
MirageOS and hypervisor software(Xen or QEMU/KVM) are required.
Libvirt with virsh(https://libvirt.org/) and jq (https://stedolan.github.io/jq/) are also required if you want a JSON format result file.

## Usage
### Usual
1. Compile a server side program in `pp_server` and a client side program in `pp_client`.
2. Launch the server side at first, then the client side.

### Usual run with a JSON output file
1. Modify parameters in `pp_run.sh` so that it can be used on your environment.  
2. Execute `./pp_run.sh xen /path/to/dir` if you want to launch the client and server side programs at `/path/to/dir` on Xen-based physical servers. "virtio" can be used for QEMU/KVM-based physical servers.
3. Execute `./tool/get_latency_stat.sh /path/to/result.json` if you want to get statistical values such as the average latency, 90-percentile and 99-percentile.
