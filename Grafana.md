# Prometheus & Grafana Monitoring - Super Mario EKS

## Step 1: Install Helm
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
Step 2: Add Helm Repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
Step 3: Create Monitoring Namespace
kubectl create namespace monitoring
Step 4: Install Prometheus + Grafana + Node Exporter
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.service.type=LoadBalancer \
  --set grafana.service.type=LoadBalancer \
  --set grafana.adminPassword=admin123 \
  --set nodeExporter.enabled=true \
  --set kubeStateMetrics.enabled=true \
  --set alertmanager.enabled=true
Step 5: Check All Pods Running
kubectl get pods -n monitoring
Wait until all pods show Running status. Takes 2-3 minutes.
Step 6: Get Grafana and Prometheus URLs
kubectl get svc -n monitoring
Look for EXTERNAL-IP in the output.
Grafana service name: prometheus-grafana
Prometheus service name: prometheus-kube-prometheus-prometheus
Step 7: Open Grafana in Browser
URL: http://<EXTERNAL-IP>
Username: admin
Password: admin123
Step 8: Import Dashboards in Grafana
Click Dashboards on left sidebar
Click Import
Enter ID 1860 → Click Load → Select Prometheus datasource → Click Import
Enter ID 315 → Click Load → Select Prometheus datasource → Click Import
Enter ID 6417 → Click Load → Select Prometheus datasource → Click Import
Dashboard IDs:
1860 = Node Exporter Full (CPU, Memory, Disk, Network)
315  = Kubernetes Cluster Monitoring
6417 = Pod and Container Metrics
Step 9: Apply Alert Rules
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: supermario-alerts
  namespace: monitoring
  labels:
    release: prometheus
spec:
  groups:
    - name: node.rules
      rules:
        - alert: HighCPUUsage
          expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High CPU on {{ $labels.instance }}"
            description: "CPU above 80% for 5 minutes"
        - alert: HighMemoryUsage
          expr: 100 - ((node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100) > 80
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High Memory on {{ $labels.instance }}"
            description: "Memory above 80% for 5 minutes"
EOF
Step 10: Verify Prometheus is Scraping Metrics
kubectl get svc -n monitoring | grep prometheus
Open Prometheus URL in browser:
http://<PROMETHEUS-EXTERNAL-IP>:9090
Go to Status → Targets — all targets should show UP in green.
Cleanup After Test
