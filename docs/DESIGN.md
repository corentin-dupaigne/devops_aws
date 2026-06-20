# Design Document — Projet DevOps + AWS (Option A)

> Application support : **Pomodoro** (3-tiers). Le code applicatif n'est pas noté ;
> ce document décrit tout l'enrobage **AWS + DevOps** et **justifie chaque choix**
> au regard des critères de notation : *résilience, scalabilité, logique
> d'architecture, et moindre privilège sur les flux*.

---

## 1. Contexte & contraintes

| Élément | Valeur |
|---|---|
| Application | Pomodoro 3-tiers : `frontend` (Nginx + statique), `backend` (Flask/Gunicorn, **stateless**), `db` (MySQL 8) |
| Environnement AWS | **AWS Academy Learner Lab** |
| Région | `us-east-1` (verrouillée par le lab) |
| Équipe | Solo (groupes de 1 autorisés), `terraform apply` depuis le laptop |
| Dépôt | **GitHub** (CI via GitHub Actions) — usage validé auprès du professeur |
| Rendu | Dépôt + rapport mail (schémas, flux, justifications) |

### Contraintes Learner Lab (structurantes)
- **Création de rôles IAM interdite** (`iam:CreateRole` refusé) → on **réutilise**
  `LabRole` / `LabInstanceProfile` (data sources Terraform), jamais de création.
- **Credentials temporaires (~4 h)** → pas d'automatisation AWS fiable depuis la CI :
  le déploiement se fait **manuellement** avec les creds frais du lab.
- **Budget / quotas limités** → RDS Single-AZ, pas de NAT Gateway.

---

## 2. Application (rappel)

- **frontend** : HTML/CSS/JS vanilla servi par Nginx ; Nginx **reverse-proxy `/api/*`**
  vers le backend → une seule origine côté navigateur.
- **backend** : Flask + Gunicorn, **sans état**, expose `/api/health`, `/api/sessions`, `/api/stats`.
- **db** : MySQL 8, table unique `sessions`, schéma chargé via `init.sql`.

Le backend stateless se prête à l'autoscaling ; le modèle Nginx-proxy permet une
**chaîne de flux linéaire** (front → back → db) idéale pour le moindre privilège.

---

## 3. Architecture AWS cible

```
                         Internet
                            │  HTTP :80
                   ┌────────▼─────────┐
                   │       ALB        │   public subnets (AZ-a, AZ-b)
                   │  SG-ALB: 80 ◄ 0.0.0.0/0
                   └────────┬─────────┘
                            │  :80  (SG-front ◄ SG-ALB uniquement)
                   ┌────────▼─────────┐
                   │ EC2 frontend     │   EC2 statique + auto-recovery
                   │ (Nginx + statique)│  public subnet
                   └────────┬─────────┘
                            │  :5000 (SG-back ◄ SG-front uniquement)
                   ┌────────▼─────────┐
                   │ EC2 backend      │   EC2 statique + auto-recovery
                   │ (Flask/Gunicorn) │   public subnet
                   └────────┬─────────┘
                            │  :3306 (SG-db ◄ SG-back uniquement)
                   ┌────────▼─────────┐
                   │ RDS MySQL 8      │   PRIVATE subnets (AZ-a, AZ-b)
                   │ Single-AZ        │   non joignable depuis Internet
                   └──────────────────┘

  Administration : SSH restreint à l'IP d'admin (22 ◄ <ADMIN_IP>/32)
  Egress EC2     : Internet Gateway (pas de NAT)
  Secrets        : SSM Parameter Store (SecureString)
  Images         : Amazon ECR
  Observabilité  : Amazon CloudWatch (métriques, logs, alarmes → SNS)
```

### 3.1 Réseau (VPC)
- 1 VPC, **2 zones de disponibilité** (AZ-a, AZ-b) → couvre le minimum imposé.
- **Subnets publics** (2 AZ) : ALB + EC2 frontend/backend.
- **Subnets privés** (2 AZ) : RDS uniquement.
- **Internet Gateway** pour l'egress des EC2 (pull ECR, paquets, SSM, CloudWatch).
- **Pas de NAT Gateway** : choix budget (Learner Lab). Compensé par des SG verrouillés.

