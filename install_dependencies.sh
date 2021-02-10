#!/bin/bash
curl --silent --location -o /usr/local/bin/kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.17.11/2020-09-18/bin/linux/amd64/kubectl
chmod +x /usr/local/bin/kubectl
pip install --upgrade awscli && hash -r
yum -y install jq gettext bash-completion moreutils
echo 'yq() {  
		docker run --rm -i -v "${PWD}":/workdir mikefarah/yq "$@" 
}' | tee -a ~/.bashrc && source ~/.bashrc
kubectl completion bash >>  ~/.bash_completion
. /etc/profile.d/bash_completion.sh
. ~/.bash_completion
echo 'export LBC_VERSION="v2.0.0"' >>  ~/.bash_profile
.  ~/.bash_profile