#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "🚀 Bắt đầu cài đặt Argo CD trên Kubernetes"
echo "=========================================="

# 1. Kiểm tra kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ Lỗi: Không tìm thấy lệnh 'kubectl'. Vui lòng cài đặt kubectl trước."
    exit 1
fi

# 2. Tạo namespace argocd nếu chưa tồn tại
echo "📦 1. Tạo namespace 'argocd'..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# 3. Cài đặt Argo CD manifest chính thức (sử dụng --server-side để tránh lỗi annotation limit > 262144 bytes của CRD)
echo "📥 2. Cài đặt Argo CD manifests (Server-side Apply)..."
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 4. Chờ cho các Pod của Argo CD khởi động xong
echo "⏳ 3. Chờ các Pods Argo CD sẵn sàng (Rollout status)..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

echo "=========================================="
echo "✅ Argo CD đã sẵn sàng!"
echo "=========================================="

# 5. Lấy mật khẩu admin ban đầu
echo "🔑 Mật khẩu quản trị mặc định (admin):"
ADMIN_PASSWORD=""
for i in {1..10}; do
    ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || true)
    if [ -n "$ADMIN_PASSWORD" ]; then
        break
    fi
    sleep 2
done
if [ -z "$ADMIN_PASSWORD" ]; then
    ADMIN_PASSWORD="<Không tìm thấy secret hoặc đã đổi mật khẩu - hãy thử lại sau ít giây>"
fi
echo "   Username: admin"
echo "   Password: ${ADMIN_PASSWORD}"

echo ""
echo "🌐 Để mở giao diện Web Argo CD, chạy lệnh sau:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8443:443"
echo "   Sau đó mở trình duyệt: https://localhost:8443"
echo ""
echo "🚀 Để deploy Helm chart qua Argo CD:"
echo "   kubectl apply -f argocd/application.yaml"
echo "=========================================="
