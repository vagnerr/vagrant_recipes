# Experimenting with Google Compute Engine (GCE)






## Tips

* Don't keep the json service key inside the vagrant directory. as
  that gets synced to the VM should the VM get compromised so would the key
* You need to add the public key to the meta data in the GCE
  interface. Google will then automatically place the auth file in the .ssh
  directory
  * google uses anything before the '@' for the username on the VM so you
    cannot use it as the "from" user identification (arg!) instead just
    put remote identification after the '@' eg
    ```user@localuser_localhost```
    * Obviously the 'user' must matche the vagrant value
      ```override.ssh.username``` or it will hang on vagrant up
  * You cannot use Putty .ppk files for the key authentication. If you to
    vagrant will silently fail "Waiting for SSH to become ready"
