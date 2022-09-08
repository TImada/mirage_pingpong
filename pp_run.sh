# Copyright (c) 2017 Takayuki Imada <takayuki.imada@gmail.com>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

#! /bin/bash

# Parameters (can be modified)
GUEST="Mirage" # used for a JSON output file
OCAMLVER="4.03.0+flambda" # used for a JSON output file
CLIENTADDR="localhost" # client side Libvirt IP where the pingpong client program runs
SERVERADDR="localhost" # server side Libvirt IP where the pingpong server program runs
PP_CLIENTADDR="192.168.122.101/24" # pp_client IP address with its network mask
PP_SERVERADDR="192.168.122.100/24" # pp_server IP address with its network mask
USER="root" # a user name to execute programs

# Parameters (should not be modified)
APP="pp"
BUF="1"
PLATFORM=${1}
BASEDIR=${2}

CLIENTPATH="./${APP}/${APP}_client"
SERVERPATH="./${APP}/${APP}_server"
CLIENTXML="${PLATFORM}_client.xml"
SERVERXML="${PLATFORM}_server.xml"
CLIENTBIN="${APP}_client.${PLATFORM}"
SERVERBIN="${APP}_server.${PLATFORM}"

# Check the arguments provided
case ${PLATFORM} in
        "xen" )
                VIRSH_C="virsh -c xen+ssh://${CLIENTADDR}";
                VIRSH_S="virsh -c xen+ssh://${SERVERADDR}";
        ;;
        "virtio" )
                VIRSH_C="virsh -c qemu+ssh://${CLIENTADDR}/system";
                VIRSH_S="virsh -c qemu+ssh://${SERVERADDR}/system";
        ;;
        * ) echo "Invalid hypervisor selected"; exit
esac

COMPILER="OCaml ${OCAMLVER}"

# switch an OCaml compiler version to be used
opam switch ${OCAMLVER}
eval `opam config env`

# Build and dispatch a server application
cd ./${SERVERPATH}
make clean
mirage configure --ipv4=${PP_SERVERADDR} -t ${PLATFORM}
make
cd ../

sed -e s@KERNELPATH@${BASEDIR}/${SERVERBIN}@ ./template/${SERVERXML} > ./${SERVERXML}
scp ./${SERVERPATH}/${SERVERBIN} ${USER}@${SERVERADDR}:${BASEDIR}/
SERVERLOG="${OCAMLVER}_${PLATFORM}_${APP}_server.log"
${VIRSH_S} create ./${SERVERXML}

# Dispatch a client side MirageOS VM repeatedly
JSONLOG="./${OCAMLVER}_${PLATFORM}_${APP}.json"
echo -n "{
  \"guest\": \"${GUEST}\",
  \"platform\": \"${PLATFORM}\",
  \"compiler\": \"${COMPILER}\",
  \"records\": [
" > ./${JSONLOG}

CLIENTLOG="${OCAMLVER}_${PLATFORM}_${APP}_client.log"
echo -n '' > ./${CLIENTLOG}

sed -e s@KERNELPATH@${BASEDIR}/${CLIENTBIN}@ ./template/${CLIENTXML} > ./${CLIENTXML}

cd ${CLIENTPATH}
make clean
mirage configure --ipv4=${PP_SERVERADDR} -t ${PLATFORM}
make
cd ../
scp ./${CLIENTPATH}/${CLIENTBIN} ${USER}@${CLIENTADDR}:${BASEDIR}/
sleep 3

echo -n "{ \"payload\": ${BUF}, \"latency\": [" >> ./${JSONLOG}
echo "***** Testing pingpong: Payload size ${BUF} *****"
${VIRSH_C} create ./${CLIENTXML} --console >> ${CLIENTLOG}
VALUES=`sed -e 's/^M/\n/g' ./${CLIENTLOG} | grep Latency | tail -n 1000 | cut -d' ' -f 8 | tr '\n' ','`
echo -n "${VALUES}" >> ./${JSONLOG}
echo -n "]}," >> ./${JSONLOG}

# Correct the generated JSON file
echo -n "]}" >> ./${JSONLOG}
sed -i -e 's/,\]/]/g' ${JSONLOG}

# Print statistics
cat ./${JSONLOG} | jq

# Destroy the server application
${VIRSH_S} destroy server

