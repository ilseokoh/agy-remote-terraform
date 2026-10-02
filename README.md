# agy-remote-terraform

Antigravity 원격 VM(`ag-vm-1`) 및 Cloud Run 리버스 프록시(`remote-browser-vm1`) 환경을 구축하는 Terraform 코드입니다.

## 1. 사전 준비 (Prerequisites)

1. **Terraform 설치** (`>= 1.5.0`)
2. **Google Cloud SDK (`gcloud`) 인증**
   Terraform이 GCP 리소스를 생성할 수 있도록 Application Default Credentials(ADC) 로그인을 수행합니다.
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```
   > **권한 참고**: 조직 정책(`constraints/compute.requireOsLogin`, `constraints/compute.vmExternalIpAccess`, `constraints/run.managed.requireInvokerIam`)을 해제하려면 실행 계정에 조직 수준 또는 프로젝트의 **Organization Policy Administrator (`roles/orgpolicy.policyAdmin`)** 권한이 필요합니다.

---

## 2. 변수 설정 (`terraform.tfvars`)

예시 파일을 복사하여 실제 배포할 GCP 프로젝트 ID 등을 설정합니다.

```bash
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` 파일을 열어 `project_id`를 대상 GCP 프로젝트 ID로 수정합니다:

```hcl
project_id             = "agy-remote-vm-prj" # 대상 GCP 프로젝트 ID로 변경
region                 = "us-central1"
zone                   = "us-central1-a"
manage_org_policies    = true                # 조직 정책 해제 권한이 없거나 이미 해제된 경우 false로 변경
vm_name                = "ag-vm-1"
vm_machine_type        = "e2-standard-16"
vm_image               = "ubuntu-os-cloud/ubuntu-2604-resolute-amd64-v20260918"
cloud_run_service_name = "remote-browser-vm1"
cloud_run_image        = "us-docker.pkg.dev/qwiklabs-resources/lfs-images/nginx-reverse-proxy:latest"
```

---

## 3. Terraform 실행

```bash
# 1) 프로바이더 플러그인 초기화
terraform init

# 2) 생성될 리소스 계획 확인
terraform plan

# 3) 리소스 배포 (확인 프롬프트에 yes 입력, 또는 -auto-approve 옵션 추가)
terraform apply
```

`terraform.tfvars` 파일 없이 명령줄에서 바로 프로젝트 ID를 지정해 실행할 수도 있습니다:
```bash
terraform apply -var="project_id=YOUR_PROJECT_ID"
```

---

## 4. 배포 확인

배포가 완료되면 아래와 같은 Output 값들이 출력됩니다:

- `cloud_run_url`: 브라우저로 접속할 Cloud Run URL (`https://remote-browser-vm1-....run.app`)
- `vm_internal_ip`: GCE VM 내부 IP (Cloud Run의 `EXTERNAL_IP` 환경변수로 연결됨)
- `vm_external_ip`: GCE VM 외부 IP
- `service_account_email`: 생성된 `antigravity-sa` 서비스 계정 이메일

> **참고**: VM 생성 직후 `startup-script.sh`가 실행되어 Docker 설치 및 컨테이너 이미지(`build-with-google:07222026-all`) 다운로드가 백그라운드에서 진행되므로, 실제 웹 UI 접속까지 약 **3~5분** 정도 소요될 수 있습니다.
> 진행 상태는 아래 명령어로 확인할 수 있습니다:
> ```bash
> gcloud compute ssh ag-vm-1 --zone=us-central1-a --command="sudo journalctl -u google-startup-scripts.service -f"
> ```

---

## 5. 리소스 삭제 (정리)

생성한 모든 인프라를 삭제하려면 아래 명령어를 실행합니다:

```bash
terraform destroy
```
