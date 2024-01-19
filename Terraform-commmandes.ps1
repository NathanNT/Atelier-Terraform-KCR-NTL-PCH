terraform init; terraform fmt; terraform validate
terraform plan --out=planfile.tfplan
terraform apply -auto-approve "planfile.tfplan"
