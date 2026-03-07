#!/bin/bash
echo "=== Creating monitoring namespace ==="
kubectl create namespace monitoring

echo "=== Adding Helm repos ==="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "=== Installing Prometheus + Grafana + Node Exporter ==="
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.service.type=LoadBalancer \
  --set grafana.service.type=LoadBalancer \
  --set grafana.adminPassword=admin123 \
  --set nodeExporter.enabled=true \
  --set kubeStateMetrics.enabled=true \
  --set alertmanager.enabled=true

echo "=== Waiting for pods to start (60 seconds) ==="
sleep 60

echo "=== Applying Alert Rules ==="
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
            description: "CPU above 80% for 5 min"

        - alert: HighMemoryUsage
          expr: 100 - ((node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100) > 80
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High Memory on {{ $labels.instance }}"
            description: "Memory above 80% for 5 min"
EOF

echo ""
echo "=== ALL DONE! ==="
echo ""
echo "--- Grafana URL ---"
kubectl get svc -n monitoring | grep grafana
echo ""
echo "Grafana Login -> Username: admin | Password: admin123"
echo ""
echo "--- Import these Dashboard IDs in Grafana ---"
echo "Node Exporter Full  : 1860"
echo "Kubernetes Cluster  : 315"
echo "Pod Metrics         : 6417"
echo ""
echo "--- Prometheus URL ---"
kubectl get svc -n monitoring | grep prometheus
