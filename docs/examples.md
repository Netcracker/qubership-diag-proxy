# Examples

For more understanding see following examples of parameters with multiple scenarios.

* [Examples](#examples)
  * [Proxy to Profiler/ESC/CDT only](#proxy-to-profileresccdt-only)
  * [Proxy to Profiler/ESC/CDT with TLS](#proxy-to-profileresccdt-with-tls)
  * [Proxy to Profiler and Jaeger](#proxy-to-profiler-and-jaeger)
  * [Proxy for Profiler, Jaeger and for old Zipkin agents](#proxy-for-profiler-jaeger-and-for-old-zipkin-agents)
  * [Proxy for Profiler, Jaeger and Zipkin (as separated service)](#proxy-for-profiler-jaeger-and-zipkin-as-separated-service)

## Proxy to Profiler/ESC/CDT only

To deploy Diag proxy to proxy only Profiler/ESC/CDT requests you can specify only namespace name where
deployed Profiler/ESC/CDT:

```yaml
ESC_COLLECTOR_NS: <esc_namespace_name>
```

For example:

```yaml
ESC_COLLECTOR_NS: profiler
```

## Proxy to Profiler/ESC/CDT with TLS

In production deployment there might be a situation where actual application need to be profiled and Profiler 
application are deployed on different cluster. In this case, TCP and HTTP communication from application to
Profiler should be encrypted consider below representation of the Use case. In this case application will send
HTTP/TCP traffic without TLS and diag-proxy will encrypt traffic and forward it to the Profiler which has
TLS support enabled.

To deploy Diag proxy to proxy only Profiler/ESC/CDT requests with TLS support you can specify namespace
name where deployed Profiler/ESC/CDT and following tls configuration:

```yaml
ESC_COLLECTOR_NS: <esc_namespace_name>
tlsConfig:
  enabled: true
  caCert: <CA Certificate>
  tlsCert: <TLS Certificate>
  tlsKey: <TLS Certificate Key>
```

## Proxy to Profiler and Jaeger

To proxy requests to Profiler and Jaeger you need to specify at least two parameters:

```yaml
# ESC/CDT proxy parameters
ESC_COLLECTOR_NS: <esc_namespace_name>
 
# Jaeger proxy parameters
JAEGER_COLLECTOR_HOST: <jaeger_service_name>
```

But if but any reasons Jaeger was deployed with non default ports, you can specify port numbers during deploy:

```yaml
# ESC/CDT proxy parameters
ESC_COLLECTOR_NS: <esc_namespace_name>
 
# Jaeger proxy parameters
JAEGER_COLLECTOR_HOST: <jaeger_service_name>
 
# Jaeger proxy ports
JAEGER_GRPC_PORT: <grpc_port>        # default: 14250
JAEGER_AGENT_PORT: <agent_port>      # default: 14267
JAEGER_THRIFT_PORT: <thrift_port>    # default: 14268
```

## Proxy for Profiler, Jaeger and for old Zipkin agents

To proxy requests to Profiler and Jaeger you need to specify at least two parameters:

```yaml
# ESC/CDT proxy parameters
ESC_COLLECTOR_NS: <esc_namespace_name>

# Jaeger proxy parameters
JAEGER_COLLECTOR_HOST: <jaeger_service_name>

# Link to Jaeger
ZIPKIN_COLLECTOR_HOST: <jaeger_service_name>
```

In this case Diag proxy will include proxy config for Jaeger:

* Standard Jaeger ports (agent, thrift, grpc)
* Zipkin port, 9411, which Jaeger listen to receive traces in Zipkin format

Also if by any reasons Jaeger deployed with custom ports you can specify port number for Zipkin during deploy:

```yaml
# ESC/CDT proxy parameters
ESC_COLLECTOR_NS: <esc_namespace_name>

# Jaeger proxy parameters
JAEGER_COLLECTOR_HOST: <jaeger_service_name>

# Link to Jaeger
ZIPKIN_COLLECTOR_HOST: <jaeger_service_name>
ZIPKIN_COLLECTOR_PORT: <zipkin_port>      # default: 9411
```

## Proxy for Profiler, Jaeger and Zipkin (as separated service)

To proxy requests to Profiler and Jaeger you need to specify at least two parameters:

```yaml
# ESC/CDT proxy parameters
ESC_COLLECTOR_NS: <esc_namespace_name>

# Jaeger proxy parameters
JAEGER_COLLECTOR_HOST: <jaeger_service_name>

# Zipkin proxy parameters
ZIPKIN_COLLECTOR_HOST: <zipkin_service_name>
```

In this case Diag proxy will include proxy config to three services:

* Profiler
* Jaeger
* Zipkin
