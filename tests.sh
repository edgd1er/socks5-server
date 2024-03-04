#!/usr/bin/env bash
#test local build

#exit on error
set -e

PROXY_HOST="localhost"
SOCK_PORT=1080
FAILED=0
INTERVAL=4
DKRFILE=Dockerfile
DCYML="docker compose -f docker-compose.build.yml"

#fonctions
enableMultiArch() {
  docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
  docker buildx rm amd-arm
  docker buildx create --use --name amd-arm --driver-opt image=moby/buildkit:master --platform=linux/amd64,linux/arm64,linux/386,linux/arm/v7,linux/arm/v6
  docker buildx inspect --bootstrap amd-arm
}

buildAndWait() {
  echo "Stopping and removing running containers"
  ${DCYML} down -v
  echo "Building and starting image"
  ${DCYML} up -d --build
  echo "Waiting for the container to be up.(every ${INTERVAL} sec)"
  logs=""
  n=0
  #  while [ 0 -eq $(echo $logs | grep -c "Initialization Sequence Completed") ]; do
  while [ 0 -eq $(echo $logs | grep -c "Start listening proxy") ]; do
    logs="$(${DCYML} logs)"
    sleep ${INTERVAL}
    ((n+=1))
    echo "loop: ${n}: $(${DCYML} logs | tail -1)"
    [[ ${n} -eq 15 ]] && break || true
  done
  ${DCYML} logs
}

areProxiesPortOpened() {
  for PORT in ${HTTP_PORT} ${SOCK_PORT}; do
    msg="Test connection to port ${PORT}: "
    if [ 0 -eq $(echo "" | nc -v -q 2 ${PROXY_HOST} ${PORT} 2>&1 | grep -c "] succeeded") ]; then
      msg+=" Failed"
      ((FAILED += 1))
    else
      msg+=" OK"
    fi
    echo -e "$msg"
  done
}

testProxies() {
  FAILED=0
  if [[ -n $(which nc) ]]; then
    areProxiesPortOpened
  fi

  #check detected ips
  vpnIP=$(curl -m15 -x socks5://${PROXY_HOST}:${SOCK_PORT} "https://ifconfig.me/ip")
  if [[ $? -eq 0 ]] && [[ ${myIp} == "${vpnIP}" ]] && [[ ${#vpnIP} -gt 0 ]]; then
    echo "socks proxy: IP is ${vpnIP}, mine is ${myIp}"
  else
    echo "Error, curl through socks proxy to https://ifconfig.me/ip failed"
    echo "or IP (${myIp}) == vpnIP (${vpnIP})"
    ((FAILED += 1))
  fi

  echo "# failed tests: ${FAILED}"
  return ${FAILED}
}

#Main
[[ "$HOSTNAME" != phoebe ]] && aptCacher=""
[[ ! -f ${DKRFILE} ]] && echo -e "\nError, Dockerfile is not found\n" && exit 1

docker run --rm -i hadolint/hadolint hadolint "$@" - < Dockerfile

myIp=$(curl -m5 -sq https://ifconfig.me/ip)
buildAndWait
testProxies

${DCYML} down -v