// Jenkins Shared Library step (bonus). Runs a pinned tool image against the workspace.
// Usage in a Jenkinsfile:  @Library('devsecops-lib') _   then   runTool(image: 'aquasec/trivy:0.56.2', args: 'fs --exit-code 1 .')
def call(Map cfg) {
    String entry = cfg.entrypoint ? "--entrypoint ${cfg.entrypoint}" : ''
    sh """
      docker run --rm ${entry} -v "\$WORKSPACE:/work" -w /work ${cfg.image} ${cfg.args}
    """
}
