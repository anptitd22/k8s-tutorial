# Phân tích & Hướng dẫn: Chuyển đổi MongoDB từ Deployment sang StatefulSet trên Kubernetes

Tài liệu này giải thích chi tiết lý do kỹ thuật, so sánh kiến trúc và hướng dẫn triển khai MongoDB dưới dạng **StatefulSet** kết hợp **Persistent Volume Claims (`volumeClaimTemplates`)** thay vì `Deployment`.

---

## 1. Bối cảnh & Vấn đề của thiết lập ban đầu

Trong kiến trúc ban đầu của Helm chart:
* MongoDB được khai báo dưới dạng một **Kubernetes Deployment** (`templates/mongo-deployment.yaml`).
* Danh sách `volumes: []` và `volumeMounts: []` trong `values.yaml` bị để trống.
* MongoDB container (`mongo:latest`) mặc định lưu toàn bộ dữ liệu bảng, chỉ mục và nhật ký giao dịch (WiredTiger engine) tại thư mục nội bộ `/data/db`.

### Rủi ro nghiêm trọng:
1. **Mất toàn bộ dữ liệu (Data Loss)**: Khi Pod bị crash, bị OOMKilled, node gặp sự cố khiến Pod bị reschedule, hoặc khi thực hiện `helm upgrade` / `kubectl rollout restart`, toàn bộ dữ liệu trên writable layer của container sẽ **bị xóa vĩnh viễn**.
2. **Không có tính bền vững (Non-persistent)**: Một hệ quản trị cơ sở dữ liệu (DBMS) không thể chạy như một ứng dụng phi trạng thái (stateless) thông thường.

---

## 2. So sánh hai hướng tiếp cận lưu trữ cho MongoDB

| Tiêu chí | Hướng 1: Deployment + PVC độc lập | Hướng 2: StatefulSet + `volumeClaimTemplates` (Được chọn) |
| :--- | :--- | :--- |
| **Bản chất workload** | Thiết kế cho ứng dụng Stateless (Web, API) | Thiết kế chuyên biệt cho ứng dụng Stateful (Database, Queue) |
| **Định danh Pod** | Ngẫu nhiên (vd: `mongo-7d8b5c9f4-x8k2p`) | Ổn định và có thứ tự (vd: `mongo-0`, `mongo-1`) |
| **Cơ chế gắn Volume** | 1 PVC dùng chung hoặc gắn tĩnh vào Pod template | Mỗi Pod tự động sở hữu 1 PVC độc lập qua `volumeClaimTemplates` |
| **Hành vi khi Rolling Update** | Thường xuyên gặp lỗi `Multi-Attach error for volume` do Pod mới khởi tạo trước khi Pod cũ kịp giải phóng khóa volume ReadWriteOnce (RWO) | Tuân thủ thứ tự tắt Pod cũ -> Pod mới tái sử dụng chính xác PVC mang cùng chỉ số thứ tự |
| **Khả năng mở rộng (Scale)** | Không thể scale > 1 replica an toàn (nhiều Pod ghi đè cùng 1 disk gây hỏng file database) | Dễ dàng mở rộng, mỗi replica có đĩa riêng, làm tiền đề cho MongoDB ReplicaSet |
| **An toàn dữ liệu khi Scale Down** | Khó kiểm soát việc thu hồi ổ đĩa | Kubernetes **không tự động xóa PVC** khi scale down, đảm bảo không bao giờ mất dữ liệu do sơ suất |

---

## 3. Tại sao chọn Hướng 2 (StatefulSet)?

### 3.1. Tránh triệt để lỗi "Multi-Attach error" khi cập nhật Pod
* Các loại đĩa lưu trữ đám mây phổ biến (AWS EBS, GCP Persistent Disk, Azure Disk, Ceph RBD, HostPath/Local PV) thường có chế độ truy cập là `ReadWriteOnce` (RWO) — tức là chỉ một Node/Pod được phép đính kèm (attach) tại một thời điểm.
* Với `Deployment`, chiến lược cập nhật mặc định là `RollingUpdate`. Kubernetes sẽ tạo một Pod mới trước khi xóa Pod cũ. Cả hai Pod (cũ và mới) sẽ cùng cố gắng mount vào cùng một PVC RWO dẫn đến lỗi bế tắc:
  ```text
  Warning  FailedAttachVolume  Multi-Attach error for volume "pvc-xxx" Volume is already exclusively attached to one node and can't be attached to another
  ```
  Pod mới sẽ bị kẹt vĩnh viễn ở trạng thái `ContainerCreating`.
