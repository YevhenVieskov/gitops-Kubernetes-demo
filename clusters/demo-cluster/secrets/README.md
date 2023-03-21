    


### Generate a key

Let's check age-key CLI for understanding how to create a key.

` age-keygen --help`

Let’s make a key

`age-keygen -o age.agekey`

The public key is the one we use to encrypt and the secret key decrypts data (and must be kept private).

### Test Encryption and Decryption

Next, make encryption easier by creating a small config file for SOPS. This allows you to encrypt quickly without telling SOPS which key you want to use and it will only check *.ymlfiles. So, let's create a .sops.yaml file like this one in the root directory of your flux repository.

Remember to add YOUR public key to the age key below in the `.sops.yaml` file.

``` 
creation_rules:
  - path_regex: .*.yml
    encrypted_regex: '^(data|stringData)$'
    age: age1p7zzzyj6qajqqdy9qssz3exwn8hws9l5swjxqhx7ryuznhza0yjsaeast4
    kms: kms: arn:aws:kms:us-east-1:xxxxxxxxxxx:key/xxxxxxx-xxxx-xxxx-xxxx-xxxx

```

And let us test it.

```
$ kubectl create secret generic sopstest --from-literal=sops=hello -o yaml --dry-run=clientapiVersion: v1
data:
  sops: aGVsbG8=
kind: Secret
metadata:
  creationTimestamp: "2022-10-04T11:38:11Z"
  name: sopstest
  namespace: default
  resourceVersion: "1381074"
  uid: 35df8996-6687-479d-83e5-065fabcadfc8
type: Opaque$ kubectl create secret generic sopstest --from-literal=sops=hello -o yaml --dry-run=client > sops-test-secret.yml

```
Now let us try encryption and decryption with the key that we just generated. Remember to export SOPS_AGE_KEY_FILE for using SOPS anywhere. Also with -i flag we can encrypt and decrypt in place.

```

$ export SOPS_AGE_KEY_FILE=age.agekey
$ sops -e sops-test-secret.yml
apiVersion: v1
data:
    sops: ENC[AES256_GCM,data:BThY4xVa+SM=,iv:odFiupGKWtOJKrZ63idvgtgpDGCCPdWijWQb1NTeIDY=,tag:D3oFsdOYFHkvlTFUyq6s9Q==,type:str]
kind: Secret
metadata:
    creationTimestamp: null
    name: sopstest
sops:
    kms: []
    gcp_kms: []
    azure_kv: []
    hc_vault: []
    age:
        - recipient: age1p7zzzyj6qajqqdy9qssz3exwn8hws9l5swjxqhx7ryuznhza0yjsaeast4
          enc: |
            -----BEGIN AGE ENCRYPTED FILE-----
            YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IFgyNTUxOSBPdjNaYlpZNDJ1cGlaR0xO
            dmFnOG9JNExNYkVQTGZLdjc0U2lmSWZuWFJZCkowbSt1NHlqT1BiWXloK1luOTZl
            dE5WWFlqL2hSMm9ScDFUZTVnYnprUlEKLS0tIFN5cjRGeG1hUmVORjhxb2pYeGFo
            ak05OWJSWnZtNng2TWlRWnVsd1Z1SXcKvlJ2v8kjlzjh6TCbuipXb3g4rG3F2DAs
            rpxm7EiTR51/GQbcQcU8qd/FC0KKOAifmLeW7PXODqk6pU0gdSPF1Q==
            -----END AGE ENCRYPTED FILE-----
    lastmodified: "2022-10-04T11:43:57Z"
    mac: ENC[AES256_GCM,data:MdCIUTrfZX4/0T5D5eqQtywTLJjWazgNd+oq//x7I88OKiA9vKuG22/K0rn7I6Rc9Motbilf3lCbz1Une8HJ9Z1L9BVcaFJJid13TCTm01+E//vCKNJwDfjnX5IkemUlsrPnWN/2IoIvqlgeUZUKZmfIzYWBAKvkYDz9L3DsRFo=,iv:ZtPtLBUw00g8C+UBNwvfgTcjzGpumv3xkMS8ClmVmA4=,tag:1kXPMR8+scKwAg1nKhz5QA==,type:str]
    pgp: []
    encrypted_regex: ^(data|stringData)$
    version: 3.7.3$ sops -e -i sops-test-secret.yml$ sops -d sops-test-secret.yml
apiVersion: v1
data:
    sops: aGVsbG8=
kind: Secret
metadata:
    creationTimestamp: null
    name: sopstest

```

As a final step for this section, commit your encrypted secret file and push it to your git repository.

### Usage in FluxCD

File with secret data creation:

