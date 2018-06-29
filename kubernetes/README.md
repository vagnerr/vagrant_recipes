# Turnkey N-Node Kubernetes Cluster (on Virtualbox)

Simple working Kubernetes cluster runnning under oracle Virtualbox.
The default settup with run 1 master and 2 slave hosts. This should
be enough for simple tests, however the number of slave hosts is configurable on the command line.

Currently it does use bridged networking and builds with sequential IP addresses starting with 172.16.1.201

```vagrant ssh``` will connect to the master by default, which is usually what you want anyway.

## Optional arguments

* ```--slaves=n``` override default(2) number of slave hosts to start
* ```--masterip="a.b.c.d"``` start ip address numbering from this value

## Example Usage

* Spinup a default configuration of three hosts ( 1 master, 2 slaves ) starting at 172.16.1.201
  ```powershell

  vagrant up

  ```
* More complex example 6 nodes ( including master ) and diffent starting ip
  ```powershell

  vagrant up --slaves=5 --masterip="192.168.100.100"

  ```

### Kube Dashboard

There is also a script included to provision the kubernetes dashboard. Once the cluster is established, login to the master with ```vagrant ssh``` then execute the provision script and start the proxy...
```bash

/vagrant/provision-kubedashboard.bash
kubectl proxy

```
...once complete this will present the access token that can be used to login to the webinterface.

* <http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/>

Note that to facilitate this an additional NAT port forward is configured on the master server for localhost:8001 -> localhost:8001


## Troubleshooting

### Pods start normally but cannot comunicate propperly with the master host

Can be caused by an issue in the flannel network when it is settup if it uses the "default" ip of the host to select its local ID. The problem with this in the virtualbox environment is that each host gets a NAT network as the first ethernet port on the VM and Virtualbox assigns all the boxes the same IP address on the NAT. To get round this the flannel network is provisioned on the master using a custom yml file ([kube-flannel.yml](kube-flannel.yml)) Its basically the same as the default one from [coreos][1] but with a small change to explicitly set the network interface to use for its IP. We set this to the second interface that has been configured with a Bridged IP ```enp0s8```
```yaml

     ...
        - --ip-masq
        - --kube-subnet-mgr
        - --iface=enp0s8               <-------
     ...

```
Should the virtualbox implementation change in the future resulting in that second interface having a name change then this yaml will need to be change to accomodate.

(see the following [Bug report][2] and [Stack overflow][3])

[1]:https://github.com/coreos/flannel/blob/master/Documentation/kube-flannel.yml
[2]:https://github.com/coreos/flannel/issues/98
[3]:https://stackoverflow.com/questions/47845739/configuring-flannel-to-use-a-non-default-interface-in-kubernetes


### I started 5 slaves but when I ran vagrant destroy, slaves 3-5 are still there

**NOTE:**
Should you select more than the default 2 slaves to start you will need pass the same argument again when shutting down/removing otherwise the additional slave hosts will be ignored. EG.
```powershell

vagrant destroy --force --slaves=5

```
