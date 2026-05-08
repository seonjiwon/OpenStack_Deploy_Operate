#!/usr/bin/env bash
# =============================================================================
# 03_add_compute.sh
# 추가 Compute Node 클러스터 통합 및 배포 스크립트
#
# 실행 위치: Control Node
# 실행 방법: bash 03_add_compute.sh
# 소요 시간: 약 20~30분
#
# 전제조건:
#   - 01_deploy_aio.sh 수행 완료
#   - 신규 노드에 prepare_compute_node.sh 수행 완료
#   - Control -> Compute 방향 SSH 키 복제(ssh-copy-id) 완료
# =============================================================================

# =============================================================================
# 실행 방법: sudo bash 03_add_compute.sh 2>&1 | tee 03_add_compute.log
# =============================================================================

# 모든 출력을 터미널과 로그 파일(03_add_compute.log)에 동시에 기록
LOG_FILE="03_add_compute.log"
exec > >(tee -i "$LOG_FILE") 2>&1

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]  $*"; }
log_error()   { echo -e "${RED}[ERROR] $*"; exit 1; }

# ── 환경 변수 설정 ─────────────────────────────────────────────────────────────
CONTROL_IP="172.21.33.67"
COMPUTE_IP="172.21.33.69"
VIP_IP="172.21.33.100"
USER_NAME="user"
VENV_DIR="/opt/kolla-venv"
KOLLA_CONFIG_DIR="/etc/kolla"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. 권한 사전 조정 ─────────────────────────────────────────────────────────
log_info "Kolla 설정 파일 권한 조정 중..."
sudo chmod 644 "${KOLLA_CONFIG_DIR}/passwords.yml" || true
sudo chmod 644 "${KOLLA_CONFIG_DIR}/globals.yml" || true
log_success "권한 조정 완료"

# ── 2. 가상환경 활성화 및 필수 패키지 설치 ──────────────────────────────────
log_info "가상환경 활성화 및 의존성 설치 중..."
source "$VENV_DIR/bin/activate"
pip install -q -U pip
pip install -q docker
kolla-ansible install-deps
log_success "의존성 설치 완료"

# ── 3. SSH 연결 확인 ─────────────────────────────────────────────────────────
log_info "Compute 노드 (${COMPUTE_IP}) SSH 연결 확인..."
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "${USER_NAME}@${COMPUTE_IP}" "echo OK" &>/dev/null; then
  log_error "SSH 접속 실패! 'ssh-copy-id ${USER_NAME}@${COMPUTE_IP}'를 먼저 실행하세요."
fi
log_success "SSH 접속 확인 완료"

# ── 4. 상세 Multinode 인벤토리 생성 (모든 프록시 그룹 포함) ──────────────────
log_info "상세 multinode 인벤토리 생성 중 (프록시 누락 완벽 차단)..."
cat > "${SCRIPT_DIR}/multinode" << EOF
[control]
${CONTROL_IP}  ansible_user=${USER_NAME} ansible_become=true

[network]
${CONTROL_IP}  ansible_user=${USER_NAME} ansible_become=true

[compute]
# dev-1 (Control Node)도 Compute 역할을 수행합니다.
${CONTROL_IP}  ansible_user=${USER_NAME} ansible_become=true cinder_backend_lvm=yes iscsi_protocol=iscsi
# dev-2 (Compute Node)
${COMPUTE_IP}  ansible_user=${USER_NAME} ansible_become=true cinder_backend_lvm=yes iscsi_protocol=iscsi

[monitoring]
${CONTROL_IP}  ansible_user=${USER_NAME} ansible_become=true

[storage]
${CONTROL_IP}  ansible_user=${USER_NAME} ansible_become=true
${COMPUTE_IP}  ansible_user=${USER_NAME} ansible_become=true

[deployment]
localhost  ansible_connection=local

# ==============================================================================
# Kolla-Ansible 공식 기본 템플릿의 그룹 매핑 구조 (수정 금지)
# 이 아래의 [xxx:children] 그룹들은 지우거나 임의로 하드코딩하지 마세요.
# Kolla가 알아서 필요한 에이전트(cinder-volume, iscsid, ovn-controller 등)를 
# 위에서 정의한 5개 핵심 물리 노드 그룹에 적절히 배포합니다.
# ==============================================================================
[baremetal:children]
control
network
compute
storage
monitoring

[tls-backend:children]
control
network

[common:children]
control
network
compute
storage
monitoring

[collectd:children]
compute

[grafana:children]
monitoring

[etcd:children]
control

[influxdb:children]
monitoring

[prometheus:children]
monitoring

