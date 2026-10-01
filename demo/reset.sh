#!/usr/bin/env bash
# Deja los 3 clusters SIN nada de la demo (para arrancarla en vivo desde cero).
# Saca finalizers antes de borrar para que nada quede colgado; los workloads se van con los namespaces.
# No toca la instancia openshift-gitops, el proyecto default ni la credencial del hub en los spokes.
G="-n openshift-gitops"
nofin() { for a in "$@"; do oc --context $CTX $G patch application.argoproj.io "$a" --type=merge -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1; done; }

echo "== hub"; CTX=hub
nofin push-root hybrid-root
oc --context hub $G delete application.argoproj.io push-root hybrid-root --ignore-not-found
oc --context hub $G delete applicationset.argoproj.io hello-world-push platform-hybrid --cascade=orphan --ignore-not-found
APPS=$(oc --context hub $G get applications.argoproj.io -l kcd.demo/model -o name | cut -d/ -f2)
nofin $APPS; [ -n "$APPS" ] && oc --context hub $G delete application.argoproj.io $APPS
oc --context hub $G delete appproject.argoproj.io push-bootstrap push-workloads hybrid-bootstrap hybrid-platform --ignore-not-found
oc --context hub $G delete secret repo-argo-multicluster --ignore-not-found

for c in bajos prod; do
  echo "== $c"; CTX=$c
  nofin hybrid-apps pull-root hello-world-hybrid hello-world-pull
  oc --context $c $G delete application.argoproj.io hybrid-apps pull-root hello-world-hybrid hello-world-pull --ignore-not-found
  oc --context $c $G delete appproject.argoproj.io hello-world-hybrid hybrid-spoke-root hello-world-pull pull-bootstrap --ignore-not-found
  oc --context $c delete ns kcd-push-$c kcd-pull-$c kcd-hybrid-$c --ignore-not-found
  oc --context $c delete clusterrolebinding kcd-argocd-edit-pull --ignore-not-found
  oc --context $c $G delete secret repo-argo-multicluster --ignore-not-found
done
echo "listo: clusters en cero"
