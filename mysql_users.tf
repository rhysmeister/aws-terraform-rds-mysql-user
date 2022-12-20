# This list contains user details and should 
# be secured for any non-trivial usage
locals {
    users = [
        { 
            user = "user1", 
            host = "%", 
            password = "o(:@/FxUAhk{Xk,T",
            database = "db1",
            permissions = ["SELECT", "INSERT", "UPDATE", "DELETE"]
        },
        { 
            user = "user2", 
            host = "%", 
            password = "-[N-yB0*qXXdCEh!Z",
            database = "db1",
            permissions = ["SELECT"]
        },       
    ]
}

resource "mysql_database" "app_db" {
    for_each = toset(["db1", "db2"])

    name = each.key
}

resource "mysql_user" "app_user" {
    for_each = { for index, user in local.users : user.user => user }

    user               = each.value.user
    host               = each.value.host
    plaintext_password = each.value.password

    depends_on = [
      mysql_database.app_db
    ]
}

resource "mysql_grant" "app_user_permissions" {
    for_each = { for index, user in local.users : user.user => user }

    user       = each.value.user
    host       = each.value.host
    database   = each.value.database   
    privileges = each.value.permissions

    depends_on = [
      mysql_user.app_user
    ]
}
