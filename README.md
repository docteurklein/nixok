```
nix run .#terraform -- apply -auto-approve -var prefix=test1
nix run .#phpweb-image.copyToRegistry
kubectl apply -f $(nix build --no-link --print-out-paths .#kube-manifest)

```

## learnings:

    nix eval '.#kubenix.x86_64-linux.kube-manifest.generated'  --json

    docker run --rm --name phpweb -p 8080:80  docteurklein/phpweb:$tag
