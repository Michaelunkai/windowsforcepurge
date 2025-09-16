# Interactive OpenRouter Model Selector
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:PATH += ";C:\Users\micha\AppData\Local\Packages\PythonSoftwareFoundation.Python.3.13_qbz5n2kfra8p0\LocalCache\local-packages\Python313\Scripts"
$env:PYTHONIOENCODING = "utf-8"

Clear-Host
Write-Host "🤖 AI Model Selector" -ForegroundColor Magenta
Write-Host "===================" -ForegroundColor Magenta

# Popular models
$models = @{
    "1" = @{name="deepseek/deepseek-r1:free"; desc="DeepSeek R1 (Free) - Advanced reasoning"}
    "2" = @{name="openai/gpt-oss-20b:free"; desc="GPT OSS 20B (Free) - Open source GPT"}
    "3" = @{name="meta-llama/llama-3.3-70b-instruct:free"; desc="Llama 3.3 70B (Free) - Meta's latest"}
    "4" = @{name="qwen/qwen3-235b-a22b:free"; desc="Qwen3 235B (Free) - Large Chinese model"}
    "5" = @{name="anthropic/claude-3.5-sonnet"; desc="Claude 3.5 Sonnet (Paid) - Best reasoning"}
    "6" = @{name="openai/gpt-5"; desc="GPT-5 (Paid) - OpenAI's latest"}
    "7" = @{name="google/gemini-2.5-pro"; desc="Gemini 2.5 Pro (Paid) - Google's best"}
    "8" = @{name="mistralai/codestral-2501"; desc="Codestral 2501 (Paid) - Best for coding"}
    "9" = @{name="x-ai/grok-4"; desc="Grok 4 (Paid) - X.AI's latest"}
}

Write-Host "`nAvailable Models:" -ForegroundColor Green
foreach ($key in $models.Keys | Sort-Object) {
    $model = $models[$key]
    $color = if ($model.name -like "*:free") { "Green" } else { "Yellow" }
    Write-Host "$key. $($model.desc)" -ForegroundColor $color
}

Write-Host "`nSelect model (1-9): " -ForegroundColor White -NoNewline
$choice = Read-Host

if (-not $models.ContainsKey($choice)) {
    Write-Host "Invalid choice!" -ForegroundColor Red
    exit 1
}

$selectedModel = $models[$choice].name
Write-Host "`nUsing: $selectedModel" -ForegroundColor Green

while ($true) {
    Write-Host "`nEnter your message (or 'quit' to exit): " -ForegroundColor Yellow -NoNewline
    $message = Read-Host
    
    if ($message -eq "quit") {
        Write-Host "Goodbye! 👋" -ForegroundColor Magenta
        break
    }
    
    if ($message.Trim() -eq "") {
        continue
    }
    
    Write-Host "`n🤖 Response:" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Gray
    
    try {
        echo $message | openrouter-cli run $selectedModel --raw
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`n" + "=" * 50 -ForegroundColor Gray
}