# Kubernetes Tutorial: Triển khai MongoDB & Mongo Express

Dự án này hướng dẫn triển khai ứng dụng MongoDB và giao diện quản trị web Mongo Express trên Kubernetes theo 3 phương thức:
1. **Triển khai thủ công (Manual)** bằng các tệp manifest tĩnh (`manual/`).
2. **Triển khai tự động hóa qua Helm Chart** với khả năng tham số hoá và cấu hình linh hoạt (`chart/`).
3. **Triển khai tự động hoá GitOps qua Argo CD** quản lý trạng thái khai báo liên tục (`argocd/`).

---

## 📁 Cấu trúc thư mục

```text
k8s-tutorial/
├── manual/                              # Các manifest Kubernetes thủ công
│   ├── mongo-secret.yaml                # Secret lưu username & password của MongoDB
│   ├── mongo-configmap.yaml             # ConfigMap lưu URL kết nối database
│   ├── mongo.yaml                       # Deployment & Service của MongoDB
│   ├── mongo-express.yaml               # Deployment & Service của Mongo Express
│   ├── mongo-express-ingress.yaml       # Ingress định tuyến domain mongo-express.antd
│   └── mongo-express-secret-tls.yaml    # Secret TLS chứng chỉ HTTPS cho Ingress
│
├── chart/                               # Helm Chart
│   ├── Chart.yaml                       # Metadata thông tin chart
│   ├── values.yaml                      # Các tham số cấu hình mặc định
│   ├── .helmignore                      # Các tệp bỏ qua khi đóng gói chart
│   └── templates/                       # Thư mục chứa các manifest templates
│       ├── _helpers.tpl                 # Hàm tiện ích render name, labels, selector
│       ├── mongo-secret.yaml            # Template Secret
│       ├── mongo-configmap.yaml         # Template ConfigMap
│       ├── mongo-deployment.yaml        # Template Deployment MongoDB
│       ├── mongo-service.yaml           # Template Service MongoDB
│       ├── mongo-express-deployment.yaml# Template Deployment Mongo Express
│       ├── mongo-express-service.yaml   # Template Service Mongo Express
│       ├── mongo-express-ingress.yaml   # Template Ingress Mongo Express
│       ├── mongo-express-secret-tls.yaml# Template Secret TLS (tuỳ chọn)
│       ├── NOTES.txt                    # Hướng dẫn hiển thị sau khi cài đặt helm
│       └── tests/
│           └── test-connection.yaml     # Helm test kiểm tra kết nối
│
├── argocd/                              # Triển khai GitOps với Argo CD
│   ├── application.yaml                 # ArgoCD Application chính (triển khai chart)
│   ├── project.yaml                     # ArgoCD AppProject phân quyền
│   ├── environments/                    # Cấu hình đa môi trường
│   │   ├── application-dev.yaml         # Application môi trường Dev
│   │   └── application-prod.yaml        # Application môi trường Prod
│   ├── app-of-apps.yaml                 # Root Application (App of Apps pattern)
│   ├── repo-secret.yaml                 # Secret cấu hình xác thực Private GitHub Repo
│   ├── install-argocd.sh                # Script cài đặt tự động Argo CD
│   ├── HELM_ARGOCD_GUIDE.md             # Hướng dẫn chi tiết các file Helm & Argo CD
│   └── README.md                        # Hướng dẫn chi tiết triển khai Argo CD
│
└── README.md
```

---

## 🏗️ Kiến trúc hệ thống

```
               [ Trình duyệt / Client ]
                          │
                          ▼
            [ Ingress: mongo-express.antd ]
                          │
                          ▼
      [ Service: mongo-express-service (Port: 8081) ]
                          │
                          ▼
             [ Pod: mongo-express ]
             ├── User/Pass  <─── [ Secret: mongo-secret ]
             └── DB Server  <─── [ ConfigMap: mongo-configmap ]
                          │
                          ▼ (kết nối database_url: mongo-service:27017)
         [ Service: mongo-service (Port: 27017) ]
                          │
                          ▼
                 [ Pod: mongo ]
                 └── Root User/Pass <─── [ Secret: mongo-secret ]
```

