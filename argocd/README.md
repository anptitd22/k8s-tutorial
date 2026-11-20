# Hướng dẫn triển khai GitOps với Argo CD & Helm Chart

Thư mục này chứa toàn bộ cấu hình để triển khai ứng dụng MongoDB & Mongo Express từ Helm Chart (`chart/`) lên Kubernetes theo mô hình **GitOps** sử dụng **Argo CD**.

---

## 📁 Cấu trúc thư mục `argocd/`

```text
argocd/
├── application.yaml          # Manifest ArgoCD Application triển khai trực tiếp Helm Chart
├── project.yaml              # Manifest ArgoCD AppProject để quản lý phân quyền và nguồn Git
├── environments/             # Manifest triển khai phân tách theo môi trường
│   ├── application-dev.yaml  # Môi trường Dev (1 replica, NodePort)
│   └── application-prod.yaml # Môi trường Prod (2 replicas, Ingress, ClusterIP)
├── app-of-apps.yaml          # Quản trị theo mô hình Root Application (App of Apps)
├── repo-secret.yaml          # Mẫu Secret chứa token cho GitHub Private Repo
├── install-argocd.sh         # Script tự động cài đặt Argo CD trên Kubernetes
├── HELM_ARGOCD_GUIDE.md      # Giải thích chi tiết cơ chế Helm trong Argo CD
└── README.md                 # Tài liệu hướng dẫn chi tiết
```

---

## ⚙️ Nguyên lý hoạt động GitOps với Helm Chart

Argo CD giám sát trực tiếp Git repository `https://github.com/anptitd22/k8s-tutorial.git`:
1. Khi có commit mới đẩy lên nhánh `main` (thay đổi trong `chart/templates/` hoặc `chart/values.yaml`), Argo CD tự động phát hiện sự sai lệch giữa Git và Cluster (Out-of-Sync).
2. Nhờ cấu hình `automated: { prune: true, selfHeal: true }`, Argo CD sẽ tự động đồng bộ (Auto Sync) các thay đổi vào Kubernetes cluster.
3. Nếu ai đó sửa thủ công cấu hình trong cluster bằng `kubectl edit/delete`, tính năng `selfHeal` sẽ tự động khôi phục về trạng thái được định nghĩa trên Git.

---

## 🚀 Hướng dẫn triển khai từng bước

### Bước 1: Cài đặt Argo CD lên Cluster

Bạn có thể chạy script tự động:
```bash
./argocd/install-argocd.sh
```

Hoặc thực hiện thủ công bằng các lệnh sau:
```bash
# 1. Tạo namespace argocd
kubectl create namespace argocd

# 2. Áp dụng manifest chính thức của Argo CD (dùng --server-side --force-conflicts để tránh lỗi giới hạn kích thước annotation của CRD)
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 3. Chờ các pod sẵn sàng
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
```

### Bước 2: Đăng nhập giao diện Argo CD

1. **Lấy mật khẩu ban đầu của tài khoản `admin`:**
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
   ```

2. **Chuyển tiếp cổng (Port-forward) Argo CD Server:**
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8443:443
   ```

3. **Mở trình duyệt:**
   - Truy cập: `https://localhost:8443` (chấp nhận cảnh báo chứng chỉ tự ký nếu có).
   - Tên đăng nhập: `admin`
   - Mật khẩu: Kết quả lấy được ở trên.

---

### Bước 3: Triển khai ứng dụng qua Argo CD

#### Cách 1: Triển khai đơn giản (`application.yaml`)

Áp dụng tệp `application.yaml` để Argo CD triển khai Chart vào namespace `mongo-app`:
```bash
kubectl apply -f argocd/application.yaml
```

Kiểm tra trạng thái trên Argo CD:
- Tên app: `mongo-stack`
- Trạng thái: `Healthy` và `Synced`.

Kiểm tra Pods được tạo bởi Argo CD:
```bash
kubectl get pods -n mongo-app
kubectl get svc -n mongo-app
```

---

#### Cách 2: Triển khai nhiều môi trường (Dev / Prod)

Bạn có thể triển khai môi trường cụ thể với các tham số tuỳ biến (`helm parameters`):

```bash
# Triển khai môi trường Dev (namespace mongo-dev)
kubectl apply -f argocd/environments/application-dev.yaml

# Triển khai môi trường Prod (namespace mongo-prod)
kubectl apply -f argocd/environments/application-prod.yaml
```

---

#### Cách 3: Mô hình App-of-Apps (Nâng cao)

Thay vì áp dụng từng Application đơn lẻ, bạn chỉ cần áp dụng một Application gốc (`root-application`). Root app này sẽ tự động đọc thư mục `argocd/environments/` và triển khai tất cả các ứng dụng con:

```bash
kubectl apply -f argocd/app-of-apps.yaml
```

---

## 🔒 Quản lý dự án với AppProject (`project.yaml`)

Để tăng cường bảo mật và giới hạn quyền hạn:
```bash
kubectl apply -f argocd/project.yaml
```
Tệp `project.yaml` đảm bảo:
- Chỉ cho phép deploy các ứng dụng từ repository Git chính thức.
- Giới hạn các namespace đích (chỉ cho phép các namespace có tiền tố `mongo-*` hoặc `default`).
- Kiểm soát danh sách resource được phép tạo.
