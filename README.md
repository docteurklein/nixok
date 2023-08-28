```
nix run .#copy-images -- --insecure-policy

kubectl apply -f $(nix build --no-link --print-out-paths .#manifest)
```