---

## 🚀 Hướng dẫn triển khai

### Yêu cầu tiên quyết
- Kubernetes cluster (Minikube, Kind, K3s hoặc Cloud K8s).
- Công cụ dòng lệnh: `kubectl` và `helm` (phiên bản v3+).
- Ingress Controller (nếu sử dụng Ingress, ví dụ: NGINX Ingress Controller trên Minikube: `minikube addons enable ingress`).

---

### Cách 1: Triển khai thủ công (`manual/`)

Chạy các lệnh `kubectl apply` theo đúng thứ tự để đảm bảo các dependency (Secret, ConfigMap) sẵn sàng trước khi Pod khởi tạo:

```bash
# 1. Tạo Secret và ConfigMap
kubectl apply -f manual/mongo-secret.yaml
kubectl apply -f manual/mongo-configmap.yaml

# 2. Triển khai MongoDB (Database)
kubectl apply -f manual/mongo.yaml

# 3. Triển khai Mongo Express (Web UI)
kubectl apply -f manual/mongo-express.yaml

# 4. (Tuỳ chọn) Cấu hình Ingress và Secret TLS
kubectl apply -f manual/mongo-express-ingress.yaml
# Nếu có chứng chỉ TLS thực tế:
# kubectl apply -f manual/mongo-express-secret-tls.yaml
```

**Kiểm tra trạng thái triển khai:**
```bash
kubectl get pods
kubectl get svc
kubectl get ingress
```

---

### Cách 2: Triển khai tự động bằng Helm Chart (`chart/`)

Sử dụng Helm giúp quản lý toàn bộ vòng đời ứng dụng, dễ dàng tuỳ biến môi trường (Dev, Staging, Prod) thông qua `values.yaml` hoặc `--set`.

#### 1. Kiểm tra cú pháp (Lint) và xem trước manifest (Dry-run / Template)
```bash
# Kiểm tra tính hợp lệ của Chart
helm lint chart/

# Xem trước kết quả render manifest mà không cài vào cluster
helm template my-release chart/
```

#### 2. Cài đặt Chart
```bash
helm install my-release chart/
```

#### 3. Cài đặt với các tham số tuỳ chỉnh
Ví dụ tuỳ biến mật khẩu và bật TLS secret:
```bash
helm install my-release chart/ \
  --set secret.data.rootUsername="admin" \
  --set secret.data.rootPassword="StrongPassword123" \
  --set mongoExpress.service.type="NodePort"
```

Hoặc tạo một tệp `my-values.yaml` riêng và cài đặt:
```bash
helm install my-release chart/ -f my-values.yaml
```

#### 4. Nâng cấp hoặc thay đổi cấu hình
```bash
helm upgrade my-release chart/ --set mongoExpress.replicaCount=2
```

#### 5. Chạy kiểm thử (Helm Test)
```bash
helm test my-release
```

#### 6. Gỡ bỏ cài đặt
```bash
helm uninstall my-release
```

---

## 🌐 Hướng dẫn truy cập Mongo Express Web UI

Sau khi triển khai thành công, bạn có thể truy cập Mongo Express qua các cách sau:

### Cách 1: Qua Ingress Domain (`mongo-express.antd`)
1. Lấy IP của Kubernetes Node / Ingress:
   ```bash
   # Nếu dùng Minikube:
   minikube ip
   ```
2. Thêm ánh xạ tên miền vào file `/etc/hosts` trên máy của bạn:
   ```text
   <MINIKUBE_IP> mongo-express.antd
   ```
3. Mở trình duyệt và truy cập: `http://mongo-express.antd`

### Cách 2: Qua Port Forwarding (Nhanh nhất để test)
```bash
kubectl port-forward svc/mongo-express-service 8081:8081
```
Mở trình duyệt truy cập: `http://localhost:8081`

### Cách 3: Qua NodePort (với Minikube)
```bash
minikube service mongo-express-service
```

