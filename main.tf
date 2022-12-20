locals {
    identifier               = "rds2"
    allocated_storage        = 10
    engine                   = "mariadb"
    engine_version           = "10.6"
    instance_class           = "db.t3.micro"
    skip_final_snapshot      = true
    multi_az                 = true
    backup_window            = "13:00-15:00"
    backup_retention_period  = 1
    delete_automated_backups = false

    username = "admin"
    password = "TopSecret915!"       
    
    snapshot_identifier = null

    slave_count = 0

    # PITR stuff
    source_db_instance_identifier            = null
    source_db_instance_automated_backups_arn = null
    use_latest_restorable_time               = false
    restore_time                             = null

    default_security_group_id                = "sg-043edf380d518306b"
}

resource "aws_db_instance" "rds1" {
    identifier               = local.identifier
    allocated_storage        = local.allocated_storage
    engine                   = local.engine
    engine_version           = local.engine_version
    instance_class           = local.instance_class
    username                 = local.username
    password                 = local.password
    skip_final_snapshot      = local.skip_final_snapshot
    multi_az                 = local.multi_az
    backup_window            = local.backup_window
    backup_retention_period  = local.backup_retention_period
    delete_automated_backups = local.delete_automated_backups

    vpc_security_group_ids   = [local.default_security_group_id, aws_security_group.rdssg.id]
    publicly_accessible       = true 

    snapshot_identifier      = local.snapshot_identifier

    dynamic "restore_to_point_in_time" {

        for_each = local.use_latest_restorable_time == true || local.restore_time != null ? [1] : []

        content {
            source_db_instance_identifier            = local.source_db_instance_identifier
            source_db_instance_automated_backups_arn = local.source_db_instance_automated_backups_arn
            use_latest_restorable_time               = local.use_latest_restorable_time
            restore_time                             = local.restore_time
        }

    }    
}

resource "aws_db_instance" "rds_slave" {
    count                    = local.slave_count
    identifier               = "${local.identifier}-slave-${count.index + 1}"
    instance_class           = local.instance_class
    skip_final_snapshot      = local.skip_final_snapshot
    delete_automated_backups = local.delete_automated_backups

   replicate_source_db =  aws_db_instance.rds1.identifier
}

resource "aws_ssm_parameter" "endpoint" {
    name        = "/test/rds/endpoint"
    description = "Endpoint of the active RDS Instance"
    type        = "String"
    value       = aws_db_instance.rds1.endpoint
}

resource "aws_ssm_parameter" "admin_username" {
    name        = "/test/rds/username"
    description = "Username of RDS Instance"
    type        = "String"
    value       = local.username
}

resource "aws_ssm_parameter" "admin_password" {
    name        = "/test/rds/password"
    description = "Password of RDS Instance"
    type        = "SecureString"
    value       = local.password
}

resource "aws_ssm_parameter" "slave_endpoints" {
    name  = "/test/rds/slave_endpoints"
    type = "String"
    value = jsonencode(aws_db_instance.rds_slave.*.endpoint)
}

data "http" "ip" {
  url = "https://ifconfig.me/ip"
}

resource "aws_security_group" "rdssg" {
    name = "rdssg"

    ingress {
        from_port   = 3306
        to_port     = 3306
        protocol    = "tcp"
        cidr_blocks = ["${data.http.ip.response_body}/32"] 
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}