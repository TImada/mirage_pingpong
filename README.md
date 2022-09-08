# mirage_pingpong
A ping-pong latency measurement tool on MirageOS

## Description
This tool can measure the TCP network latency(round trip time) between two different MirageOS programs.

## Requirement
MirageOS and hypervisor software(Xen or QEMU/KVM) are required.
Libvirt with virsh(https://libvirt.org/) and jq (https://stedolan.github.io/jq/) are also required if you want a JSON format result file.

## Usage
### Usual
1. Edit the following variable in `unikernel.ml` of `pp_client`.
    - `server_ip` (server side IP address)
2.  Configure your target programs. You must assign an IP address for each side in this step.
```
(client side using hvt)
$ mirage configure --ipv4=192.168.122.101/24 -t hvt
(server side using hvt)
$ mirage configure --ipv4=192.168.122.100/24 -t hvt
```
3. Compile your target programs.
4. Launch the server side at first, then the client side.

### Usual run with a JSON output file
1. Modify parameters in `pp_run.sh` so that it can be used on your environment.  
2. Execute `./pp_run.sh xen /path/to/dir` if you want to launch the client and server side programs at `/path/to/dir` on Xen-based physical servers. "virtio" can be used for QEMU/KVM-based physical servers.
3. Execute `./tool/get_latency_stat.sh /path/to/result.json` if you want to get statistical values such as the average latency, 90-percentile and 99-percentile.