[telegraf:children]
compute
control
monitoring
network
storage

[hacluster:children]
control

[hacluster-remote:children]
compute

[loadbalancer:children]
network

[mariadb:children]
control

[rabbitmq:children]
control

[keystone:children]
control

[glance:children]
control

[nova:children]
control

[neutron:children]
network

[openvswitch:children]
network
compute
manila-share

[cinder:children]
control

[cloudkitty:children]
control

[memcached:children]
control

[horizon:children]
control

[swift:children]
control

[barbican:children]
control

[heat:children]
control

[ironic:children]
control

[magnum:children]
control

[mistral:children]
control

[manila:children]
control

[ceilometer:children]
control

[aodh:children]
control

[cyborg:children]
control

[gnocchi:children]
control

[tacker:children]
control

[trove:children]
control

[watcher:children]
control

[octavia:children]
control

[designate:children]
control

[placement:children]
control

[bifrost:children]
deployment

[zun:children]
control

[skyline:children]
control

[redis:children]
control

[blazar:children]
control

[venus:children]
monitoring

[letsencrypt:children]
loadbalancer

[cron:children]
common

[fluentd:children]
common

[kolla-logs:children]
common

[kolla-toolbox:children]
common

[opensearch:children]
control

[opensearch-dashboards:children]
opensearch

[glance-api:children]
glance

[nova-api:children]
nova

[nova-conductor:children]
nova

[nova-super-conductor:children]
nova

[nova-novncproxy:children]
nova

[nova-scheduler:children]
nova

[nova-spicehtml5proxy:children]
nova

[nova-compute-ironic:children]
nova

[nova-serialproxy:children]
nova

[neutron-server:children]
control

[neutron-dhcp-agent:children]
neutron

[neutron-l3-agent:children]
neutron

[neutron-metadata-agent:children]
neutron

[neutron-ovn-metadata-agent:children]
compute
network

[neutron-bgp-dragent:children]
neutron

[neutron-infoblox-ipam-agent:children]
neutron

[neutron-metering-agent:children]
neutron

[ironic-neutron-agent:children]
neutron

[neutron-ovn-agent:children]
compute
network

[cinder-api:children]
cinder

[cinder-backup:children]
storage

[cinder-scheduler:children]
cinder

[cinder-volume:children]
storage

[cloudkitty-api:children]
cloudkitty

[cloudkitty-processor:children]
cloudkitty

[iscsid:children]
compute
storage
ironic

[tgtd:children]
storage

[manila-api:children]
manila

[manila-scheduler:children]
manila

[manila-share:children]
network

[manila-data:children]
manila

[swift-proxy-server:children]
swift

[swift-account-server:children]
storage

[swift-container-server:children]
storage

[swift-object-server:children]
storage

[barbican-api:children]
barbican

[barbican-keystone-listener:children]
barbican

[barbican-worker:children]
barbican

[heat-api:children]
heat

[heat-api-cfn:children]
heat

[heat-engine:children]
heat

[ironic-api:children]
ironic

[ironic-conductor:children]
ironic

[ironic-inspector:children]
ironic

[ironic-tftp:children]
ironic

[ironic-http:children]
ironic

[magnum-api:children]
magnum

[magnum-conductor:children]
magnum

[mistral-api:children]
mistral

[mistral-executor:children]
mistral

[mistral-engine:children]
mistral

[mistral-event-engine:children]
mistral

[ceilometer-central:children]
ceilometer

[ceilometer-notification:children]
ceilometer

[ceilometer-compute:children]
compute

[ceilometer-ipmi:children]
compute

[aodh-api:children]
aodh

[aodh-evaluator:children]
aodh

[aodh-listener:children]
aodh

[aodh-notifier:children]
aodh

[cyborg-api:children]
cyborg

[cyborg-agent:children]
compute

[cyborg-conductor:children]
cyborg

[gnocchi-api:children]
gnocchi

[gnocchi-statsd:children]
gnocchi

[gnocchi-metricd:children]
gnocchi

[trove-api:children]
trove

[trove-conductor:children]
trove

[trove-taskmanager:children]
trove

[multipathd:children]
compute
storage

[watcher-api:children]
watcher

[watcher-engine:children]
watcher

[watcher-applier:children]
watcher

[octavia-api:children]
octavia

[octavia-driver-agent:children]
octavia

[octavia-health-manager:children]
octavia

[octavia-housekeeping:children]
octavia

[octavia-worker:children]
octavia

[designate-api:children]
designate

[designate-central:children]
designate

[designate-producer:children]
designate

[designate-mdns:children]
network

[designate-worker:children]
designate