```
kubectl -n default create secret generic basic-auth \
    --from-literal=user=admin \
    --from-literal=password=change-me \
    --dry-run=client \
    -o yaml > basic-auth.yaml

```

Our first step created a age.agekey file and we need to create a secret from that file that only flux can see in its namespace and remember default namespace for flux is flux-system:



`cat age.agekey | kubectl create secret generic sops-age --namespace=flux-system --from-file=age.agekey=/dev/stdin`

This command creates a generic secret called sops-age with our key in the flux-system namespace. The secret exists only inside the flux-system namespace so that only the pods in that namespace have permission to read it.

Finally, we must tell flux that it needs to decrypt secrets so we need to provide the location of the decryption key. Flux is built heavily on kustomize manifests and that’s where our key configuration belongs.

Below you can find a sample kustomize definition that uses SOPS with our key:

```
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: test
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  # Decryption configuration starts here
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```

The last section tells flux about our sops-age secret and indicate that we are using the SOPS backend for decryption. Commit this change and push it to your git repository.

There is one important point about kustomization here. As you can see there is path: `./` a key-value pair in the file which indicates that decryption will be happening under the apps/test folder so you need to put your encrypted secret file under this path.

So what are the next steps after you commit and push your kustomize file to your repo?

    * Flux checks and understands that local and remote have differences which mean there is a change in the git repository. So it starts to reconcile.

    * After reconciliation, it reaches the encrypted secret and it will fetch the decryption configuration defined in the kustomization file.

    * From there, it retrieves the sops-age secret, reads the key, and uses SOPS with age to decrypt the secret.

    * Flux applies the secret to the namespace defined in the encrypted secret file in your cluster.

At this point, you can retrieve your unencrypted version of your secret by using:

`kubectl get secret sops-age -n default -o yaml`

Flux decrypts the secret from your git repository and adds it to your cluster, but it remains unencrypted in your cluster. This allows pods in the namespace [this namespace refers to the namespace defined in your secret file] to read data from the secret without any further decryption.


### Configure the tools
Add aliases to your interpretor

This should work effortlessly on bash and zsh.

As the syntax to encrypt a file is bit tedious (due to the fact that you must pass the Age public key to Sops) we have prepared an alias that can be added to your .bashrcor .zshrc

`export SOPS_KMS_ARN_PROD="arn:aws:kms:us-east-1:xxxxxxxxxxx:key/xxxxxxx-xxxx-xxxx-xxxx-xxxx"`

`export SOPS_AGE_KEY_FILE=$HOME/age.agekey`

`export AGE_PUBLIC_KEY=$(cat $SOPS_AGE_KEY_FILE |grep -oP "public key: \K(.*)") $2 $3 $1`

```
function cypher {
    filename=$(basename -- "$1")
    extension="${filename##*.}"
    filename="${filename%.*}"
    AGE_PUBLIC_KEY=$(cat $SOPS_AGE_KEY_FILE |grep -oP "public key: \K(.*)") $2 $3 $1
    sops --encrypt --age $AGE_PUBLIC_KEY  --kms $SOPS_KMS_ARN_PROD $1 >  "$filename.enc.$extension"
}

```


Remember to always source your profile before trying new aliases.

Usage:

```
# Creating test files
$ echo "some_key: some_value" > test_alias.yaml# Encrypting
$ cypher test_alias.yaml$ ls
test_alias.enc.yaml

```
You could also update the alias to edit the file in place and not generate a new one. This should look like this :

```
function cypher_inplace {
    AGE_PUBLIC_KEY=$(cat $SOPS_AGE_KEY_FILE |grep -oP "public key: \K(.*)") $2 $3 $1
    sops --encrypt --in-place --age $AGE_PUBLIC_KEY $1 --kms $SOPS_KMS_ARN_PROD
}

```

Decryption functions:

``
`function decypher_inplace {
    AGE_PUBLIC_KEY=$(cat $SOPS_AGE_KEY_FILE |grep -oP "public key: \K(.*)") $2 $3 $1
    sops --decrypt --in-place --age $SOPS_AGE_KEY_FILE $1 --kms $SOPS_KMS_ARN_PROD
}

function decypher {
    filename=$(basename -- "$1")
    extension="${filename##*.}"
    filename="${filename%.*}"    
    sops --decrypt --age $AGE_PUBLIC_KEY  --kms $SOPS_KMS_ARN_PROD $1 >  "$filename.dec.$extension"
}

```





