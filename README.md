# aws_terraform

## 	Starting The Website in aws and terraform 

### First create  terraform file
```
touch web.tf 
```
### Edit the terraform file for aws and null
```
provider "aws" {
  profile =  "aman1"
  region  = "ap-south-1"
}

resource "null_resource" "null_remote" {
	
}
```


download package aws and null using file 

```
terraform init
```