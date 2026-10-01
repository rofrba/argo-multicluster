#!/usr/bin/env bash
# Tablero de la demo: qué modelo/entorno/pods sirve cada ruta. Uso: ./demo/status.sh [segundos]
# Requiere contexts de oc llamados hub, bajos y prod.
show() {
  printf "%-7s %-7s %-6s %-9s %s\n" CLUSTER MODELO PODS HTTP ENTORNO
  for c in bajos prod; do
    for m in push pull hybrid; do
      ns=kcd-$m-$c
      pods=$(oc --context $c -n $ns get deploy hello-world -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null)
      host=$(oc --context $c -n $ns get route hello-world -o jsonpath='{.spec.host}' 2>/dev/null)
      if [ -n "$host" ]; then
        body=$(curl -sk --max-time 5 "https://$host")
        code=$(curl -sk -o /dev/null --max-time 5 -w '%{http_code}' "https://$host")
        env=$(echo "$body" | grep -o 'class="env">[^<]*' | cut -d'>' -f2)
      else code="-"; env="(no desplegado)"; fi
      printf "%-7s %-7s %-6s %-9s %s\n" $c $m "${pods:--}" "$code" "$env"
    done
  done
}
if [ -n "$1" ]; then while true; do clear; date +%T; show; sleep "$1"; done; else show; fi
