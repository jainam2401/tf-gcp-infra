terraform plan -destroy -var-file='variables.tfvars'
read -p "Press any key to continue with Terraform destroy..."
terraform destroy -var-file='variables.tfvars' -auto-approve