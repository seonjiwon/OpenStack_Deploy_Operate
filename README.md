# OpenStack 자동화 배포 및 실습 환경 구축
이 저장소는 **Kolla-Ansible** 을 활용하여 Ubuntu 24.04 LTS 환경에서 OpenStack 2025.1 (Epoxy) 버전을 효율적으로 구축하고, Multi-tenant 실습 환경을 자동화하는 스크립트를 포함하고 있습니다.

> ℹ️ 기존 2024.2 (Dalmatian) / Ubuntu 22.04 구성은 **2024.2가 EOL** 되어 컬렉션 stable 브랜치·이미지가 내려가 배포가 불가합니다. → **OpenStack 2025.1 (Epoxy) / Ubuntu 24.04 (noble)** 로 전환했습니다.

<img width="2520" height="1113" alt="image" src="https://github.com/user-attachments/assets/a30f2f17-52ee-4666-8a89-934be7730e0c" />

## 🚀 주요 특징
- **자동화된 AIO 배포**: 한 번의 실행으로 Control Node 및 OpenStack 핵심 서비스 구축.
- **단일노드 VM 지원**: Hyper-V 등 단일 VM에서도 동작 (Cinder 디스크 `sdb` 단독, NIC `eth0`(관리)/`eth1`(외부), 중첩 가상화 없으면 **qemu 자동 폴백**).
- **멀티 노드 확장성**: 새로운 Compute Node를 클러스터에 손쉽게 추가할 수 있는 가이드 및 스크립트 제공.
- **대용량 블록 스토리지**: LVM(Cinder) 기반 스토리지 구성 지원.
- **운영 안정화 내장**: Docker 로그 로테이션, Horizon fd `ulimit` 상향, nova `max_concurrent_builds` 제한, Cinder `image_volume_cache`(convert→clone).
- **실습 환경 자동화**: 팀별 프로젝트 생성, 자원 할당량(Quota) 설정, 네트워크 격리 및 인증 파일(OpenRC) 생성을 자동화.

## 📋 시스템 요구사항
### Control Node (All-in-One)
- **OS**: **Ubuntu 24.04 LTS (noble)** — OpenStack 2025.1은 24.04 전용 (22.04 미지원)
- **RAM**: 권장 32GB 이상 (단일노드 VM은 최소 ~20GB)
- **CPU**: 권장 8 Core (단일노드 VM은 최소 4~6)
- **Disk**: OS 100GB + **Cinder용 빈 디스크(`/dev/sdb`)**
### Compute Node (추가 노드, 멀티노드 시)
- **RAM**: 최소 16GB
- **Disk**: Cinder 볼륨 구성을 위한 미사용 유휴 디스크(LVM VG용)

> 💡 중첩 가상화(KVM)가 불가한 환경(예: VBS가 잠긴 호스트, 일부 클라우드 VM)에서는 `01_deploy_aio.sh`가 `/proc/cpuinfo`에 `vmx/svm`이 없으면 `nova_compute_virt_type`를 **자동으로 qemu**로 전환합니다. 인스턴스 부팅이 느릴 뿐 기능은 동일합니다.

---

## 🛠 실행 순서
### 1단계: Control Node 배포 (All-in-One)
기본적인 OpenStack 컨트롤러 환경을 배포합니다. (이미지 다운로드 포함 약 20~50분)
```bash
sudo bash kolla-ansible/01_deploy_aio.sh 2>&1 | tee 01.log
```
### 2단계: 서비스 초기화
외부 네트워크 생성, 기본 이미지(Ubuntu) 등록, Flavor, image_volume_cache를 설정합니다.
```bash
sudo bash kolla-ansible/02_init_openstack.sh 2>&1 | tee 02.log
```
### 3단계: Compute 노드 추가 (선택 사항, 멀티노드)
새로운 서버를 컴퓨트 노드로 클러스터에 통합합니다. (사전에 `prepare_compute_node.sh` 실행 필요)
```bash
sudo bash kolla-ansible/03_add_compute.sh
```
### 4단계: 실습 팀(Team) 환경 구성
팀별 독립 프로젝트와 네트워크, 고사양 Quota를 배포합니다.
```bash
sudo bash kolla-ansible/04_setup_teams.sh
```
---

## ⚙️ 배포 전 환경값 확인 (필수)
환경에 맞게 아래 값을 먼저 수정하세요.
- **`globals.yml`**: `network_interface`(관리 NIC), `neutron_external_interface`(외부 NIC), `kolla_internal_vip_address`(VIP/노드 IP). 단일노드는 `enable_haproxy: "no"`(VIP=노드 IP), `enable_heat: "no"`(메모리 절약) 권장.
- **`01_deploy_aio.sh`**: `NODE_IP`, `NETWORK_IFACE`, Cinder 디스크(`CINDER_DISK=/dev/sdb`).
- **`02_init_openstack.sh`**: 외부망 `EXTERNAL_NETWORK_CIDR` / `EXTERNAL_GATEWAY` / `FLOATING_IP_*` 범위.

## 📁 주요 스크립트 안내
- `01_deploy_aio.sh`: Kolla-Ansible 설치 및 AIO 배포 전체 자동화 (빌드 의존성·openstackclient·로그 로테이션·ulimit·nova override 포함).
- `02_init_openstack.sh`: 네트워크/이미지/Flavor 등 초기 인프라 설정 + Cinder image_volume_cache.
- `03_add_compute.sh`: Multinode 인벤토리 생성 및 추가 컴퓨트 노드 배포.
- `04_setup_teams.sh`: 팀별 격리 환경(네트워크, 사용자, Quota) 구축 및 OpenRC 생성.
- `prepare_compute_node.sh`: 컴퓨트 노드용 OVS 및 커널 모듈 사전 설정.
- `cleanup_env.sh`: 꼬인 환경(Docker, OVS 찌꺼기 등)을 초기화하는 정리 스크립트.