---

## ⚙️ Bảng tham số cấu hình (`values.yaml`)

| Tham số | Mô tả | Mặc định |
| :--- | :--- | :--- |
| `secret.create` | Tạo Secret cho MongoDB | `true` |
| `secret.name` | Tên Secret | `"mongo-secret"` |
| `secret.existingSecret` | Sử dụng Secret có sẵn thay vì tạo mới | `""` |
| `secret.data.rootUsername` | Tên tài khoản root MongoDB | `"username"` |
| `secret.data.rootPassword` | Mật khẩu root MongoDB | `"password"` |
| `configMap.create` | Tạo ConfigMap kết nối | `true` |
| `configMap.name` | Tên ConfigMap | `"mongo-configmap"` |
| `configMap.databaseUrl` | URL MongoDB Service (để trống sẽ tự sinh theo tên service) | `""` |
| `mongo.enabled` | Bật/tắt component MongoDB | `true` |
| `mongo.image.repository` | Docker image của MongoDB | `"mongo"` |
| `mongo.image.tag` | Phiên bản MongoDB | `"latest"` |
| `mongo.replicaCount` | Số lượng Pod MongoDB | `1` |
| `mongo.service.type` | Loại Service MongoDB | `"ClusterIP"` |
| `mongo.service.port` | Cổng Service MongoDB | `27017` |
| `mongoExpress.enabled` | Bật/tắt component Mongo Express | `true` |
| `mongoExpress.image.repository` | Docker image Mongo Express | `"mongo-express"` |
| `mongoExpress.image.tag` | Phiên bản Mongo Express | `"latest"` |
| `mongoExpress.replicaCount` | Số lượng Pod Mongo Express | `1` |
| `mongoExpress.service.type` | Loại Service Mongo Express | `"LoadBalancer"` |
| `mongoExpress.service.port` | Cổng Service Mongo Express | `8081` |
| `mongoExpress.service.nodePort` | Cổng NodePort Mongo Express (để trống sẽ cấp phát tự động) | `""` |
| `mongoExpress.ingress.enabled` | Kích hoạt Ingress cho Mongo Express | `false` |
| `mongoExpress.ingress.hosts` | Danh sách hosts và paths cho Ingress | `mongo-express.antd` (`/`) |
| `mongoExpress.tlsSecret.enabled` | Kích hoạt tạo Secret TLS riêng | `false` |

---

## 🔄 Thử nghiệm tính năng Multi-Version trong Helm

Helm hỗ trợ quản lý nhiều phiên bản (Multi-version) ở 2 cấp độ:
1. **Chart Repository Versioning**: Đóng gói và lưu trữ nhiều phiên bản chart (`0.1.0`, `0.2.0`, ...) trong repository.
2. **Release Revision & Rollback**: Quản lý lịch sử triển khai, nâng cấp và khôi phục trạng thái ứng dụng.

### 1. Đóng gói nhiều phiên bản Chart
```bash
mkdir -p repo

# Đóng gói phiên bản v0.1.0 (AppVersion 1.0.0, 1 replica Mongo Express)
helm package chart/ --version 0.1.0 --app-version 1.0.0 -d repo/

# Đóng gói phiên bản v0.2.0 (AppVersion 2.0.0, 2 replica Mongo Express)
helm package chart/ --version 0.2.0 --app-version 2.0.0 -d repo/

# Khởi tạo chỉ mục cho Local Repo
helm repo index repo/
```

### 2. Thêm và tìm kiếm các phiên bản trong Repo
```bash
# Phục vụ repo cục bộ (hoặc dùng Web server / ChartMuseum)
python3 -m http.server 8089 --directory repo &

# Thêm repo vào Helm client
helm repo add local-repo http://127.0.0.1:8089
helm repo update

# Tìm kiếm toàn bộ các phiên bản có sẵn (--versions)
helm search repo local-repo --versions
```
**Kết quả:**
```text
NAME            	CHART VERSION	APP VERSION	DESCRIPTION                               
local-repo/chart	0.2.0        	2.0.0      	A Helm chart for MongoDB and Mongo Express
local-repo/chart	0.1.0        	1.0.0      	A Helm chart for MongoDB and Mongo Express
```

