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
        AWSACCOUNT="592269360669"
    }	
    stages {
        stage('CleanWorkSpace') {
            steps {
                sh 'rm -rf *'
                checkout scm
            }
        }
		stage ('PreCheckYaml') {
		    steps {
                //cfn-guard check template file parameters rules. if all success, return 0, else return errorcode.
                //Eg: [myCluster] failed because it does not contain the required property of [EncryptionConfig].Number of failures: 1 echo $?, output 2
                sh '/usr/local/bin/cfn-guard check -t eks_demo_cluster_step2.yaml -r precheck.rules -s'
            }
            post {
            	failure {
            		echo "Build ECR&EKS canceled thanks to PreCheckYaml executed failed by cfn-guard ..."
            	}
            }		
		}
        stage('Build ECR') {
            steps {           
                sh '''
				aws cloudformation create-stack --template-body file://./ecrNginx.yaml --stack-name nginxecr --region $REGION --parameters ParameterKey=RepoName,ParameterValue=$repoName --capabilities CAPABILITY_NAMED_IAM
				'''}
		}
        stage('Push Nginx to ECR') {
            steps {		
                sh '''
                echo $DockerhubPwd | docker login --username plumei --password-stdin
                docker search "nginx"
                docker pull $repoName
				export REPOSITORY=$(aws ecr describe-repositories --repository-name $repoName  --region $REGION --query "repositories[0].repositoryUri" --output text) 
                aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $AWSACCOUNT.dkr.ecr.$REGION.amazonaws.com
                docker tag $repoName:latest $REPOSITORY:latest
                docker push $REPOSITORY:latest
			    '''
            }
        }        
		stage('Build Eks Cluster') {
            steps {		
                sh '''
                chmod +x ./deploy_ekscluster_all.sh
                sh -x ./deploy_ekscluster_all_noprofile.sh -r $REGION --vpc-stack $vpcStackName --eks-stack $clusterStackName --nodegroup-stack $nodegroupStackName 
				
				aws eks --region $REGION update-kubeconfig --name $clusterStackName --kubeconfig ~/.kube/config
                /usr/local/bin/kubectl apply -f aws-iam-authenticator.yaml
                aws eks list-clusters --region=$REGION --output=json
			    '''
            }
        }

        stage('Scan Nginx image of ECR') {
            steps {	
                //if there is CRITICAL warning, stop deploying Nginx image to EKS	
                sh '''
                #aws ecr start-image-scan --registry-id $AWSACCOUNT --region $REGION --repository-name $repoName --image-id imageTag=latest
                #aws ecr wait image-scan-complete --registry-id $AWSACCOUNT --region $REGION --repository-name $repoName --image-id imageTag=latest
                SCAN_FINDINGS=$(aws ecr describe-image-scan-findings --registry-id $AWSACCOUNT --region $REGION --repository-name $repoName --image-id imageTag=latest | jq '.imageScanFindings.findingSeverityCounts')
                CRITICAL=$(echo $SCAN_FINDINGS | jq '.CRITICAL')
                if [ $CRITICAL != null ] ; then
                    echo Docker image contains vulnerabilities at CRITICAL or HIGH level
                    exit 1  #exit execution due to docker image vulnerabilitiesr
                fi
                # aws ecr describe-image-scan-findings --registry-id 592269360669 --repository-name nginxdemos/hello --image-id imageTag=latest --query imageScanFindings | grep "CRITICAL"
			    '''
            }
        }
		
		stage('Deploy Nginx to EKS') {
		    steps {			
			    sh '''
				   export REPOSITORY=$(aws ecr describe-repositories --repository-name $repoName  --region $REGION --query "repositories[0].repositoryUri" --output text)
                   sed -ri "/\\{REPOSITORY\\}/ s#\\{REPOSITORY\\}#$REPOSITORY#" deployment.yaml'''
				sh  '''
     				/usr/local/bin/kubectl apply -f deployment.yaml
					/usr/local/bin/kubectl apply -f service.yaml
					/usr/local/bin/kubectl get pods
					/usr/local/bin/kubectl describe deployment
					/usr/local/bin/kubectl get deployments
					/usr/local/bin/kubectl get svc --all-namespaces | grep LoadBalancer | awk '{print $5}'
					/usr/local/bin/kubectl get svc/nginx -o=jsonpath="{.status.loadBalancer.ingress..hostname}"

					'''
			}
		}
	}
}
