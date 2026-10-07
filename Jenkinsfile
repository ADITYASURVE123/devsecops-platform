// Declarative multibranch pipeline. Tools run as pinned containers; the Jenkins host needs Docker.
// AWS auth = EC2 instance profile (no access keys stored anywhere).
// Jenkins credentials used (all non-AWS): sonarqube-token, github-token.
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 40, unit: 'MINUTES')
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '15'))
  }

  environment {
    AWS_REGION   = "${env.AWS_REGION ?: 'ap-south-1'}"
    ECR_REGISTRY = "${env.ECR_REGISTRY ?: '<AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com'}"
    IMAGE_TAG    = "${env.GIT_COMMIT?.take(8) ?: 'local'}"
    SERVICES     = 'orders-api inventory-api'
    GITLEAKS     = 'zricethezav/gitleaks:v8.21.2'
    TRIVY        = 'aquasec/trivy:0.56.2'
    SYFT         = 'anchore/syft:v1.14.0'
    TFLINT       = 'ghcr.io/terraform-linters/tflint:v0.53.0'
    TFSEC        = 'aquasec/tfsec:v1.28.10'
    PYTHON_IMG   = 'python:3.12-slim'
    OLLAMA_URL   = "${env.OLLAMA_URL ?: 'http://localhost:11434'}"
  }

  stages {
    stage('Checkout') {
      steps { checkout scm; sh 'git log -1 --oneline' }
    }

    stage('Secrets scan (Gitleaks)') {
      steps {
        sh 'docker run --rm -v "$WORKSPACE:/repo" $GITLEAKS detect --source /repo --no-banner --redact --exit-code 1'
      }
    }

    stage('Lint + unit tests') {
      steps {
        script {
          def jobs = [:]
          env.SERVICES.split(' ').each { svc ->
            jobs[svc] = {
              sh """
                docker run --rm -v "\$WORKSPACE/services/${svc}:/app" -w /app \$PYTHON_IMG sh -c '
                  pip install -q --no-cache-dir -r requirements-dev.txt &&
                  ruff check . &&
                  pytest -q --cov=app --cov-report=xml --cov-fail-under=80'
              """
            }
          }
          parallel jobs
        }
      }
    }

    stage('SonarQube quality gate') {
      steps {
        script {
          sh '''
            rm -f "$WORKSPACE/.scannerwork/report-task.txt" \
              "$WORKSPACE/.scannerwork-orders-api/report-task.txt" \
              "$WORKSPACE/.scannerwork-inventory-api/report-task.txt"
          '''
          env.SERVICES.split(' ').each { svc ->
            withSonarQubeEnv('sonarqube') {   // Manage Jenkins > System > SonarQube servers
              sh """
                mkdir -p "\$WORKSPACE/.scannerwork-${svc}" "\$WORKSPACE/.scannerwork"
                chmod 1777 "\$WORKSPACE/.scannerwork-${svc}"
                docker run --rm -e SONAR_HOST_URL="\$SONAR_HOST_URL" -e SONAR_TOKEN="\$SONAR_AUTH_TOKEN" \
                  -v "\$WORKSPACE/services/${svc}:/usr/src" \
                  -v "\$WORKSPACE/.scannerwork-${svc}:/tmp/.scannerwork" \
                  sonarsource/sonar-scanner-cli:11.0
                cp "\$WORKSPACE/.scannerwork-${svc}/report-task.txt" "\$WORKSPACE/.scannerwork/report-task.txt"
                rm -f "\$WORKSPACE/.scannerwork-${svc}/report-task.txt"
                chmod 755 "\$WORKSPACE/.scannerwork-${svc}"
              """
            }
            timeout(time: 5, unit: 'MINUTES') { waitForQualityGate abortPipeline: true }
          }
        }
      }
    }

    stage('Trivy filesystem scan') {
      steps {
        sh '''
          docker run --rm -v "$WORKSPACE:/src" "$TRIVY" fs --scanners vuln,misconfig --severity HIGH,CRITICAL --exit-code 1 --no-progress /src/services
          docker run --rm -v "$WORKSPACE:/src" "$TRIVY" fs --scanners vuln,misconfig --severity HIGH,CRITICAL --exit-code 1 --no-progress /src/deploy
        '''
      }
    }

    stage('Terraform checks') {
      when { changeset 'infra/**' }
      steps {
        sh 'docker run --rm -v "$WORKSPACE/infra:/data" -w /data $TFLINT --recursive'
        sh 'docker run --rm -v "$WORKSPACE/infra:/src" $TFSEC /src --soft-fail=false --minimum-severity HIGH'
      }
    }

    stage('Build images') {
      steps {
        script {
          env.SERVICES.split(' ').each { svc ->
            sh "docker build -t ${svc}:${IMAGE_TAG} services/${svc}"
          }
        }
      }
    }

    stage('Image scan + SBOM') {
      steps {
        script {
          env.SERVICES.split(' ').each { svc ->
            sh """
              docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \$TRIVY image \
                --severity HIGH,CRITICAL --exit-code 1 --ignore-unfixed --no-progress ${svc}:${IMAGE_TAG}
              docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \$SYFT ${svc}:${IMAGE_TAG} -o cyclonedx-json > sbom-${svc}.json
            """
          }
        }
        archiveArtifacts artifacts: 'sbom-*.json', fingerprint: true
      }
    }

    stage('AI PR review (advisory)') {
      when { changeRequest() }
      steps {
        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {   // can never fail the build
          withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
            sh '''
              git fetch --no-tags origin "$CHANGE_TARGET" || true
              git diff "origin/$CHANGE_TARGET...HEAD" > diff.txt || true
              python3 ci/ai-reviewer/reviewer.py pr-review --input diff.txt || true
            '''
          }
        }
      }
    }

    stage('Push to ECR') {
      when { anyOf { branch 'main'; buildingTag() } }
      steps {
        sh '''
          aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"
        '''
        script {
          env.SERVICES.split(' ').each { svc ->
            sh """
              docker tag ${svc}:${IMAGE_TAG} \$ECR_REGISTRY/${svc}:${IMAGE_TAG}
              docker push \$ECR_REGISTRY/${svc}:${IMAGE_TAG}
            """
          }
        }
      }
    }

    stage('Release notes (tags)') {
      when { buildingTag() }
      steps {
        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
          sh '''
            prev=$(git describe --tags --abbrev=0 "${TAG_NAME}^" 2>/dev/null || git rev-list --max-parents=0 HEAD)
            git log --pretty=format:'%s' "$prev..HEAD" > commits.txt
            python3 ci/ai-reviewer/reviewer.py release-notes --input commits.txt | tee release-notes.md || true
          '''
          archiveArtifacts artifacts: 'release-notes.md', allowEmptyArchive: true
        }
      }
    }

    stage('GitOps: bump image tag') {
      when { branch 'main' }
      steps {
        withCredentials([usernamePassword(credentialsId: 'github-token-user', usernameVariable: 'GH_USER', passwordVariable: 'GH_TOKEN')]) {
          script {
            env.SERVICES.split(' ').each { svc ->
              sh "./scripts/bump-image-tag.sh ${svc} ${IMAGE_TAG} dev"
            }
          }
          // [skip ci] prevents the config commit from re-triggering the pipeline (SCM Skip plugin).
          // Jenkins only edits Git; Argo CD does the deploy. No kubectl from Jenkins.
          sh '''
            git config user.name "jenkins-ci"; git config user.email "jenkins@localhost"
            git add deploy/envs/dev
            git diff --cached --quiet && { echo "no change"; exit 0; }
            git commit -m "ci: deploy ${IMAGE_TAG} [skip ci]"
            git push "https://${GH_USER}:${GH_TOKEN}@$(git remote get-url origin | sed 's#https://##')" HEAD:main
          '''
        }
      }
    }
  }

  post {
    failure {
      // Advisory log explainer: tail of the console, never blocks anything.
      catchError(buildResult: 'FAILURE', stageResult: 'UNSTABLE') {
        sh '''
          curl -s --max-time 20 "${BUILD_URL}consoleText" | tail -n 150 > failure.log || true
          python3 ci/ai-reviewer/reviewer.py explain-failure --input failure.log || true
        '''
      }
    }
    always { sh 'docker image prune -f >/dev/null 2>&1 || true' }
  }
}
