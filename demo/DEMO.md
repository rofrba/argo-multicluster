# Guion de la demo — KCD Argentina

~12 min de demo en 4 bloques, intercalados con los slides. Todo se levanta **en vivo desde cero**
con un `oc apply -k` por modelo; el resto lo hace Argo CD desde Git.

## Antes de la charla (T-30 min)

1. **Contexts de `oc`** con estos nombres exactos (los scripts los usan):
   ```bash
   oc login https://api.ocp.w8jqn.sandbox186.opentlc.com:6443 -u admin   && oc config rename-context $(oc config current-context) hub
   oc login https://api.ocp.zcnm2.sandbox871.opentlc.com:6443 -u admin   && oc config rename-context $(oc config current-context) bajos
   oc login https://api.ocp.xv5zf.sandbox1997.opentlc.com:6443 -u admin  && oc config rename-context $(oc config current-context) prod
   ```
2. **Clusters en cero**: `./demo/reset.sh`, y después `./demo/status.sh` → todo "(no desplegado)".
3. **Pestañas abiertas** (logueadas, zoom 150 %):
   | Pestaña | URL |
   |---|---|
   | Argo **hub** | https://openshift-gitops-server-openshift-gitops.apps.ocp.w8jqn.sandbox186.opentlc.com |
   | Argo **bajos** | https://openshift-gitops-server-openshift-gitops.apps.ocp.zcnm2.sandbox871.opentlc.com |
   | Argo **prod** | https://openshift-gitops-server-openshift-gitops.apps.ocp.xv5zf.sandbox1997.opentlc.com |
   | Repo | VS Code con el repo abierto en `main`, `git pull` hecho |
4. **Terminal partida en 2**: arriba `./demo/status.sh 3` (tablero en vivo), abajo para los comandos.
5. **Plan B**: si la red falla, capturas de cada paso (sacarlas en el ensayo) en un slide oculto.

> Cada cambio en Git va seguido de `./demo/refresh.sh` para no esperar los ~3 min de polling.
> Decirlo en voz alta: *"en producción esto lo dispara un webhook"*.

---

## Bloque 1 — PUSH (después del slide 8, "Push Model: Pros & Cons")

| # | Hacer | Mostrar | Decir |
|---|---|---|---|
| 1 | Abrir `push/hub/hello-world-appset.yaml` y `push/clusters/prod/cluster-config.json` | `destination.name: '{{.name}}'` | "Un JSON por cluster. El hub decide todo." |
| 2 | `oc --context hub apply -k push/bootstrap` | Argo **hub**: `push-root` → `hello-world-push-bajos` / `-prod` | "Un solo comando, en un solo lugar." |
| 3 | Click en `hello-world-push-prod` | Árbol con Deployment y **Pods de otro cluster** | "Este Argo está en el hub, esos pods están en prod." |
| 4 | Pestaña Argo **prod** | Vacío: no hay ninguna app de push | "El spoke ni se entera de que existe Argo." |
| 5 | Tablero / ruta push | 🟧 **PUSH** | — |

**Mensaje:** visibilidad total y un solo punto de control… y un solo punto de falla. El hub tiene las credenciales de admin de todos los clusters.

## Bloque 2 — PULL (después del slide 11, "Pull Model: Strategic Trade-offs")

| # | Hacer | Mostrar | Decir |
|---|---|---|---|
| 1 | Abrir `pull/bootstrap/bajos/kustomization.yaml` | El patch de Kustomize que cambia el path de la root app | "Misma base para todos los clusters; cada uno cambia una línea." |
| 2 | `oc --context bajos apply -k pull/bootstrap/bajos` y `oc --context prod apply -k pull/bootstrap/prod` | Argo **bajos** y **prod**: `pull-root` → `hello-world-pull` | "Cada cluster se gobierna solo." |
| 3 | Pestaña Argo **hub** | No aparece nada de pull | "El hub no tiene credenciales de estos clusters. Zero trust." |
| 4 | Tablero | 🟩 **PULL** en bajos y prod | "¿Y si tengo 50? 50 consolas." → slide 12 (War Story) |

