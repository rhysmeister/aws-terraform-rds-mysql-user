# aws-terraform-rds-mysql-user
An extension of [aws-terraform-rds-default-backup-multi-master-slaves](https://github.com/rhysmeister/aws-terraform-rds-default-backup-multi-master-slaves) using the [mysql_user](https://registry.terraform.io/providers/nkhanal0/mysql/latest/docs/resources/user) resource. The [mysql_provider](https://registry.terraform.io/providers/nkhanal0/mysql/latest/docs) requires connectivity to the RDS Instance so we need to allow this.

* We add the security group *rdssg* which allows access over 3306/TCP to this [IP](https://ifconfig.me/ip), i.e. your home connection. This is just done for demoing the MySQL provider. Do not use for production purposes. 
* For production usage a control node in the AWS environment would be a more secure method to use the MySQL Provider in.
* Other ideas to explore to init db.... Task in a Container? Ansible Playbook & Parameter Store? Restore a snapshot with the users already created?   

# Initial Deployment

Ensure the identifier, snapshot_identifier and PITR local variables are as desired.

```bash
terraform apply
```

# Perform a restore without deleting the source RDS instance

First remove any slave instances from the state

```bash
terraform state rm aws_db_instance.rds_slave
```

Remove the master RDS instance

```bash
terraform state rm aws_db_instance.rds1
```

* Update the `identifier` value in the locals section, i.e. rds1 -> rds2
* Set `source_db_instance_identifier`to the source db, i.e. rds1
* Set `use_latest_restorable_time`to true

Perform the restore. This will create the rds2 instance using the backups of rds1...

```bash
terraform apply
```

The rds1 instance, slaves and any backups must be manually deleted as we have deleted the state from Terraform.

To cleanup the rds2 instance...

```bash
terraform destroy
```

# Promote a slave to master / replica to primary

The goals of this section to to take a Multi-AZ setup, with read-only slaves, promote one slave to become the new master, and maintain this state in Terraform, returning it to the "default" setup. The default setup here is considered to be a Multi-AZ DB Instance with 3 read-only slaves.

First creating a starting point....

```bash
terraform apply
```

In the web console...

* RDS > Databases
* Select the slave to promote, i.e. rds1-slave-1
* Actions > Promote > Promote read replica

The status of the slave will move to "Modifying" and it will move out of the master/slave hierachy. This process take a fe w minutes to complete. Delete the other db instances in the setup as they will not be required again. Ensure the rds1 instance has completed deletion before proceeding (Optional call it rds2 to make the process a bit quicker, don't forget to update the TF code to reflect this)..

Next, select the new master db instance, i.e. rds1-slave-1 and fix the name

* Modify
* In the field "DB Instance Identifier", update the name to match the master instance in the Terraform code, i.e. rds1
* Click Continue
* Select "Apply immediately"
* Click "Modify DB Instance"

Next remove the DB Instances from the TF state...

```bash
terraform state rm aws_db_instance.rds1
terraform state rm aws_db_instance.rds_slave
```

Import the state of rds2...

```bash
terraform import aws_db_instance.rds1 rds2
```

Next perform a `terraform apply` to update the state of our MariaDB Cluster. This will make the master instance Multi-AZ, create 3 read-only slaves and then update the SSM Parameter as appropriate.

```bash
terraform apply
```

This will take sometime to complete but at the end we should have the same setup as we started with.


# SSM Parameters

* endpoint - The master read/write endpoint. String.
* username - MariaDB root user. String.
* password - MariaDB root user password. String.
* slaves_endpoints - List of read only slaves endpoint. List of strings.

# Notes

* This version of the module introduces a locals variable for identifier so we can choose the name for our db instance - this is to enable restores without deleting our instance.
* Root password is hard-coded in this module. Fix this for any non-trivial usage.
* In order for the slaves to be created automatic backups must be enabled on the master.
* Disassociating a backup does not delete it but it might take some time to appear in RDS > Automated backups > Retained backups. Ensure that delete_automated_backups is set to false before deleting the RDS instance.
* We want to support PITR as well as snapshot restore in this module. The restore_to_point_in_time block needs to be dynamic for this to work properly. Creating the block with all null values causes terraform to crash.
* Further work can be done here involving delayed slaves and recovering from a user error [Recover from a disaster with delayed replication in Amazon RDS for MySQL](https://aws.amazon.com/blogs/database/recover-from-a-disaster-with-delayed-replication-in-amazon-rds-for-mysql/) *UPDATE" This is handles slightly differently in MariaDB, see [Working with MariaDB read replicas](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_MariaDB.Replication.ReadReplicas.html)