pipeline {
    agent any
	parameters {
		string(defaultValue: 'nginxdemos/hello', description: '', name: 'repoName')
		string(defaultValue: 'EKS-Demo-vpc', description: '', name: 'vpcStackName')
		string(defaultValue: 'EKS-Demo-Cluster', description: '', name: 'clusterStackName')
		string(defaultValue: 'EKS-Demo-Nodegroup', description: '', name: 'nodegroupStackName')
		
    }
    environment {
		REGION="us-east-2";
    }	
    stages {
        stage('CleanWorkSpace') {
            steps {
                sh 'rm -rf *'
                checkout scm
            }
        }
        stage('Build ECR') {
            steps {
                // Get some code from a GitHub repository
                //git 'https://github.com/jglick/simple-maven-project-with-tests.git'
                //export repoName="nginxdemos/hello"
                //export region="us-east-2"
           
                sh '''
				aws cloudformation create-stack --template-body file://./ecrNginx.yaml --stack-name nginxecr --region $REGION --parameters ParameterKey=RepoName,ParameterValue=$repoName --capabilities CAPABILITY_NAMED_IAM
				'''}
		}
        stage('Push Nginx to ECR') {
            steps {		
                sh '''
                echo $DockerhubPwd | docker login --username plumei --password-stdin
                docker search "nginx"
                docker pull nginxdemos/hello
				export REPOSITORY=$(aws ecr describe-repositories --repository-name $repoName  --region $REGION --query "repositories[0].repositoryUri" --output text) 
                aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin 592269360669.dkr.ecr.$REGION.amazonaws.com
                docker tag nginxdemos/hello:latest $REPOSITORY:latest
                docker push $REPOSITORY:latest
			    '''
            }
        }
        stage('Build Eks Cluster') {
            steps {		
                sh '''
                chmod +x ./deploy_ekscluster_all.sh
                sh -v ./deploy_ekscluster_all_noprofile.sh -r REGION --vpc-stack $vpcStackName --eks-stack $clusterStackName --nodegroup-stack $nodegroupStackName 
			    '''
            }
        }
        
		stage('Deploy Eks Cluster') {
            steps {		
                sh '''
                chmod +x ./deploy_ekscluster_all.sh
                sh -v ./deploy_ekscluster_all_noprofile.sh -r REGION --vpc-stack $vpcStackName --eks-stack $clusterStackName --nodegroup-stack $nodegroupStackName 
				
				aws eks --region us-east-2 update-kubeconfig --name EKS-Demo-Cluster --kubeconfig ~/.kube/config
                 /usr/local/bin/kubectl apply -f aws-iam-authenticator.yaml
                 aws eks list-clusters --region=us-east-2 --output=json
			    '''
            }
        }
		
		stage('Deploy Nginx to EKS') {
		    steps {			
			    sh '''
					export REPOSITORY=$(aws ecr describe-repositories --repository-name $repoName  --region $region --query "repositories[0].repositoryUri" --output text) 
					sed -ri "/\{REPOSITORY\}/ s#\{REPOSITORY\}#$REPOSITORY#" deployment.yaml
					/usr/local/bin/kubectl apply -f deployment.yaml
					/usr/local/bin/kubectl apply -f service.yaml
					/usr/local/bin/kubectl get deployments
					/usr/local/bin/kubectl get pods
					/usr/local/bin/kubectl describe deployment 
					/usr/local/bin/kubectl get svc --all-namespaces
					/usr/local/bin/kubectl get svc/nginx -o=jsonpath="{.status.loadBalancer.ingress..hostname}"
					/usr/local/bin/kubectl get svc --all-namespaces
					'''
			}
		}
	}
}
