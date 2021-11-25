# Terraform:


The Terraform script in the terraform directory is used to deploy DivvyCloud Resources in Shared Security AWS Account.

Terraform Script is structured as follows:

1) **main.tf:** Defines the resources to be deployed.
2) **variables.tf:** Defines the variables and locals used in *main.tf*.
3) **backend.tf:** Remote S3 Backend configuration.
4) **outputs.tf:** Any desired outputs from Terraform.
5) **terraform.tfvars:** Defines any variables to be overriden at run time. Here it is used to override divvycloud_random_short, divvycloud_random, divvycloud_version variables.




# Jenkins:


The *DivvyCloudUpdate.jenkinsfile* defined in jenkins folder is used to the run the above mentioned Terraform script.

The Jenkins *DivvyCloudUpdate* pipeline takes three paramters:

1)  **AWS_Secret_Manger_Random_String_Length:**
       - Description - Length of the random string to be appended to the name of AWS Secret Manager Resource which holds RDS secrets.
       - Default Value - 7

2)  **Random_RDS_Password_Length:**
       - Description - Length of RDS password.
       - Default Value - 20

3)  **Divvy_Cloud_Version:**
       - Description - Version of Divvy Cloud to be updated.
       - Default Value - "v20.3.1"

The Jenkins DivvyCloudUpdate pipeline runs in 9 Stages:

1) **Checkout SCM:** Gets the Jenkins file from the jenkins folder of this repository.

2) **Tool Install:** Installs Terraform Binary.

3) **Git Checkout:** Cleans the workspace directory and clones this repository.

4) **Inject Jenkins Paramter Values into terrform.tfvars:** Injects the above mentioned parameter values into terraform.tfvars file.

5) **Terraform init:** Initializes Terraform in working directory and sets Remote Backend to S3 Bucket in Shared Security Account.

6) **Terraform validate:** Validates the configuration files in a directory, referring only to the configuration and not accessing any remote services such as remote state, provider, etc

7) **Terraform plan:** Generates Terraform plan in *tfplan* file depending on values passed in terraform.tfvars file.

8) **Terraform apply:** Applies the Terraform plan from tfplan file and saves the state to remote backend.

9) **Terraform show:** Displays the resources deployed by previous stage.