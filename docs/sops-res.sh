$ echo "key: somesecrets" >> my-secrets.yaml
$ sops -e -i my-secrets.yaml
$ cat my-secrets.yaml

key: ENC[AES256_GCM,data:IermPQamdQoWVQE=,iv:ftvBbgqON/w9e7Q4fvH6QVs0JlfEcJBoo+OJYrgHSk8=,tag:IVhNjD/g1jdpc8DIjmbe4w==,type:str]
sops:
    kms: []
    gcp_kms: []
    azure_kv: []
    hc_vault: []
...

$ git add my-secrets.yaml && git commit -m "commit with encrypted secret"

[master 00d096b] commit with encrypted secret
 1 file changed, 29 insertions(+)
 create mode 100644 my-secrets.yaml