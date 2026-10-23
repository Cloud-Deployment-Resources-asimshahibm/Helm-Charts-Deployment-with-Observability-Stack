# Helm Charts Implementation-Observability

This repository contains a Helm chart with optional NGINX Prometheus exporter
metrics, Prometheus Operator ServiceMonitor/PrometheusRule resources, and a
standard GitHub Actions test that installs and exercises the chart on a
temporary Kubernetes kind cluster.

## Create a chart structure

From the repository root, run:

```powershell
.\scripts\new-chart.ps1 -ChartName my-app
```

The script creates `charts/my-app` with `Chart.yaml`, `values.yaml`, the common
template files, and a `templates/tests` directory. Existing files are left
untouched.

## Validate and render the chart

With Helm installed, run:

```sh
helm lint charts/helm-charts-implementation
helm template demo charts/helm-charts-implementation
```

Install it into your current Kubernetes context with:

```sh
helm upgrade --install demo charts/helm-charts-implementation
```

Override settings with a values file or `--set`, for example:

```sh
helm upgrade --install demo charts/helm-charts-implementation --set replicaCount=2
```

## Application observability

The chart version is `0.2.0`. The sample chart can expose NGINX-specific metrics using the
`nginx-prometheus-exporter` sidecar. Metrics are disabled by default. Enabling
`metrics.enabled` mounts an NGINX `stub_status` endpoint restricted to
localhost, adds the exporter container, and adds a `metrics` Service port.
Use this integration with the bundled NGINX sample image; other application
images need their own instrumentation or exporter.

Set `metrics.grafanaDashboard.enabled: true` to create a Grafana dashboard
ConfigMap for NGINX availability, active connections, request rate, and
exporter scrape health. Grafana must have a dashboard sidecar configured to
watch ConfigMaps labeled `grafana_dashboard: "1"`; the provided CI monitoring
stack includes that configuration.

For a Prometheus Operator installation, enable a `ServiceMonitor` and
`PrometheusRule` as well:

```yaml
metrics:
  enabled: true
  grafanaDashboard:
    enabled: true
  serviceMonitor:
    enabled: true
    additionalLabels:
      release: kube-prometheus-stack
    interval: 30s
  prometheusRule:
    enabled: true
    additionalLabels:
      release: kube-prometheus-stack
```

The `release` label must match the label selector configured on your
Prometheus installation. The ServiceMonitor and PrometheusRule CRDs must
already exist; they are not installed by this chart. Scrape relabelings attach
stable `nginx_namespace` and `nginx_service` labels used by the alerts and
dashboard. Rules alert when Prometheus cannot scrape the exporter (including
when the target disappears) or NGINX reports itself unavailable.

Render the optional observability resources before installing. The monitoring
CRDs must already be installed in the cluster for these two resource kinds:

```sh
helm lint charts/helm-charts-implementation
helm template demo charts/helm-charts-implementation \
  --set metrics.enabled=true \
  --set metrics.serviceMonitor.enabled=true \
  --set metrics.prometheusRule.enabled=true \
  --set metrics.grafanaDashboard.enabled=true \
  --set metrics.serviceMonitor.additionalLabels.release=kube-prometheus-stack \
  --set metrics.prometheusRule.additionalLabels.release=kube-prometheus-stack
```

After installing, verify the exporter and monitoring resources:

```sh
kubectl get pods,services -l app.kubernetes.io/instance=demo
kubectl get servicemonitor,prometheusrule
kubectl port-forward service/demo-helm-charts-implementation 9113:9113
```

Then open `http://127.0.0.1:9113/metrics`. Collect application/container
logs separately with the cluster's log collector (for example, Fluent Bit or
Promtail/Loki); configure alert routing in your Prometheus/Alertmanager stack.

## Standard Kubernetes cluster test

Every push and pull request runs `.github/workflows/chart-ci.yml`. The workflow
lints and renders the chart, creates an ephemeral Kubernetes cluster with
kind, and installs a pinned `kube-prometheus-stack` (Prometheus, Grafana, and
Alertmanager) using the lean CI configuration in
`.github/ci/kube-prometheus-stack-values.yaml`. It deploys the chart with
metrics, ServiceMonitor, alert rules, and dashboard enabled, waits for the
application rollout, and runs the Helm connection test. It then verifies
Prometheus is scraping the exporter and reports NGINX as healthy, confirms
both custom alert rules are loaded, and checks that Grafana has provisioned
the NGINX dashboard. This is an end-to-end observability integration test on
a disposable CI cluster; it does not deploy to your personal or production
cluster.

To run the same smoke test locally, install Docker Desktop (with its Linux
container engine), kubectl, Helm, and kind, then run:

```powershell
kind create cluster --name helm-observability
helm upgrade --install observability .\charts\helm-charts-implementation `
  --namespace observability --create-namespace `
  --set metrics.enabled=true --wait --timeout 5m
kubectl rollout status deployment/observability-helm-charts-implementation `
  --namespace observability --timeout=5m
helm test observability --namespace observability --logs
kubectl port-forward service/observability-helm-charts-implementation `
  --namespace observability 9113:9113
```

In another terminal, verify metrics at `http://127.0.0.1:9113/metrics`.
The local commands create resources only in the named local kind cluster.
