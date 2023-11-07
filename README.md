### Pre-requisites:
1. Set environment variables: 
    ```
    export PEM_FILE_PATH="/path/to/your/file.pem"
    export AWS_ACCESS_KEY_ID=""  # AWS ACCESS KEY
    export AWS_SECRET_ACCESS_KEY=""  # AWS SECRET KEY
    export PREFIX="tag_name"  # Prefix tag name for AWS resources. 
    ```
2. Clone the k3s and rke2 repo in your local dev environment. Ex path: ${HOME}/repos/${PRDT} where PRDT can be k3s or rke2. This is needed when we provide RELEASE_BRANCH or RELEASE_BRANCH2 vars - it can cd into this directory and pull the branch we are testing and get its latest commit. 
These branch paths can be set as environment variables as well: 
    ```
    export RKE2_REPO_PATH="${HOME}/repos/rke2"
    export K3S_REPO_PATH="${HOME}/repos/k3s"
    ```

### How to set variables in the test.config.sh and some gotchas: 
1. To run HA Setup test Use: 
```
SERVER1=""
SERVER2=""
SERVER3=""
AGENT1=""
```
For split install: 
```
SERVER1=""
AGENT1=""

SERVER2=""
AGENT2=""
```
Note that this can be gotten by running the aws.sh script from qa/aws-ec2-mgr folder for deployment.
Ex: 
Deploy a HA setup: -d
```
./aws.sh -d -o rhel9.2
INFO: This AMI is packer generated from ami-02b8534ff4b424939
      Enable FIPS and Disable Network Management has been pre-run in the AMI for you
*************************
ACTION STAGE: deploy
*************************
Deploying OS: rhel9.2 ImageID: ami-082bf7cc12db545b9 SSH_USER: ec2-user
ssh -i "/Users/aganesh/.ssh/archana-aws.pem" ec2-user@1.1.1.1
ssh -i "/Users/aganesh/.ssh/archana-aws.pem" ec2-user@2.2.2.2
ssh -i "/Users/aganesh/.ssh/archana-aws.pem" ec2-user@3.3.3.3
ssh -i "/Users/aganesh/.ssh/archana-aws.pem" ec2-user@4.4.4.4
SERVER3="1.1.1.1"
SERVER2="2.2.2.2"
SERVER1="3.3.3.3"
AGENT1="4.4.4.4"
```
or 
Get a 2 server setup: with -g and -s2 options
```
./aws.sh -g -s2   
*************************
ACTION STAGE: get_running
*************************
Getting setups for OS: ubuntu22.4 with ImageID: ami-024e6efaf93d85776 and SSH_USER: ubuntu
ssh -i "/Users/aganesh/.ssh/archana-aws.pem" ubuntu@1.1.1.1
ssh -i "/Users/aganesh/.ssh/archana-aws.pem" ubuntu@2.2.2.2
ssh -i "/Users/aganesh/.ssh/archana-aws.pem" ubuntu@3.3.3.3
ssh -i "/Users/aganesh/.ssh/archana-aws.pem" ubuntu@4.4.4.4
SERVER2="1.1.1.1"
SERVER1="2.2.2.2"
AGENT2="3.3.3.3"
AGENT1="4.4.4.4"
```
2. If you want to do Upgrades on a HA Setup, OR for issue validations and split install setup, 

use: VERSION and VERSION2 variables. or RELEASE_BRANCH and RELEASE_BRANCH2 variables or COMMIT and COMMIT2 variables. You can do a mix and match as well. VERSION and COMMIT2; VERSION and RELEASE_BRANCH2 etc. 

For doing upgrade tests - use only HA setup.

3. test.config.sh has both values you set, and then, there is a section where all variable values get updated, based on some choices you made earlier. 
For instance, 
a) if you did not provide a RELEASE_BRANCH2, but gave a VERSION variable, it will parse the version, know the branch, and get its commit and set that as COMMIT2. This is useful for issue validation to compare an older version and a latest commit. 
b) For secret_encrypt_test, etcd and secret_encrypt configs have to be set. if you did not set the configs, but set the test to true, it will automatically update the config variables later. 

So, in case of doubt, set the debug level, which logs most variables that get updated in the test.config.sh. Also, add extra logs(in case the var you are looking for doesnt get logged), and 'exit' with the test.config.sh in case you want to see what var values are being set first, before you run the test. 

4. Feel free to overwrite any variable values, by adding a var at the end of test.config.sh

### HOW TO RUN TESTS: 

### K3S:

```
cd k3s;
```
Edit the test.config.sh to set the test configs. 
Run:
```
./install-k3s.sh
```

To save logs:
```
./install-k3s.sh 2>&1 | tee -a /path/to/log/file
```

### RKE2:
```
cd rke2;
```
Edit the test.config.sh to set the test configs. 
Run:
```
./install-rke2.sh
```
To save logs:
```
./install-rke2.sh 2>&1 | tee -a /path/to/log/file
```


