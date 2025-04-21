# Diag proxy

* [Diag proxy](#diag-proxy)
  * [Overview](#overview)
  * [Before you begin](#before-you-begin)
  * [Deploy in application namespace](#deploy-in-application-namespace)
  * [Deploy](#deploy)
    * [Deploy parameters](#deploy-parameters)
    * [Parameter order and override](#parameter-order-and-override)
  * [Examples](#examples)

## Overview

It is a simple and tiny proxy fully based on [Nginx](https://nginx.org/) which allows:

* Receiving diagnostics information from Profiler agent and send it to Profiler collector
  in another namespace.
* Receiving tracing information from OTEL/Jaeger/Zipkin agents and send it to OTEL/Jaeger/Zipkin collector
  in another namespace.

The main purpose of `diag-proxy` is to simplify settings in components.

By using `diag-proxy`, we can configure addresses for profiler agent and tracing agent.
And specify addresses of Profiler and OTEL/Jaeger/Zipkin collectors in one place.

## Before you begin

* You need namespace in Kubernetes 1.15+ in which CDT will be installed
* Diag proxy strongly recommended installing it in the application's namespace before deploying application

## Deploy in application namespace

If you want to use diag-proxy to proxy diagnostic data in the application's namespace you must deploy
the agent before deploying the application in this namespace.

You can override this value if you want to send diagnostic data directly to the collector service without using diag-proxy.

## Deploy

### Deploy parameters

<!-- markdownlint-disable line-length -->
| Name                          | Default value                               | Description                                                                                                                                                                               |
| ----------------------------- | ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ESC_COLLECTOR_NS`            | `cdt`                                       | Namespace where Execution Statistics Collector is installed. If neither `ESC_COLLECTOR_NS` nor (`ESC_COLLECTOR_HOST` and `ESC_STATIC_HOST`) are specified, the ESC proxy will be disabled |
| `ESC_COLLECTOR_HOST`          | `esc-collector-service.${ESC_COLLECTOR_NS}` | Collector service of Execution Statistics Collector                                                                                                                                       |
| `ESC_COLLECTOR_PORT`          | `1715`                                      | ESC port which ESC agent use to send collected calls to ESC in special protocol (over TCP)                                                                                                |
| `ESC_STATIC_HOST`             | `esc-static-service.${ESC_COLLECTOR_NS}`    | Static Nginx service of Execution Statistics Collector                                                                                                                                    |
| `ESC_STATIC_PORT`             | `8080`                                      | ESC port which can be use to request new versions of ESC agent and send collected Heap, Thread dumps or top and GC logs (over HTTP)                                                       |
| `ZIPKIN_COLLECTOR_HOST`       | `-`                                         | Host (without port) where Zipkin is installed. Standard `9411` is proxy                                                                                                                   |
| `ZIPKIN_COLLECTOR_PORT`       | `9411`                                      | Zipkin (or Jaeger) port to receive traces in Zipkin format                                                                                                                                |
| `JAEGER_NS`                   | `jaeger`                                    | Namespace where Jaeger is installed. If neither `JAEGER_NS` nor `JAEGER_COLLECTOR_HOST` are specified, the Tracing proxy will be disabled                                                 |
| `JAEGER_COLLECTOR_HOST`       | `jaeger-collector.${JAEGER_NS}`             | Host (without port) where Jaeger is installed. Standard ports `14250` (grpc), `14267` (thrift for jaeger agent), `14268` (thrift for external clients) are proxy.                         |
| `JAEGER_GRPC_PORT`            | `14250`                                     | Jaeger port to receive gRPC traffic and traces (over TCP)                                                                                                                                 |
| `JAEGER_AGENT_PORT`           | `14267`                                     | Jaeger port to receive traces in thrift format from jaeger-agent (over TCP)                                                                                                               |
| `JAEGER_THRIFT_PORT`          | `14268`                                     | Jaeger port to receive traces in thrift format from any external clients (over HTTP)                                                                                                      |
| `JAEGER_OTEL_GRPC_PORT`       | `4317`                                      | Jaeger port to receive traces in OpenTelemetry format from any external clients (over gRPC)                                                                                               |
| `JAEGER_OTEL_HTTP_PORT`       | `4318`                                      | Jaeger port to receive traces in OpenTelemetry format from any external clients (over HTTP)                                                                                               |
| `SKIP_HOSTNAME_RESOLVING`     | `false`                                     | Disable host resolving during run and allow to run agent with pre-configured hosts without checking them                                                                                  |
| `NUMBER_OF_PODS`              | `1`                                         | Number of diag-proxy replicas (pods per deployment)                                                                                                                              |
| `CPU_LIMIT`                   | `500m`                                      | Allow to set CPU limits for pod                                                                                                                                                           |
| `CPU_REQUEST`                 | `100m`                                      | Allow to set CPU request for pod                                                                                                                                                          |
| `MEMORY_LIMIT`                | `500Mi`                                     | Allow to set Memory limits for pod                                                                                                                                                        |
| `MEMORY_REQUEST`              | `20Mi`                                      | Allow to set Memory request for pod                                                                                                                                                       |
| `ARTIFACT_DESCRIPTOR_VERSION` | `-`                                         | Sets value for `app.kubernetes.io/version` label                                                                                                                                          |
| `IMAGE_REPOSITORY`            | `-`                                         | A docker image to use for diag-proxy deployment                                                                                                                                  |
| `PRIORITY_CLASS_NAME`         | `-`                                         | Assigned to the Pods to prevent them from evicting                                                                                                                                        |
| `tlsConfig`                   | `-`                                         | TLS configuration for upstream application cloud profiler  i.e. collector-service and static service                                                                                      |
| `tlsConfig.enabled`           | `false`                                     | Enable or Disable TLS for upstream application cloud profiler  i.e. collector-service and static service                                                                                  |
| `tlsConfig.caCert`            | `-`                                         | CA certificate for maintaining trust between diag-proxy and TLS enabled the upstream application(Currently collector and static-service)                                         |
| `tlsConfig.tlsCert`           | `-`                                         | TLS certificate needed for encrypted traffic between diag-proxy and TLS enabled the upstream application(Currently collector and static-service)                                 |
| `tlsConfig.tlsKey`            | `-`                                         | TLS Key needed for encrypted traffic between diag-proxy and TLS enabled the upstream application(Currently collector and static-service)                                         |
<!-- markdownlint-enable line-length -->

### Parameter order and override

To deploy `diag-proxy` there are two sets of parameters to configure it which have relations:

* to specify the namespace name for Tracing or Profiler (that has the suffix `_NS`)
* to specify the hostname for Tracing or Profiler (that has the suffix `_HOST`)

You can specify only `*_NS` parameters, like:

```yaml
ESC_COLLECTOR_NS: profiler
JAEGER_NS: tracing
```

The hostname will be automatically calculated using the default Kubernetes Service name and namespace name.

But if you change the Kubernetes Service name of one or N components you can override hosts values
(that generated using namespace names) using `*_HOST` parameters, for example:

```yaml
ESC_COLLECTOR_NS: profiler
ESC_COLLECTOR_HOST: esc-collector-service-new.profiler-new.svc  # this value will use even if ESC_COLLECTOR_NS specified

JAEGER_NS: tracing
JAEGER_COLLECTOR_HOST: jaeger-collector-new.tracing-new.svc  # this value will use even if JAEGER_NS specified
```

## Examples

You can find examples in the document [Examples](docs/examples.md).