[designate-sink:children]
designate

[designate-backend-bind9:children]
designate

[placement-api:children]
placement

[zun-api:children]
zun

[zun-wsproxy:children]
zun

[zun-compute:children]
compute

[zun-cni-daemon:children]
compute

[skyline-apiserver:children]
skyline

[skyline-console:children]
skyline

[tacker-server:children]
tacker

[tacker-conductor:children]
tacker

[blazar-api:children]
blazar

[blazar-manager:children]
blazar

[prometheus-node-exporter:children]
monitoring
control
compute
network
storage

[prometheus-mysqld-exporter:children]
mariadb

[prometheus-memcached-exporter:children]
memcached

[prometheus-cadvisor:children]
monitoring
control
compute
network
storage

[prometheus-alertmanager:children]
monitoring

[prometheus-openstack-exporter:children]
monitoring

[prometheus-elasticsearch-exporter:children]
opensearch

[prometheus-blackbox-exporter:children]
monitoring

[prometheus-libvirt-exporter:children]
compute

[masakari-api:children]
control

[masakari-engine:children]
control

[masakari-hostmonitor:children]
control

[masakari-instancemonitor:children]
compute

[ovn-controller:children]
ovn-controller-compute
ovn-controller-network

[ovn-controller-compute:children]
compute

[ovn-controller-network:children]
network

[ovn-database:children]
control

[ovn-northd:children]
ovn-database

[ovn-nb-db:children]
ovn-database

[ovn-sb-db:children]
ovn-database

[venus-api:children]
venus

[venus-manager:children]
venus

[letsencrypt-webserver:children]
letsencrypt

[letsencrypt-lego:children]
letsencrypt
EOF
log_success "상세 인벤토리 생성 완료"

# ── 5. globals.yml 업데이트 (HAProxy & OVS 호스트 모드) ───────────────────────
log_info "globals.yml 설정 업데이트 중..."
sudo sed -i "s/^kolla_internal_vip_address:.*/kolla_internal_vip_address: \"${VIP_IP}\"/" "${KOLLA_CONFIG_DIR}/globals.yml"
sudo sed -i "s/^enable_haproxy:.*/enable_haproxy: \"yes\"/" "${KOLLA_CONFIG_DIR}/globals.yml"
sudo sed -i "s/^enable_tgtd:.*/enable_tgtd: \"yes\"/" "${KOLLA_CONFIG_DIR}/globals.yml" || echo 'enable_tgtd: "yes"' | sudo tee -a "${KOLLA_CONFIG_DIR}/globals.yml"

# OVS가 비활성화되면 컴퓨트 노드 네트워크가 안 될 수 있으므로 주석 처리 또는 yes 유지
# if grep -q "enable_openvswitch" "${KOLLA_CONFIG_DIR}/globals.yml"; then
#     sudo sed -i 's/^#*enable_openvswitch:.*/enable_openvswitch: "no"/' "${KOLLA_CONFIG_DIR}/globals.yml"
# else
#     echo 'enable_openvswitch: "no"' | sudo tee -a "${KOLLA_CONFIG_DIR}/globals.yml"
# fi

# ── 6. Compute 노드 배포 ──────────────────────────────────────────────────
log_info "Compute 노드 배포 시작..."

# 호스트 iscsid 충돌 방지 (컴퓨트 노드 대상)
log_info "호스트 iscsid 서비스 충돌 방지 조치 중..."
ssh -o StrictHostKeyChecking=no "${USER_NAME}@${COMPUTE_IP}" "sudo systemctl stop iscsid iscsid.socket || true; sudo systemctl disable iscsid iscsid.socket || true; sudo docker rm -f iscsid || true"

log_info "Step [1/2]: bootstrap-servers 실행..."
kolla-ansible bootstrap-servers -i "${SCRIPT_DIR}/multinode" --limit control,compute

log_info "Step [2/2]: deploy 실행 (변수 강제 주입 및 태스크 강제 실행)..."
kolla-ansible deploy -i "${SCRIPT_DIR}/multinode" \
  -e "enable_iscsid=yes" \
  -e "enable_tgtd=yes" \
  -e "enable_cinder_backend_lvm=yes" \
  --limit control,compute,iscsid,tgtd,storage,network \
  --tags common,iscsi,tgtd,cinder,nova,neutron,ovn

log_success "Compute node deployment complete. Log: $LOG_FILE"

# ── 7. 결과 확인 ─────────────────────────────────────────────────────────────
source "$HOME/admin-openrc.sh"
echo "--- Compute Service List ---"
openstack compute service list
echo "--- Hypervisor List ---"
openstack hypervisor list
