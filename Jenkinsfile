// Runs in the home lab's Jenkins, in one pod running the Raku CI image built
// from raku-ci/ in the devops repo. When it passes, Jenkins reports the
// continuous-integration/jenkins/branch status, which starts
// .github/workflows/ci.yml on the same commit.

def buildPod = '''
  apiVersion: v1
  kind: Pod
  spec:
    containers:
      - name: ci
        image: harbor.home.gregdonald.com/raku/ci:latest
        imagePullPolicy: Always
        command: ["sleep"]
        args: ["infinity"]
        resources:
          requests:
            cpu: "2"
            memory: 4Gi
          limits:
            cpu: "4"
            memory: 4Gi
'''

pipeline {
  agent {
    kubernetes {
      defaultContainer 'ci'
      yaml buildPod
    }
  }

  options {
    disableConcurrentBuilds(abortPrevious: true)
    timeout(time: 60, unit: 'MINUTES')
  }

  stages {
    stage('dependencies') {
      steps {
        sh 'zef install --/test --force-install https://github.com/gdonald/BDD-Behave.git'
        sh 'zef install --deps-only --/test --test-depends .'
      }
    }

    stage('test') {
      steps {
        sh './test.raku'
      }
    }
  }
}
