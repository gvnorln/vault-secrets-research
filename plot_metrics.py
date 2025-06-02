import os
import json
import glob
import matplotlib.pyplot as plt

DATA_DIR = 'data'
RESULTS_DIR = os.path.join(DATA_DIR, 'results')

# Buat folder results jika belum ada
os.makedirs(RESULTS_DIR, exist_ok=True)

def load_json(file_pattern):
    files = glob.glob(os.path.join(DATA_DIR, file_pattern))
    return [json.load(open(f)) for f in files]

# Load benchmark summaries
benchmark_summaries = load_json('benchmark_summary_*.json')
benchmark_data = benchmark_summaries[0]['statistics']

# Plot overhead comparison
def plot_overhead(data):
    apps = ['Static App', 'Vault App']
    avg_times = [data['static_app']['avg'], data['vault_app']['avg']]

    plt.figure(figsize=(6,4))
    plt.bar(apps, avg_times, color=['green', 'orange'])
    plt.title('Average Response Time Comparison')
    plt.ylabel('Seconds')
    plt.tight_layout()
    plt.savefig(os.path.join(RESULTS_DIR, 'avg_response_time.png'))
    plt.close()

    # Overhead %
    plt.figure(figsize=(6,4))
    overhead = data['overhead']['percentage']
    plt.bar(['Overhead'], [overhead['avg']], color='red')
    plt.title('Vault Overhead (%)')
    plt.ylabel('Percentage')
    plt.tight_layout()
    plt.savefig(os.path.join(RESULTS_DIR, 'vault_overhead_percentage.png'))
    plt.close()

# Load detailed results for rotation
benchmark_details = load_json('benchmark_results_*.json')
rotations = [r['rotation']['duration_seconds'] for r in benchmark_details[0]['results'] if r['rotation']['performed']]

def plot_rotation(rotations):
    if not rotations:
        print("No rotation data found.")
        return
    plt.figure(figsize=(8,4))
    plt.plot(range(1, len(rotations)+1), rotations, marker='o', linestyle='--')
    plt.title('Vault Credential Rotation Time')
    plt.xlabel('Iteration')
    plt.ylabel('Duration (seconds)')
    plt.grid(True)
    plt.tight_layout()
    plt.savefig(os.path.join(RESULTS_DIR, 'vault_rotation_time.png'))
    plt.close()

# Gitleaks report comparison
def count_secrets(file):
    with open(file) as f:
        return len(json.load(f))

def plot_gitleaks():
    static = count_secrets(os.path.join(DATA_DIR, 'static-secrets-gitleaks-report.json'))
    vault = count_secrets(os.path.join(DATA_DIR, 'vault-secrets-gitleaks-report.json'))
    
    plt.figure(figsize=(6,4))
    plt.bar(['Static Secrets', 'Vault Secrets'], [static, vault], color=['crimson', 'blue'])
    plt.title('Secrets Leak Detected (Gitleaks)')
    plt.ylabel('Count')
    plt.tight_layout()
    plt.savefig(os.path.join(RESULTS_DIR, 'secrets_leak_comparison.png'))
    plt.close()

# Run all plots
plot_overhead(benchmark_data)
plot_rotation(rotations)
plot_gitleaks()

print(f"✅ Semua grafik disimpan di folder: {RESULTS_DIR}")
# This script generates plots for benchmark metrics and saves them in the results directory.