[Using SOPS with Age and Git like a Pro](https://devops.datenkollektiv.de/using-sops-with-age-and-git-like-a-pro.html)

echo -n 'creation_rules:
  - shamir_threshold: 1
    path_regex: "secret.json"
    encrypted_regex: "^(user|password)$"
    key_groups:
      - age:
        - age1t2c8jft25k5nnr7m2zln473dkxegwvx5ge2pfgarfnaepepmzpzszz63qy
' >> workspace/.sops.yaml



Name:         vault
Namespace:    vault
Labels:       kustomize.toolkit.fluxcd.io/name=test
              kustomize.toolkit.fluxcd.io/namespace=flux-system
Annotations:  <none>
API Version:  helm.toolkit.fluxcd.io/v2beta1
Kind:         HelmRelease
Metadata:
  Creation Timestamp:  2023-03-14T09:10:36Z
  Finalizers:
    finalizers.fluxcd.io
  Generation:  1
  Managed Fields:
    API Version:  helm.toolkit.fluxcd.io/v2beta1
    Fields Type:  FieldsV1
    fieldsV1:
      f:metadata:
        f:labels:
          f:kustomize.toolkit.fluxcd.io/name:
          f:kustomize.toolkit.fluxcd.io/namespace:
      f:spec:
        f:chart:
          f:spec:
            f:chart:
            f:sourceRef:
              f:kind:
              f:name:
              f:namespace:
            f:version:
        f:interval:
        f:values:
          f:server:
            .:
            f:affinity:
            f:ha:
              .:
              f:enabled:
              f:raft:
                .:
                f:enabled:
    Manager:      kustomize-controller
    Operation:    Apply
    Time:         2023-03-14T09:24:10Z
    API Version:  helm.toolkit.fluxcd.io/v2beta1
    Fields Type:  FieldsV1
    fieldsV1:
      f:metadata:
        f:finalizers:
          .:
          v:"finalizers.fluxcd.io":
    Manager:      helm-controller
    Operation:    Update
    Time:         2023-03-14T09:10:36Z
    API Version:  helm.toolkit.fluxcd.io/v2beta1
    Fields Type:  FieldsV1
    fieldsV1:
      f:status:
        f:conditions:
        f:failures:
        f:helmChart:
        f:observedGeneration:
    Manager:         helm-controller
    Operation:       Update
    Subresource:     status
    Time:            2023-03-14T09:27:38Z
  Resource Version:  416461
  UID:               1a67e505-460b-446c-8675-ff79d951ad1a
Spec:
  Chart:
    Spec:
      Chart:               vault
      Reconcile Strategy:  ChartVersion
      Source Ref:
        Kind:       HelmRepository
        Name:       hashicorp
        Namespace:  vault
      Version:      0.23.0
  Interval:         1m0s
  Values:
    Server:
      Affinity:  
      Ha:
        Enabled:  true
        Raft:
          Enabled:  true
Status:
  Conditions:
    Last Transition Time:  2023-03-14T09:10:36Z
    Message:               HelmChart 'vault/vault-vault' is not ready
    Reason:                ArtifactFailed
    Status:                False
    Type:                  Ready
  Failures:                18
  Helm Chart:              vault/vault-vault
  Observed Generation:     1
Events:
  Type    Reason  Age                 From             Message
  ----    ------  ----                ----             -------
  Normal  info    18s (x18 over 17m)  helm-controller  HelmChart 'vault/vault-vault' is not ready




flux logs -n vault --level=error
2023-03-14T08:13:47.956Z error HelmRepository/vault.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: failed to fetch https://github.com/hashicorp/vault-helm/index.yaml : 404 Not Found
2023-03-14T08:13:49.688Z error HelmRepository/vault.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: failed to fetch https://github.com/hashicorp/vault-helm/index.yaml : 404 Not Found
2023-03-14T08:13:52.869Z error HelmRepository/vault.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: failed to fetch https://github.com/hashicorp/vault-helm/index.yaml : 404 Not Found
2023-03-14T08:13:59.050Z error HelmRepository/vault.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: failed to fetch https://github.com/hashicorp/vault-helm/index.yaml : 404 Not Found
2023-03-14T08:14:11.384Z error HelmRepository/vault.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: failed to fetch https://github.com/hashicorp/vault-helm/index.yaml : 404 Not Found
2023-03-14T08:14:35.827Z error HelmRepository/vault.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: failed to fetch https://github.com/hashicorp/vault-helm/index.yaml : 404 Not Found
2023-03-14T08:15:24.448Z error HelmRepository/vault.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: failed to fetch https://github.com/hashicorp/vault-helm/index.yaml : 404 Not Found
2023-03-14T08:17:00.716Z error HelmRepository/vault.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: failed to fetch https://github.com/hashicorp/vault-helm/index.yaml : 404 Not Found
2023-03-14T08:20:13.181Z error HelmRepository/vault.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: failed to fetch https://github.com/hashicorp/vault-helm/index.yaml : 404 Not Found
2023-03-14T08:26:37.771Z error HelmRepository/vault.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: failed to fetch https://github.com/hashicorp/vault-helm/index.yaml : 404 Not Found
2023-03-14T08:39:26.063Z error HelmRepository/vault.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: failed to fetch https://github.com/hashicorp/vault-helm/index.yaml : 404 Not Found
2023-03-14T08:54:28.493Z error HelmRepository/vault.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: failed to fetch https://github.com/hashicorp/vault-helm/index.yaml : 404 Not Found
2023-03-14T09:09:28.855Z error HelmRepository/vault.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: failed to fetch https://github.com/hashicorp/vault-helm/index.yaml : 404 Not Found
2023-03-14T09:10:37.225Z error HelmRepository/hashicorp.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: Get "https://helm.releases.hashhicorp.com/index.yaml": dial tcp: lookup helm.releases.hashhicorp.com on 10.96.0.10:53: no such host
2023-03-14T09:10:38.864Z error HelmRepository/hashicorp.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: Get "https://helm.releases.hashhicorp.com/index.yaml": dial tcp: lookup helm.releases.hashhicorp.com on 10.96.0.10:53: no such host
2023-03-14T09:10:41.951Z error HelmRepository/hashicorp.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: Get "https://helm.releases.hashhicorp.com/index.yaml": dial tcp: lookup helm.releases.hashhicorp.com on 10.96.0.10:53: no such host
2023-03-14T09:10:48.003Z error HelmRepository/hashicorp.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: Get "https://helm.releases.hashhicorp.com/index.yaml": dial tcp: lookup helm.releases.hashhicorp.com on 10.96.0.10:53: no such host
2023-03-14T09:11:00.066Z error HelmRepository/hashicorp.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: Get "https://helm.releases.hashhicorp.com/index.yaml": dial tcp: lookup helm.releases.hashhicorp.com on 10.96.0.10:53: no such host
2023-03-14T09:11:24.499Z error HelmRepository/hashicorp.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: Get "https://helm.releases.hashhicorp.com/index.yaml": dial tcp: lookup helm.releases.hashhicorp.com on 10.96.0.10:53: no such host
2023-03-14T09:12:12.782Z error HelmRepository/hashicorp.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: Get "https://helm.releases.hashhicorp.com/index.yaml": dial tcp: lookup helm.releases.hashhicorp.com on 10.96.0.10:53: no such host
2023-03-14T09:13:48.926Z error HelmRepository/hashicorp.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: Get "https://helm.releases.hashhicorp.com/index.yaml": dial tcp: lookup helm.releases.hashhicorp.com on 10.96.0.10:53: no such host
2023-03-14T09:17:01.198Z error HelmRepository/hashicorp.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: Get "https://helm.releases.hashhicorp.com/index.yaml": dial tcp: lookup helm.releases.hashhicorp.com on 10.96.0.10:53: no such host
2023-03-14T09:23:25.353Z error HelmRepository/hashicorp.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: Get "https://helm.releases.hashhicorp.com/index.yaml": dial tcp: lookup helm.releases.hashhicorp.com on 10.96.0.10:53: no such host
2023-03-14T09:36:14.243Z error HelmRepository/hashicorp.vault - Reconciler error failed to fetch Helm repository index: failed to cache index to temporary file: Get "https://helm.releases.hashhicorp.com/index.yaml": dial tcp: lookup helm.releases.hashhicorp.com on 10.96.0.10:53: no such host
yevhenv@yevhenv-VirtualBox:~$ flux get sources helm --all-namespaces
NAMESPACE  	NAME          	REVISION                                                        	SUSPENDED	READY	MESSAGE                                                                                                                                                                                                             
flux-system	metrics-server	ac916419e9ae713cbd962e6198a5b9d97fc211cf9b394b954d080260624208c7	False    	True 	stored artifact: revision 'ac916419e9ae713cbd962e6198a5b9d97fc211cf9b394b954d080260624208c7'                                                                                                                       	
vault      	hashicorp     	                                                                	False    	False	failed to fetch Helm repository index: failed to cache index to temporary file: Get "https://helm.releases.hashhicorp.com/index.yaml": dial tcp: lookup helm.releases.hashhicorp.com on 10.96.0.10:53: no such host	
yevhenv@yevhenv-VirtualBox:~$ flux get sources chart -n vault
NAME       	REVISION	SUSPENDED	READY	MESSAGE                                                     
vault-vault	        	False    	False	no artifact available for HelmRepository source 'hashicorp'	
yevhenv@yevhenv-VirtualBox:~$ 

kubectl exec vault-0 -n vault -- vault operator unseal $VAULT_UNSEAL_KEY



