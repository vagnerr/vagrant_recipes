# Vagrant docker build

* based on debian stretch
* Install Oracle VBox Additions ( for sharing host directories with guest )
* Install docker
* share ../../data with guest

Note that due to VBox dependencies you need to restart the vm after initial install
( so that the Additions utility can be available for the dir mount )
so you need to run

```
vagrant up
vagrant reload
```