* Với `StatefulSet`, Kubernetes đảm bảo thứ tự tuần tự: Pod cũ sẽ nhận tín hiệu dừng (Graceful Shutdown) -> Volume được unmount sạch sẽ -> Pod mới được lập lịch và mount lại đúng ổ đĩa `data-mongo-0`.

### 3.2. Định danh mạng và Storage ổn định (Stable Identity)
* Pod của StatefulSet luôn có tên cố định: `<statefulset-name>-0` (ở đây là `mongo-0`).
* Tên PVC cũng được sinh ra theo quy chuẩn: `<volume-name>-<statefulset-name>-0` (ở đây là `data-mongo-0`).
* Dù Pod có bị xóa và tạo lại bao nhiêu lần, nó vẫn luôn được gắn lại chính xác ổ đĩa `data-mongo-0` mà không bị nhầm lẫn hay tạo ra đĩa mới.

### 3.3. Tiền đề mở rộng thành MongoDB ReplicaSet
* Trong môi trường Production, cơ sở dữ liệu cần tính sẵn sàng cao (High Availability - HA). StatefulSet cung cấp DNS nội bộ ổn định cho từng Pod qua Headless Service (`mongo-0.mongo-service`, `mongo-1.mongo-service`), giúp dễ dàng cấu hình Primary-Secondary Replication mà Deployment không thể đáp ứng.

---

## 4. Các thay đổi kỹ thuật đã thực hiện

### 4.1. Thêm template StatefulSet (`templates/mongo-statefulset.yaml`)
* Đổi `kind: Deployment` thành `kind: StatefulSet`.
* Bổ sung trường bắt buộc `serviceName: {{ include "chart.mongo.serviceName" . }}`.
* Bổ sung khối `volumeClaimTemplates`:
  ```yaml
  volumeClaimTemplates:
    - metadata:
        name: {{ .Values.mongo.persistence.name | default "data" }}
      spec:
        accessModes:
          {{- toYaml .Values.mongo.persistence.accessModes | nindent 10 }}
        {{- if .Values.mongo.persistence.storageClass }}
        storageClassName: {{ .Values.mongo.persistence.storageClass | quote }}
        {{- end }}
        resources:
          requests:
            storage: {{ .Values.mongo.persistence.size | default "5Gi" }}
  ```
* Tự động mount ổ đĩa vào `/data/db` bên trong container.

### 4.2. Cập nhật `values.yaml`
Bổ sung cấu hình persistence rõ ràng, linh hoạt:
```yaml
mongo:
  ...
  # Persistence configuration using StatefulSet volumeClaimTemplates
  persistence:
    enabled: true
    name: "data"
    storageClass: ""      # Để trống để sử dụng StorageClass mặc định của cluster
    accessModes:
      - ReadWriteOnce
    size: 5Gi
    mountPath: /data/db
    subPath: ""
    annotations: {}

  useEmptyDir: false      # Tùy chọn fallback sang emptyDir khi persistence.enabled: false
```

### 4.3. Loại bỏ `templates/mongo-deployment.yaml`
Xóa file Deployment cũ để tránh xung đột tài nguyên trong cùng Helm Release.

---

## 5. Hướng dẫn kiểm tra sau khi Deploy

Sau khi deploy hoặc upgrade chart:
```bash
helm upgrade --install my-release ./chart
```

1. **Kiểm tra trạng thái StatefulSet và Pod**:
   ```bash
   kubectl get statefulset
   kubectl get pods -l app=mongo
   ```
   *Bạn sẽ thấy Pod có tên định danh ổn định: `mongo-0`.*

2. **Kiểm tra PersistentVolumeClaim (PVC)**:
   ```bash
   kubectl get pvc
   ```
   *Kết quả sẽ hiển thị PVC mang tên `data-mongo-0` ở trạng thái `Bound`.*

3. **Kiểm tra mount path trong Pod**:
   ```bash
   kubectl describe pod mongo-0
   # Xem phần Mounts: /data/db from data (rw)
   ```

4. **Kiểm tra an toàn dữ liệu khi restart Pod**:
   * Tạo thử một database/collection qua Mongo Express hoặc `mongosh`.
   * Xóa Pod: `kubectl delete pod mongo-0`.
   * Pod `mongo-0` mới sẽ tự động được tạo lại và mount lại chính xác PVC `data-mongo-0`. Dữ liệu vẫn được giữ nguyên vẹn 100%.
