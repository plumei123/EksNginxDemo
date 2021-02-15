#!/bin/bash
# authors: plumei.zhang@gmail.com
# Run All CloudFormation Create Stack for VPC, Bastion EKS Cluster and NodeGroup Templates


##################################### Functions Definitions
function usage() {
    echo "usage: $0 [options]"
    echo "Run All CloudFormation Create Stack for VPC, Bastion and EKS Cluster Templates"
    echo "by default are using AWS CLI default profile & region, otherwise please provide profile and/or region option"
    echo " "
    echo -e "options:"
    echo -e "-h, --help \t Show options for this script"
    #echo -e "-p, --profile \t AWS CLI profile"
    echo -e "-r, --region \t AWS Region"
    echo -e "--vpc-stack \t VPC CloudFormation's Stack Name ('EKS-Demo-vpc' by default)"
    echo -e "--nodegroup-stack \t Bastion CloudFormation's Stack Name ('EKS-Demo-Nodegroup' by default)"
    echo -e "--eks-stack \t EKS CloudFormation's Stack Name ('EKS-Demo-Cluster' by default)"
}

function aws_get_identity() {
  USER_ARN=($(eval "aws " $REGION_PARAM " sts get-caller-identity --query 'Arn' --output text"))
  if [[ $USER_ARN == "arn:aws:iam::"* ]]; then
    echo "User : $USER_ARN"
    export USER_ARN
  else
    exit;
  fi
}

function aws_create_stack() {
  if [ "$#" -le "1" ]; then echo "error: aws_create_stack Stack Name & Template are Required"; exit 1; fi

  local STACK_NAME=$1
  local TEMPLATE_FILE=$2
  local PARAMS=$3
  
  local STACK_CREATE_ID=($(eval "aws " $REGION_PARAM " cloudformation create-stack --stack-name " $STACK_NAME " --template-body " $TEMPLATE_FILE " " $PARAMS " --query 'StackId' --output text"))

  echo "Started to create $STACK_NAME : $STACK_CREATE_ID"
  
  if [[ -z "$STACK_CREATE_ID" ]] ; then echo "$STACK_NAME Create Failed"; exit 1; fi
  echo "Started create stack, errorcode is $?"
  echo "Creating $STACK_NAME : $STACK_CREATE_ID"
}

function aws_wait_create_stack() {
  if [ "$#" -le "0" ]; then echo "error: aws_create_stack Stack Name & Template are Required"; exit 1; fi

  local STACK_NAME=$1
  
  STACK_STATUS=$(eval "aws " $REGION_PARAM " cloudformation wait stack-create-complete --stack-name " $STACK_NAME)
  echo"checking status, echo $?"

  if [[ $STACK_STATUS == "" ]]; then
      echo "$STACK_NAME Created"
      echo "Finished create stack, errorcode is $?"
  else
      echo $?
      exit 1
  fi
}



function aws_create_stack_VPC() {
  aws_create_stack $VPC_STACK "file://./eks_demo_vpc_step1.yaml"
}

function aws_create_stack_Nodegroup() {
  aws_create_stack $NODEGRP_STACK "file://./eks_demo_nodegroup_step3.yaml" "--parameters ParameterKey=VpcName,ParameterValue=$VPC_STACK ParameterKey=ClusterName,ParameterValue=$EKS_STACK ParameterKey=NodeGroupDesiredCapacity,ParameterValue=2 --capabilities CAPABILITY_NAMED_IAM"
}

function aws_create_stack_EKS() {
  aws_create_stack $EKS_STACK "file://./eks_demo_cluster_step2.yaml" "--parameters ParameterKey=VpcName,ParameterValue=$VPC_STACK --capabilities CAPABILITY_NAMED_IAM"
}

##################################### End Function Definitions
set -x
NARGS=$#

# extract options and their arguments into variables.
while true; do
    case "$1" in
        -h | --help)
            usage
            exit 1
            ;;
        -r | --region)
            REGION="$2";
	        REGION_PARAM="--region $REGION"
            shift 2
            ;;
        --vpc-stack)
            VPC_STACK="$2";
            shift 2
            ;;
        --eks-stack)
            EKS_STACK="$2";
            shift 2
            ;;
        --nodegroup-stack)
            NODEGRP_STACK="$2";
            shift 2
            ;;
        --)
            break
            ;;
        *)
            break
            ;;
    esac
done

if [[ $NARGS == 0 ]] ; then echo " "; fi

if [[ -z "$VPC_STACK" ]] ; then VPC_STACK="EKS-Demo-vpc"; fi
if [[ -z "$EKS_STACK" ]] ; then EKS_STACK="EKS-Demo-Cluster"; fi
if [[ -z "$NODEGRP_STACK" ]] ; then NODEGRP_STACK="EKS-Demo-Nodegroup"; fi

#aws_get_identity
#echo "after aws_get_identity, errorcode is $?"

echo "VPC Stack Name : $VPC_STACK"
echo "EKS Stack Name : $EKS_STACK"
echo "NodeGroup Stack Name : $NODEGRP_STACK"


aws_create_stack_VPC
aws_wait_create_stack $VPC_STACK  

aws_create_stack_EKS
aws_wait_create_stack $EKS_STACK

aws_create_stack_Nodegroup
aws_wait_create_stack $NODEGRP_STACK


set -x

exit;
