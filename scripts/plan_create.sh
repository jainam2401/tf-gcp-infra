terraform validate
echo "Running to Plan terraform"
terraform plan -var-file='variables.tfvars'
read -p "Press any key to continue with Terraform apply..."
echo "Starting to start services"
terraform apply -var-file='variables.tfvars' -auto-approve


             