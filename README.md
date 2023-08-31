```
nix run .#nginx-image.copyToRegistry
nix run .#php-image.copyToRegistry

kubectl apply -f $(nix build --no-link --print-out-paths .#manifest)
```
