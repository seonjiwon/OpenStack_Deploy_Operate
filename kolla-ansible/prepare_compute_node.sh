#!/usr/bin/env bash
# =============================================================================
# prepare_compute_node.sh
# 신규 Compute Node 추가를 위한 사전 환경 및 패키지 설정 스크립트
#
# 실행 위치: 신규 Compute Node (fisa-cloud-dev-2)
# 실행 방법: bash prepare_compute_node.sh
# 소요 시간: 약 5분
#
# 전제조건:
#   - Ubuntu 22.04 LTS 설치 완료
#   - 인터넷 연결 가능 환경
#   - root 또는 sudo 권한
# =============================================================================

# =============================================================================
# 실행 방법: sudo bash prepare_compute_node.sh 2>&1 | tee prepare_compute_node.log
# =============================================================================
set -e
echo "[1/5] Installing and enabling host OVS and LVM packages..."
sudo apt update && sudo apt install -y openvswitch-switch lvm2 xfsprogs open-iscsi
sudo systemctl enable openvswitch-switch
sudo systemctl stop iscsid iscsid.socket || true
sudo systemctl disable iscsid iscsid.socket || true

echo "[2/5] Configuring Cinder LVM Volume Group (cinder-volumes)..."
# /dev/sdb가 존재하는지 확인하고 VG 생성 (이미 존재하면 건너뜀)
if lsblk /dev/sdb &>/dev/null; then
    if ! sudo vgs cinder-volumes &>/dev/null; then
        sudo pvcreate -f /dev/sdb
        sudo vgcreate cinder-volumes /dev/sdb
        echo "Successfully created cinder-volumes VG on /dev/sdb"
    else
        echo "cinder-volumes VG already exists."
    fi
else
    echo "WARNING: /dev/sdb not found. Cinder volume will fail if no disk is provided."
fi

echo "[3/5] Restarting OVS service..."
sudo systemctl restart openvswitch-switch || true
    
echo "[4/5] Starting OVS service and applying netplan..."
sudo systemctl start openvswitch-switch
sudo netplan apply

echo "[5/5] Configuring firewall and kernel modules..."
# Load br_netfilter for bridge filtering (required for Libvirt/OVS)
sudo modprobe br_netfilter
echo "br_netfilter" | sudo tee /etc/modules-load.d/br_netfilter.conf
echo "---------------------------------------------------------"
echo "Compute node preparation complete."