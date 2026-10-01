#!/usr/bin/env bash
# Fuerza a Argo CD a releer Git ya (en vez de esperar ~3 min de polling) en los 3 clusters.
for c in hub bajos prod; do
  for a in $(oc --context $c -n openshift-gitops get applications.argoproj.io -o name 2>/dev/null); do
    oc --context $c -n openshift-gitops annotate "$a" argocd.argoproj.io/refresh=hard --overwrite >/dev/null &
  done
done
wait; echo "refresh pedido en hub, bajos y prod"
