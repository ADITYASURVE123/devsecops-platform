# Jenkins setup checklist
1. Get the unlock password over SSM Session Manager: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`.
2. Plugins: Pipeline, Git, GitHub Branch Source, Docker Pipeline, SonarQube Scanner, Prometheus metrics, Credentials Binding, SCM Skip.
3. Credentials (all non-AWS): `sonarqube-token` (secret text), `github-token` (secret text, PR comments), `github-token-user` (username + PAT, config commits).
4. Manage Jenkins > System: add SonarQube server named `sonarqube`; set global env `AWS_REGION`, `ECR_REGISTRY`, optional `OLLAMA_URL`.
5. New Item > Multibranch Pipeline > GitHub source > discover branches, PRs and tags. Add a GitHub webhook to `http://<jenkins>:8080/github-branch-source/webhook/` (needs a reachable URL; use an SSH tunnel or a smee.io proxy for demos).
6. Verify the instance profile works: `aws sts get-caller-identity` on the box shows the Jenkins role, and no keys exist in Jenkins credentials.
7. Prometheus plugin exposes `/prometheus`; set the target IP in `observability/kube-prometheus-stack-values.yaml`.
8. Local alternative (no EC2 cost): `docker run -d -p 8080:8080 -v /var/jenkins_home:/var/jenkins_home -v /var/run/docker.sock:/var/run/docker.sock jenkins/jenkins:lts-jdk17`. The identical host/container path for `/var/jenkins_home` is required because the pipeline mounts `$WORKSPACE` into sibling containers. Install the Docker CLI and AWS CLI in that container or build a small custom image.