### 3. Cài đặt phiên bản cụ thể (`--version 0.1.0`)
```bash
helm install demo-app local-repo/chart --version 0.1.0 -n helm-multi-version --create-namespace
```
Kiểm tra Pods đang chạy 1 replica Mongo Express:
```bash
kubectl get pods -n helm-multi-version
```

### 4. Nâng cấp lên phiên bản mới (`--version 0.2.0`)
```bash
helm upgrade demo-app local-repo/chart --version 0.2.0 -n helm-multi-version
```
Kiểm tra lịch sử phát hành:
```bash
helm history demo-app -n helm-multi-version
```
**Kết quả:**
```text
REVISION	UPDATED                 	STATUS    	CHART      	APP VERSION	DESCRIPTION     
1       	Mon Nov 16 00:01:15 2026	superseded	chart-0.1.0	1.0.0      	Install complete
2       	Mon Nov 16 01:45:07 2026	deployed  	chart-0.2.0	2.0.0      	Upgrade complete
```
*(Số lượng pod Mongo Express tự động scale lên 2 replicas theo cấu hình của v0.2.0)*

### 5. Rollback về phiên bản trước đó (`helm rollback`)
Khi phát hiện lỗi hoặc muốn quay lại phiên bản cũ:
```bash
helm rollback demo-app 1 -n helm-multi-version
```
Helm tự động tạo Revision 3 khôi phục toàn bộ trạng thái của Revision 1:
```bash
helm history demo-app -n helm-multi-version
```
**Kết quả:**
```text
REVISION	UPDATED                 	STATUS    	CHART      	APP VERSION	DESCRIPTION     
1       	Mon Nov 16 00:01:15 2026	superseded	chart-0.1.0	1.0.0      	Install complete
2       	Mon Nov 16 01:45:07 2026	superseded	chart-0.2.0	2.0.0      	Upgrade complete
3       	Mon Nov 16 01:45:25 2026	deployed  	chart-0.1.0	1.0.0      	Rollback to 1   
```

### 6. Kiểm thử kết nối (Helm Test)
```bash
helm test demo-app -n helm-multi-version
# Phase: Succeeded
```

---

### Cách 3: Triển khai liên tục GitOps với Argo CD (`argocd/`)

Phương pháp GitOps sử dụng Git làm **Single Source of Truth** (Nguồn chân lý duy nhất). Argo CD liên tục giám sát trạng thái trong Git và đồng bộ tự động xuống Kubernetes cluster.

#### 1. Cài đặt Argo CD vào Cluster
```bash
# Sử dụng script cài đặt nhanh:
./argocd/install-argocd.sh

# Hoặc bằng lệnh thủ công:
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

#### 2. Lấy mật khẩu và đăng nhập Argo CD Web UI
```bash
# Lấy mật khẩu admin ban đầu:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Port-forward giao diện web:
kubectl port-forward svc/argocd-server -n argocd 8443:443
```
Mở trình duyệt: `https://localhost:8443` (Username: `admin`).

#### 3. Triển khai Helm Chart qua Argo CD Application
```bash
kubectl apply -f argocd/application.yaml
```
Argo CD sẽ tự động tạo namespace `mongo-app`, render chart `chart/` và đồng bộ toàn bộ resources lên cluster với chế độ `self-heal` và `prune`.

#### 4. Triển khai nhiều môi trường (Dev / Prod)
```bash
# Triển khai môi trường Dev:
kubectl apply -f argocd/environments/application-dev.yaml

# Triển khai môi trường Prod:
kubectl apply -f argocd/environments/application-prod.yaml

# Hoặc dùng mô hình Root App-of-Apps:
kubectl apply -f argocd/app-of-apps.yaml
```
Chi tiết cấu hình xem tại [argocd/README.md](file:///home/tranducan/coder/projects/package_github/k8s-tutorial/argocd/README.md).