### 3.2 Compute
- **EC2 statiques** (une instance frontend, une instance backend) — pas d'ASG.
- **Auto-recovery via alarme CloudWatch** : une alarme sur `StatusCheckFailed_System`
  déclenche l'action `ec2:recover` → l'instance est récupérée sur un hôte sain en
  conservant son ID, son IP privée et ses volumes EBS.
  - Bénéfice : résilience face à une panne matérielle/hyperviseur **sans la
    complexité d'un ASG**, cohérent avec le budget Learner Lab.
  - Limite assumée : ne couvre pas une panne applicative interne (OS/conteneur) ;
    pas de scaling horizontal (voir future-work §8).
- **EC2 attachées à l'ALB** via un Target Group + health checks.

### 3.3 Données
- **RDS MySQL 8 Single-AZ** en subnets privés.
- **Multi-AZ documenté en future-work** (bascule d'une ligne Terraform).

---

## 4. Flux & moindre privilège (critère noté ★)

### 4.1 Security Groups en cascade
Chaque tier n'accepte **que le SG du tier au-dessus** — **aucun CIDR ouvert** entre tiers.

| SG | Inbound autorisé | Source | Justification |
|---|---|---|---|
| `SG-ALB` | TCP 80 | `0.0.0.0/0` | Seul point d'entrée public |
| `SG-front` | TCP 80 | `SG-ALB` | Front joignable uniquement par l'ALB |
| `SG-back` | TCP 5000 | `SG-front` | Back joignable uniquement par le front (Nginx-proxy) |
| `SG-db` | TCP 3306 | `SG-back` | DB joignable uniquement par le backend |
| `SG-front` / `SG-back` | TCP 22 | `<ADMIN_IP>/32` | SSH d'admin (Ansible) limité à la seule IP de l'admin |

- **SSH (22) fermé à tous sauf l'IP d'admin** (`/32`) — aucun accès SSH public.
- **Egress** : ouvert (`0.0.0.0/0`) pour permettre le pull ECR, les appels SSM/CloudWatch
  et les mises à jour de paquets sans NAT ni VPC endpoints (egress via l'IGW).

### 4.2 Administration — SSH restreint à l'IP d'admin
- Accès shell et déploiement Ansible via **SSH**, mais le port 22 n'est **ouvert
  qu'à l'IP de l'admin** (`<ADMIN_IP>/32`) — fermé pour tout le reste d'Internet.
- Pas de bastion : la surface d'exposition se réduit à une seule IP source.
- Choix assumé vs SSM Session Manager : Ansible conserve un transport SSH simple
  et fiable (le connecteur SSM étant fragile), au prix d'un port 22 ouvert à une
  seule IP plutôt que totalement fermé (voir §8).

### 4.3 RDS privée
- RDS en subnets **privés**, **pas d'IP publique**, `publicly_accessible = false`.
- → la base est **structurellement injoignable depuis Internet** (argument le plus fort).

### 4.4 IAM
- **Contrainte lab** : on réutilise `LabRole` / `LabInstanceProfile` (création interdite).
- L'instance profile fournit aux EC2 : SSM, pull ECR, push logs/métriques CloudWatch,
  lecture des paramètres SSM.
- Le moindre privilège côté projet repose donc **principalement sur les Security Groups**
  (l'IAM fin n'est pas modifiable dans le lab — assumé et expliqué).

---

## 5. Secrets
- Credentials RDS stockés dans **SSM Parameter Store** en `SecureString`.
- Injectés dans les conteneurs au déploiement (Ansible lit SSM via l'instance profile).
- **Plus aucun mot de passe en clair** (contrairement au `docker-compose` de dev).

---

## 6. Observabilité — CloudWatch (décision : pas de Prometheus/Grafana)

> Prometheus/Grafana écarté : sans dashboards custom, il fait doublon avec CloudWatch
> et ajoute une EC2 + des exporters à maintenir, pour un gain quasi nul vu la deadline.

| Besoin | Mise en œuvre CloudWatch |
|---|---|
| Métriques système EC2 | CloudWatch agent (CPU, mém, disque) |
| Métriques conteneurs | **Container Insights** |
| Logs des 3 conteneurs | CloudWatch Logs (+ **Logs Insights** pour les requêtes) |
| Métriques managées | ALB (5xx, latence, hôtes unhealthy), RDS (CPU, connexions, storage) |
| Dashboard | 1 dashboard unique ALB / EC2 / RDS |
| Alertes | **Alarmes → SNS** (ALB 5xx, RDS storage/CPU, host unhealthy) |
| Résilience | **EC2 auto-recovery alarm** |

---

## 7. Chaîne DevOps

### 7.1 Infrastructure as Code — Terraform
- **State local** (solo, apply depuis le laptop).
- Modules : `network` (VPC/subnets/IGW/routes/SG), `data` (RDS + SSM params),
  `compute` (EC2 statiques + ALB + Target Group + alarmes auto-recovery), `ecr`,
  `observability` (CloudWatch dashboard/alarms/SNS).
- IAM **référencé** (data sources `LabRole` / `LabInstanceProfile`), jamais créé.
- Provider figé sur `us-east-1`.

### 7.2 Gestion de configuration — Ansible
- **Inventaire statique** : les deux EC2 ayant une identité fixe, un inventaire
  listant les IP publiques frontend/backend suffit (pas besoin du plugin dynamique
  `aws_ec2`).
- Connexion **via SSH** (clé d'admin), port 22 restreint à `<ADMIN_IP>/32` au niveau
  des SG → transport simple et fiable (pas de connecteur SSM).
- **Ansible = outil de déploiement complet** : hardening de base, install Docker,
  `docker login` ECR, pull image, run conteneur, injection des secrets lus depuis
  **SSM Parameter Store** (via l'instance profile de l'EC2).

### 7.3 CI/CD — GitHub Actions
Répartition imposée par les creds temporaires du Learner Lab :

| Phase | Où | Étapes |
|---|---|---|
| Qualité & sécurité | **GitHub Actions (sans AWS)** | `lint → test → security → build image → scan image` |
| Déploiement (CD) | **Laptop (creds lab frais)** ou workflow `workflow_dispatch` | `docker push ECR → terraform apply → ansible deploy` |

Pipeline CI (jobs) :
1. **lint** — `hadolint` (Dockerfiles), formatage Python, `tfsec`/`checkov` (Terraform)
2. **test** — tests applicatifs (le cas échéant)
3. **security (DevSecOps)** — `gitleaks` (secrets), `semgrep` (SAST),
   `pip-audit`/`safety` (dépendances)
4. **build** — `docker build` des images front/back
5. **scan** — `trivy` (image + filesystem)
6. *(deploy : workflow `workflow_dispatch` ou hors-CI depuis le laptop)*

### 7.4 DevSecOps (bonus fortement encouragés)
- Secrets : **gitleaks**
- SAST : **semgrep**
- Dépendances : **pip-audit** / **safety**
- Images Docker : **trivy**
- IaC : **tfsec** / **checkov**
- Dockerfiles : **hadolint**
- **Rapports** publiés en **artifacts GitHub Actions**.

---

## 8. Compromis assumés (à justifier dans le rapport)

| Compromis | Raison | Compensation / future-work |
|---|---|---|
| EC2 en subnets **publics** | Pas de NAT (budget Learner Lab) | SG en cascade + SSH restreint à l'IP admin + RDS privée |
| **SSH ouvert** (port 22) au lieu de SSM-only | Transport Ansible simple/fiable (connecteur SSM fragile) | Ingress 22 limité à `<ADMIN_IP>/32` uniquement ; aucun accès SSH public |
| **EC2 statiques** (pas d'ASG) | Simplicité / budget lab | Auto-recovery par alarme CloudWatch ; ASG (scaling horizontal) = future-work |
| RDS **Single-AZ** | Budget / quotas lab | Multi-AZ = 1 ligne Terraform à flipper |
| **HTTP** sur l'ALB | Pas de domaine ; déploiement non imposé | ACM + Route53 en future-work |
| IAM via **LabRole** | Création de rôles interdite | Moindre privilège porté par les SG ; expliqué |
| **State Terraform local** | Solo, apply laptop | S3 + DynamoDB si travail en équipe |
| **Pas de Prometheus/Grafana** | Doublon CloudWatch sans dashboards custom | CloudWatch couvre métriques/logs/alarmes |

---

## 9. Cartographie sur les critères de notation

| Critère | Réponse dans le design |
|---|---|
| **Résilience** | Multi-AZ réseau, EC2 auto-recovery (alarme CloudWatch), RDS managée + backups, alarmes |
| **Scalabilité** | Backend stateless + ALB (prêt pour un ASG) ; scaling vertical immédiat, ASG en future-work |
| **Logique d'architecture** | 3-tiers mappé 1:1 sur l'infra, flux linéaire front→back→db |
| **Moindre privilège** | SG en cascade, SSH restreint à l'IP admin (`/32`), RDS privée, secrets SSM, aucun CIDR inter-tiers |

---

## 10. Plan de construction

1. **Terraform `network`** — VPC, subnets 2 AZ (public/privé), IGW, routes, **SG chaînés**.
2. **Terraform `data`** — RDS Single-AZ + paramètres SSM (secrets).
3. **Terraform `compute`** — EC2 statiques (front/back) + alarmes auto-recovery,
   ALB + Target Group, ECR, références `LabRole`/`LabInstanceProfile`.
4. **Terraform `observability`** — dashboard CloudWatch, alarmes, SNS.
5. **Ansible** — rôles install Docker / deploy conteneurs / secrets SSM (connexion SSH restreinte à l'IP admin).
6. **GitHub Actions** — pipeline qualité/sécurité + scans DevSecOps + build/scan image.
7. **Rapport** — schémas, captures, flux (moindre privilège), justifications.

---

## 11. Sprints & User Stories

> Découpage en sprints courts (projet solo, deadline serrée : **20 juin 23h59**).
> Chaque story suit le format *« En tant que… je veux… afin de… »* avec des
> **critères d'acceptation (CA)** vérifiables.
> Priorités : **P0** = noté/indispensable, **P1** = fortement valorisé,
> **P2** = bonus/confort (sacrifiable si le temps manque).

> **Règle de survie** : l'ordre des sprints n'est PAS l'ordre de valeur. Le chemin
> critique est S1→S2→S3→S4 (infra qui tourne de bout en bout) PUIS S7 (rapport).
> Dès que l'app répond via l'URL de l'ALB, basculer sur le rapport et capturer les
> écrans, puis revenir piocher dans S5/S6 selon le temps restant.

### Sprint 0 — Cadrage & socle (P0)
But : un dépôt propre et une app qui tourne en local, base saine pour l'IaC.

- **US-0.1** — En tant que dev, je veux **un dépôt GitHub structuré** (app + `docs/` +
  futurs `terraform/`, `ansible/`, `.github/`) afin de séparer code et infra.
  - CA : arborescence créée ; `README` + `docs/DESIGN.md` présents ; `.gitignore`
    couvre `.env`, state Terraform, clés.
- **US-0.2** — En tant que dev, je veux **lancer l'app en local via Docker Compose**
  afin de valider le comportement avant tout déploiement.
  - CA : `docker compose up` démarre front/back/db ; `/api/health` répond `ok`.

### Sprint 1 — Réseau & sécurité AWS (P0) ★
But : le socle réseau le plus noté (VPC multi-AZ + moindre privilège).

- **US-1.1** — En tant qu'architecte, je veux **un VPC avec subnets publics et privés
  sur 2 AZ** afin de respecter le minimum imposé et la résilience.
  - CA : `terraform apply` crée 1 VPC, 2 subnets publics + 2 privés (AZ-a/AZ-b),
    IGW + routes ; egress `0.0.0.0/0` via IGW.
- **US-1.2** — En tant que RSSI, je veux **des Security Groups en cascade**
  (ALB→front→back→db) afin d'appliquer le moindre privilège sur les flux.
  - CA : chaque SG n'autorise que le SG du tier au-dessus ; aucun CIDR inter-tiers ;
    SSH 22 ouvert uniquement à `<ADMIN_IP>/32`.

### Sprint 2 — Données & secrets (P0)
But : base managée privée + secrets hors du code.

- **US-2.1** — En tant qu'architecte, je veux **une RDS MySQL en subnets privés**
  afin que la base soit injoignable depuis Internet.
  - CA : RDS `publicly_accessible = false` ; `SG-db` n'accepte 3306 que de `SG-back`.
  - Note : le chargement du schéma (`init.sql`) est porté par US-4.1 (Ansible
    l'exécute depuis le backend), RDS managée n'exécutant pas de script d'init seule.
- **US-2.2** — En tant que RSSI, je veux **les credentials DB dans SSM Parameter Store
  (SecureString)** afin de ne jamais avoir de secret en clair.
  - CA : paramètres SSM créés ; aucun mot de passe en clair dans le repo/IaC.

### Sprint 3 — Compute & exposition (P0)
But : les 2 EC2 derrière l'ALB, images dans ECR, résilience par auto-recovery.

- **US-3.1** — En tant qu'architecte, je veux **2 EC2 statiques (front/back) attachées
  à un ALB** afin d'exposer l'app via un point d'entrée unique.
  - CA : ALB HTTP:80 → Target Group front ; front proxy `/api` → back ; health checks verts.
- **US-3.2** — En tant qu'ops, je veux **une alarme CloudWatch d'auto-recovery** sur
  chaque EC2 afin de récupérer une instance en cas de panne hôte.
  - CA : alarme `StatusCheckFailed_System` → action `ec2:recover` sur les 2 instances.
- **US-3.3** — En tant que dev, je veux **un dépôt ECR** afin de stocker les images
  buildées.
  - CA : repos ECR front/back créés.
- **US-3.4** — En tant que dev, je veux **build et push des images front/back sur ECR**
  (depuis le laptop ou via artifact CI) afin que le déploiement Ansible ait des images
  à puller.
  - CA : images `front:latest` et `back:latest` présentes dans ECR AVANT US-4.1 ;
    push testé depuis le laptop avec les creds frais du lab.

### Sprint 4 — Déploiement & configuration (P0)
But : Ansible déploie tout sur les EC2.

- **US-4.1** — En tant qu'ops, je veux **un playbook Ansible de déploiement complet**
  (hardening, Docker, login/pull/run ECR, chargement `init.sql`, secrets SSM) afin
  d'automatiser la config.
  - CA : `ansible-playbook` sur inventaire statique déploie les conteneurs ; schéma
    `init.sql` appliqué à la RDS ; app accessible via l'ALB ; secrets injectés depuis SSM.
- **US-4.2** — En tant qu'ops, je veux **un transport SSH restreint à l'IP admin**
  afin de garder un accès simple sans exposer le port 22.
  - CA : connexion Ansible via SSH OK depuis l'IP admin ; refusée depuis une autre IP.

### Sprint 5 — CI/CD & DevSecOps (P0 noyau / P1-P2 extras) ★
But : pipeline GitHub Actions avec portes qualité/sécurité.
**Rappel sujet** : CI/CD + outils de sécurité et de qualité sont **imposés** (le bonus
porte sur l'*ampleur* du DevSecOps, pas sur son existence) → le noyau est **P0**.

- **US-5.1** *(P0)* — En tant que dev, je veux **un pipeline GitHub Actions**
  (`lint → test → security → build → scan`) afin d'automatiser qualité et build.
  - CA : workflow déclenché sur push/PR ; échoue si une étape échoue ; sans creds AWS.
- **US-5.2** — En tant que RSSI, je veux **les scans DevSecOps** afin de détecter
  secrets/vulns/mauvaises pratiques.
  - CA (**P0**, minimum imposé = 1 sécurité + 1 qualité) : `trivy` (image, sécurité) +
    `gitleaks` (secrets) + un **linter qualité** (ex. `hadolint`/format Python) tournent
    dans la CI ; rapports en **artifacts**.
  - CA (P1) : ajout de `checkov`/`tfsec` (IaC).
  - CA (P2, si le temps reste) : ajout de `semgrep` (SAST), `pip-audit`/`safety`
    (dépendances).
- **US-5.3** — En tant qu'ops, je veux **un déploiement déclenchable manuellement**
  (`workflow_dispatch`) ou depuis le laptop afin de gérer les creds temporaires du lab.
  - CA : étape de deploy isolée, non auto sur les creds éphémères.

### Sprint 6 — Observabilité (P1 noyau / P2 extras)
But : visibilité et alerting via CloudWatch.
**Rappel sujet** : monitoring **et logs** sont **imposés** → dashboard + logs = noyau P1.

- **US-6.0** *(P1, minimum)* — En tant qu'ops, je veux **un dashboard CloudWatch simple
  (ALB/EC2/RDS)** afin de prouver le monitoring exigé par le sujet.
  - CA : 1 dashboard avec les métriques natives ALB (5xx, latence), EC2 (CPU), RDS (CPU,
    connexions) ; capture pour le rapport.
- **US-6.1** *(P1)* — En tant qu'ops, je veux **les logs des 3 conteneurs centralisés
  dans CloudWatch Logs** afin de diagnostiquer les incidents (logs explicitement imposés).
  - CA : log groups créés ; logs front/back/db visibles ; une requête Logs Insights documentée.
- **US-6.2** *(P2)* — En tant qu'ops, je veux des **alarmes → SNS** afin d'être alerté
  sur les anomalies.
  - CA : alarmes ALB 5xx / RDS / host unhealthy ; notification SNS testée.

### Sprint 7 — Rapport & finalisation (P0)
But : le livrable noté. **À démarrer dès que l'app tourne (fin S4), pas à la fin.**

- **US-7.1** — En tant qu'étudiant, je veux **un rapport** (schémas, captures, flux,
  justifications, compromis) afin que le travail soit compréhensible et évaluable.
  - CA : rapport reprend §3/§4/§8/§9 ; captures du dashboard, du pipeline et des scans.
- **US-7.2** — En tant qu'étudiant, je veux **un README de prise en main** (déploiement
  pas-à-pas) afin que le correcteur puisse reproduire.
  - CA : étapes build/push ECR → `terraform apply` → `ansible-playbook` → URL ALB documentées.

### Vue d'ensemble

| Sprint | Thème | Priorité | Livrable clé | Fallback si manque de temps |
|---|---|---|---|---|
| 0 | Cadrage & socle | P0 | Repo structuré + app locale | — (prérequis) |
| 1 | Réseau & sécurité ★ | P0 | VPC 2 AZ + SG chaînés | — (intouchable) |
| 2 | Données & secrets | P0 | RDS privée + SSM | — (intouchable) |
| 3 | Compute & exposition | P0 | EC2 + ALB + ECR + images | auto-recovery (US-3.2) en dernier |
| 4 | Déploiement | P0 | Playbook Ansible | hardening minimal, focus deploy |
| 5 | CI/CD & DevSecOps ★ | **P0** noyau / P1-P2 | GitHub Actions + scans | noyau = pipeline + trivy + gitleaks + 1 lint ; extras coupés |
| 6 | Observabilité | **P1** noyau / P2 | Dashboard + logs CloudWatch | dashboard (US-6.0) + logs (US-6.1) ; alarmes SNS coupées |
| 7 | Rapport | P0 | Rapport + README | — (ne JAMAIS sacrifier) |

### Chemin critique (jalon de survie)
```
S1 (VPC+SG) → S2 (RDS+SSM) → S3 (EC2+ALB+images ECR) → S4 (Ansible deploy)
   → APP DEBOUT via URL ALB  ← jalon de survie, le plus tôt possible
   → noyau P0/P1 imposé : S5 (pipeline + trivy/gitleaks/lint) + S6 (dashboard + logs)
   → S7 (rapport, captures en parallèle dès l'app debout)
   → extras P2 (checkov/semgrep/pip-audit, alarmes SNS) selon temps restant
```

---

*Document de conception — sera la base du rapport final.*
