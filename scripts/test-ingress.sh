#!/bin/bash
set -e

echo "🔍 Testing Ingress Routes via LoadBalancer..."
echo ""

# Get envoy port
ENVOY_PORT=$(docker port $(docker ps -q --filter "ancestor=envoyproxy/envoy:v1.33.2") 80/tcp 2>/dev/null | cut -d':' -f2)

if [ -z "$ENVOY_PORT" ]; then
    echo "❌ Envoy proxy not found. LoadBalancer may not be ready yet."
    echo "Run 'make apps-install' and wait for services to sync."
    exit 1
fi

echo "📡 Using LoadBalancer port: $ENVOY_PORT"
echo ""

# Test microservice-a
echo -n "Testing Microservice A (microservice-a.127.0.0.1.nip.io)... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://microservice-a.127.0.0.1.nip.io:${ENVOY_PORT})
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ $HTTP_CODE OK"
else
    echo "⚠️  $HTTP_CODE (expected 200)"
fi

# Test microservice-b
echo -n "Testing Microservice B (microservice-b.127.0.0.1.nip.io)... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://microservice-b.127.0.0.1.nip.io:${ENVOY_PORT})
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ $HTTP_CODE OK"
else
    echo "⚠️  $HTTP_CODE (expected 200)"
fi

# Test Grafana
echo -n "Testing Grafana (grafana.127.0.0.1.nip.io)... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://grafana.127.0.0.1.nip.io:${ENVOY_PORT})
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    echo "✅ $HTTP_CODE OK"
else
    echo "⚠️  $HTTP_CODE (expected 200 or 302)"
fi

# Test Prometheus
echo -n "Testing Prometheus (prometheus.127.0.0.1.nip.io)... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://prometheus.127.0.0.1.nip.io:${ENVOY_PORT})
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ $HTTP_CODE OK"
else
    echo "⚠️  $HTTP_CODE (expected 200)"
fi

# Test Argo CD (if ingress exists)
echo -n "Testing Argo CD (argocd.127.0.0.1.nip.io)... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://argocd.127.0.0.1.nip.io:${ENVOY_PORT} 2>/dev/null || echo "N/A")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
    echo "✅ $HTTP_CODE OK"
else
    echo "⚠️  $HTTP_CODE"
fi

echo ""
echo "🎉 Ingress testing complete!"
echo ""
echo "📌 HTTP Status Codes:"
echo "   200 = Success"
echo "   302 = Redirect (normal for login pages)"
echo "   404 = Not found (check ingress rules)"
echo ""
echo "💡 Access URLs with: make urls"
