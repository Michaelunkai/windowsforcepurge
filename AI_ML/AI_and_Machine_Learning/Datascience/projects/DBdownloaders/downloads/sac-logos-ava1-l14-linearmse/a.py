import kagglehub

# Download latest version
path = kagglehub.model_download("jiazhuang/YOUR_CLIENT_SECRET_HERE/transformers/default")

print("Path to model files:", path)
