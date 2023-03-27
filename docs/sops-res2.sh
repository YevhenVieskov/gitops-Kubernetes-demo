sops -d -i my-secrets.yaml
$ git add my-secrets.yaml && git commit -m "commit with unencrypted secret"

💥 File env/bel1/c1/helm_vars/my-secrets.yaml has non encrypted secrets!

🤔 Do you still want to commit? (y|Y to commit) n
aborted