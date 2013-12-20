#!/bin/bash

# This configures a neutron network on an all in one VM and boots an instance:

##### NOTE - FOR THIS TO WORK YOU NEED YOUR NETWORK CARD ADDED AS A PORT FOR br-ex
#[root@rhelosp4 network-scripts]# cat ifcfg-eth1
#DEVICE=eth1
#TYPE=OVSPort
#DEVICETYPE=ovs
#OVS_BRIDGE=br-ex
#ONBOOT=yes
#NM_CONTROLLED=no
#HWADDR=52:54:00:6C:3F:F5
#IPV4_FAILURE_FATAL=yes
#IPV6INIT=no
#NAME="System eth1"
#
#[root@rhelosp4 network-scripts]# cat ifcfg-br-ex
#DEVICE=br-ex 
#TYPE=OVSBridge 
#DEVICETYPE=ovs 
#ONBOOT=yes 
#NM_CONTROLLED="no" 
#BOOTPROTO=static 
#STP=off 
#IPADDR=192.168.122.131
#NETMASK=255.255.255.0 
#GATEWAY=192.168.122.1 
#DNS1=192.168.0.14 
#DNS2=192.168.0.1 
#DEFROUTE=yes
###################################################################################


# Public Network to Access OpenStack Compute Instances: 
neutron net-create public-net --router:external=True
### Note: 192.168.122.0/24 is my actual physical network...
neutron subnet-create --name public-subnet public-net 192.168.122.0/24 --enable-dhcp False --allocation-pool start=192.168.122.200,end=192.168.122.220

# Private Network for internal Communication: 
neutron net-create private-net 
neutron subnet-create --name private-subnet private-net 10.10.80.0/24

# Create a router to allow external access: 
neutron router-create router1
neutron router-gateway-set router1 public-net
neutron router-interface-add router1 private-subnet

# Create Access Rules (SSH and ICMP)
neutron security-group-create ssh
neutron security-group-rule-create --direction ingress --ethertype IPv4 --protocol tcp --port-range-min 22 --port-range-max 22 ssh
neutron security-group-rule-create --direction ingress --ethertype IPv4 --protocol icmp ssh


# Setup SSH key
ssh-keygen -t rsa -f testkey -N ""
nova keypair-add --pub-key testkey.pub testkey

# Upload Cirros Image if it doesn't exist... 
if [[ $(glance image-list | grep -i cirros | wc -l) -eq 0 ]]; then
   wget http://cdn.download.cirros-cloud.net/0.3.1/cirros-0.3.1-x86_64-disk.img
   glance image-create --name="Cirros 0.3.1" --disk-format=qcow2 --container-format=bare --is-public=true < cirros-0.3.1-x86_64-disk.img
   sleep 10
fi


# Boot a new instance of the image
IMAGE_UUID=$(glance image-list | grep -i cirros | awk '{print $2}')
PRIVATE_NET_UUID=$(neutron net-list | grep -i private-net | awk '{print $2}')
nova boot --image $IMAGE_UUID --flavor 1 --nic net-id=$PRIVATE_NET_UUID --key_name testkey --security_groups ssh myTestInstance

