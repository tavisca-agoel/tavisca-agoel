// S3 Remote Backend Configuration. 
// Ensure that the S3 Bucket exists and IAM Role used for Terraform Deployments has the necessary Read and Write Permission to the S3 Bucket Configured
terraform {
    backend "s3" {  
        bucket     = "cxloyalty-application-artifacts-dev"
        key        = "divvycloud/terraform.tfstate"
        region     = "us-east-1"
        encrypt    = false
        kms_key_id = "arn:aws:kms:us-east-1:982267650803:key/2a667904-c60a-48f3-ac34-2fb66f8fb85a"
    }
}
