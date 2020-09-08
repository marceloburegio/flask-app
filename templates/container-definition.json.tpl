[{
    "name": "${app_name}",
    "image": "${app_image}",
    "cpu": ${app_cpu},
    "memory": ${app_memory},
    "networkMode": "awsvpc",
    "portMappings": [{
        "containerPort": ${app_port},
        "hostPort": ${app_port}
    }],
    "secrets": [{
        "name": "APP_SECRET_TOKEN",
        "valueFrom": "${app_secret_token}"
    }],
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "${awslogs_group}",
            "awslogs-region": "${awslogs_region}",
            "awslogs-stream-prefix": "ecs"
        }
    }
}]