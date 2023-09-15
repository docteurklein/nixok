
# what

A nix flake that helps construct terraform+kubernetes stacks.

# why

Unification in a single language. Currently, working with terraform+kube revolves around a **lot** of stringly typed arguments.  
The best thing the kube ecosystem ended up with is helm with go templates (:facepalm:).  
HCL for terraform and cue-lang are relatively similar to nix-lang, but they lack the generality that nix has.

# how

1. define **all** your objects in a single grand-unified nix module
2. apply the auto-generated tf-config file:
````
nix run .#terraform -- apply -auto-approve -var prefix=test1
````
3. upload the auto-generated docker image:
````
nix run .#phpweb-image.copyToRegistry
````
4. apply the auto-generated kube manifest:
````
kubectl apply -f $(nix build --no-link --print-out-paths .#kube-manifest)
````

## learnings:

    nix eval '.#kubenix.x86_64-linux.kube-manifest.generated'  --json

    docker run --rm --name phpweb -p 8080:80  docteurklein/phpweb:$tag