## Bloque 3 — Kustomize: un commit, tres modelos (enganche con el slide 13, "Head to Head")

| # | Hacer | Mostrar | Decir |
|---|---|---|---|
| 1 | `oc kustomize manifests/hello-world/deploy/push/prod` | Base + `envs/prod` + `components/push` → réplicas 2, color, namespace | "Una base, entorno por overlay, modelo por componente." |
| 2 | Editar `manifests/hello-world/envs/prod/kustomization.yaml`: `MI_ENTORNO=Produccion - KCD Buenos Aires` → `git commit -am "prod: saludo KCD" && git push` | — | "Un cambio, un archivo." |
| 3 | `./demo/refresh.sh` | Tablero: las filas de **prod** cambian solas (push y pull) | "Cambió el hash del ConfigMap → rollout automático." |

> Hybrid todavía no está desplegado: en el bloque 4 nace con el texto nuevo.

## Bloque 4 — HYBRID (después del slide 15, "Hybrid Architecture Diagram")

| # | Hacer | Mostrar | Decir |
|---|---|---|---|
| 1 | `oc --context hub apply -k hybrid/bootstrap` | Argo **hub**: `platform-bajos` / `platform-prod` | "El hub sólo instala la plataforma." |
| 2 | Click en `platform-prod` | Árbol: Namespace, ResourceQuota, LimitRange, NetworkPolicies, AppProjects, Application `hybrid-apps`. **Ningún Deployment.** | "El hub no puede desplegar apps: no está en su whitelist." |
| 3 | Pestaña Argo **prod** | `hybrid-apps` → `hello-world-hybrid` → Pods | "Esto lo creó el hub, pero lo ejecuta el Argo local." |
| 4 | Tablero | 🟪 **HYBRID** con el texto del bloque 3 | — |

### 4a. Gobierno central
```bash
oc --context prod -n kcd-hybrid-prod delete resourcequota team-quota
oc --context prod -n kcd-hybrid-prod get resourcequota      # ya volvió (~1 s)
```
**Decir:** "Alguien en prod borró la cuota. El hub la repuso antes de que terminara de escribir."

### 4b. Guardrails
Editar `manifests/hello-world/envs/bajos/kustomization.yaml` → `count: 6` → commit + push → `./demo/refresh.sh`.

**Mostrar:** en el tablero, bajos/push y bajos/pull llegan a 6/6; bajos/hybrid se queda en **4/6**
(`oc --context bajos -n kcd-hybrid-bajos get events | grep quota`).
**Decir:** "Mismo commit. En el híbrido manda la cuota que puso plataforma, y el equipo no la puede tocar."

Después volver a `count: 1` (commit + push + refresh).

### 4c. Final: se cae el hub
```bash
oc --context hub -n openshift-gitops scale statefulset openshift-gitops-application-controller --replicas=0
```
Cambiar `MI_ENTORNO` de bajos (`Desarrollo - hub caido`) → commit + push → `./demo/refresh.sh`.

**Mostrar en el tablero:**
- 🟩 pull y 🟪 hybrid de bajos → **texto nuevo** (el Argo local siguió trabajando).
- 🟧 push de bajos → **texto viejo** (nadie le empuja).

```bash
oc --context hub -n openshift-gitops scale statefulset openshift-gitops-application-controller --replicas=1
```
**Mostrar:** a los segundos push también se actualiza.
**Decir:** "Push se cae con el hub. Pull no se entera. Hybrid: las apps siguen, la plataforma se congela." → slide 16 (Decision Framework).

---

## Después de la charla
1. Revertir los cambios de texto y réplicas en `envs/` (commit + push).
2. Opcional: `./demo/reset.sh`.
