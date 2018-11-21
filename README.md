# WORK IN PROGRESS


az group deployment create -n nvatest01 -g nvatest --template-uri https://raw.githubusercontent.com/Azure/fta-wip/master/Networking/VirtualWAN/nvaLinux.json --parameters '{"vmPwd":{"value":"Microsoft123!"}}'