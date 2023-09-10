```
nix run .#phpweb-image.copyToRegistry

kubectl apply -f $(nix build --no-link --print-out-paths .#kube-manifest)
```

## learnings:

overlays
