#!/bin/bash

export COMPOSE_PROJECT_NAME=mongodbdocker
KEYFILE=mongodb.key
max_retries=10
retry_interval=5
source .env

if [ -z "$P" ] || [ -z "$U" ]; then
    echo "Biến môi trường P và U không được đặt trong file .env!"
    exit 1
fi

function check_connection() {
    local container_name="$1"
    docker exec "$container_name" mongosh --eval "quit(db.runCommand({ ping: 1 }).ok ? 0 : 1)" > /dev/null 2>&1
    return $?
}

function execute_mongosh_with_eval() {
    local server=$1
    local eval_cmd=$2

    local output
    output=$(docker exec "$server" mongosh --eval "$eval_cmd" 2>&1)

    if [ $? -ne 0 ]; then
        echo "Thực hiện auth $server"
        docker exec "$server" mongosh -u "$U" -p "$P" --eval "$eval_cmd"
    else
        echo "Không auth $server"
        echo "$output"
    fi
}

function wait_for_connection() {
    local host="$1"
    local max_retries="$2"
    local retry_interval="$3"
    local retry_count=0
    while [ $retry_count -lt $max_retries ]; do
        if check_connection "$host"; then
            echo "Kết nối đến $host thành công!"
            return 0
        else
            echo "Không thể kết nối đến $host. Đang thử lại..."
            sleep "$retry_interval"
            retry_count=$((retry_count + 1))
        fi
    done
    echo "Timeout: Không thể kết nối đến $host sau $max_retries lần thử."
    return 1
}

function initiate_genKey() {
    if [ ! -f "$KEYFILE" ]; then
        openssl rand -base64 756 > "$KEYFILE"
        sudo chmod 400 "$KEYFILE"
        sudo chown 999:999 "$KEYFILE"
        echo "Đã tạo keyfile mới: $KEYFILE"
    else
        echo "Keyfile đã tồn tại: $KEYFILE"
    fi
}

function initiate_replica_set() {
    local container_name="$1"
    local replica_set_name="$2"
    local members="$3"

    local value="{\"_id\": \"$replica_set_name\", \"version\": 1, \"members\": [$members]}"

    if [ "$replica_set_name" = "configsvr" ]; then
        value="{\"_id\": \"$replica_set_name\", \"configsvr\": true, \"version\": 1, \"members\": [$members]}"
    fi
    if wait_for_connection "$container_name" "$max_retries" "$retry_interval"; then
       echo "Thực hiện replica set cho $container_name!"
       eval_replicaset="rs.initiate($value); printjson($value);"
       execute_mongosh_with_eval "$container_name" "$eval_replicaset"
    else
       echo "Không thể kết nối đến $container_name!"
    fi

}

initiate_genKey

docker-compose up -d 

# Thực hiện replica set cho config server
initiate_replica_set "configsvr-a" "configsvr" "{ _id: 0, host: 'configsvr-a:27017', priority: 2 },{ _id: 1, host: 'configsvr-b:27017', priority: 0 },{ _id: 2, host: 'configsvr-c:27017', priority: 0 }" 

#Thực hiện replica set cho các shard
initiate_replica_set "shard-01a" "shard-01" "{ _id: 0, host: 'shard-01a:27017', priority: 2 },{ _id: 1, host: 'shard-01b:27017', priority: 0 },{ _id: 2, host: 'shard-01c:27017', priority: 0 }"
initiate_replica_set "shard-02a" "shard-02" "{ _id: 0, host: 'shard-02a:27017', priority: 2 },{ _id: 1, host: 'shard-02b:27017', priority: 0 },{ _id: 2, host: 'shard-02c:27017', priority: 0 }"
initiate_replica_set "shard-03a" "shard-03" "{ _id: 0, host: 'shard-03a:27017', priority: 2 },{ _id: 1, host: 'shard-03b:27017', priority: 0 },{ _id: 2, host: 'shard-03c:27017', priority: 0 }"
# Thực hiện thêm shard và tạo người dùng admin
if wait_for_connection "router-01" "$max_retries" "$retry_interval"; then
   echo "Thực hiện thêm shard!"
   eval_addShard='for (var i = 1; i <= 3; i++) { var shardNumber = i < 10 ? "0" + i : "" + i; var shardName = "shard-" + shardNumber; var shardHosts = [ "shard-" + shardNumber + "a:27017", "shard-" + shardNumber + "b:27017", "shard-" + shardNumber + "c:27017" ]; var addShard = sh.addShard(shardName + "/" + shardHosts.join(",")); }'
   execute_mongosh_with_eval "router-01" "$eval_addShard"
   eval_createUser="admin = db.getSiblingDB('admin'); admin.createUser({ user: '$U', pwd: '$P', roles: [{ role: 'root', db: 'admin' }] });"
   
   echo "Thực hiện tạo người dùng admin!"

#tạo admin trên configsvr sẽ đồng bộ lên router nhưng không đồng bộ lên các shard

   execute_mongosh_with_eval "configsvr-a" "$eval_createUser"
   execute_mongosh_with_eval "router-01" "$eval_createUser"

   execute_mongosh_with_eval "shard-01a" "$eval_createUser"
   execute_mongosh_with_eval "shard-02a" "$eval_createUser"
   execute_mongosh_with_eval "shard-03a" "$eval_createUser"

else
    echo "Không thể kết nối đến MongoDB container!"
fi