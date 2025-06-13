import os
import csv
import glob
import matplotlib.pyplot as plt
import json

DATA_DIR = 'data'
RESULTS_DIR = os.path.join(DATA_DIR, 'results')
PERFORMANCE_DIR = os.path.join(DATA_DIR, 'performance-results')
SECURITY_DIR = os.path.join(DATA_DIR, 'security-results')

os.makedirs(RESULTS_DIR, exist_ok=True)

# Load CSV Benchmark File
def load_benchmark_csv():
    files = glob.glob(os.path.join(PERFORMANCE_DIR, 'benchmark_data_*.csv'))
    if not files:
        raise FileNotFoundError("❌ Benchmark CSV file not found.")
    csv_file = sorted(files)[-1]  # ambil file terbaru

    iterations = []
    static_times = []
    vault_times = []
    overheads = []
    overhead_percents = []
    rotations = []

    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            iterations.append(int(row['iteration']))
            static_times.append(float(row['static_time']))
            vault_times.append(float(row['vault_time']))
            overheads.append(float(row['overhead_seconds']))
            overhead_percents.append(float(row['overhead_percentage']))

            if row['rotation_performed'].lower() == 'true' and row['rotation_duration'] != 'null':
                rotations.append(float(row['rotation_duration']))

    return iterations, static_times, vault_times, overheads, overhead_percents, rotations

# Plot Average Response Time & Overhead
def plot_overhead(static_times, vault_times, overhead_percents):
    static_avg = sum(static_times) / len(static_times)
    vault_avg = sum(vault_times) / len(vault_times)
    overhead_avg = sum(overhead_percents) / len(overhead_percents)

    # Bar chart average response time
    apps = ['Static App', 'Vault App']
    avg_times = [static_avg, vault_avg]

    plt.figure(figsize=(8, 6))
    bars = plt.bar(apps, avg_times, color=['green', 'orange'])
    plt.title('Average Response Time Comparison')
    plt.ylabel('Seconds')
    plt.grid(axis='y', linestyle='--', alpha=0.7)

    for bar in bars:
        yval = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2, yval + 0.001, f'{yval:.4f}', ha='center', fontsize=10)

    plt.tight_layout()
    plt.savefig(os.path.join(RESULTS_DIR, 'avg_response_time.png'))
    plt.close()

    # Overhead %
    plt.figure(figsize=(8, 6))
    plt.bar(['Overhead'], [overhead_avg], color='red')
    plt.title('Vault Overhead (%)')
    plt.ylabel('Percentage')
    plt.grid(axis='y', linestyle='--', alpha=0.7)
    plt.text(0, overhead_avg + 1, f'{overhead_avg:.2f}%', ha='center', fontsize=12)

    plt.tight_layout()
    plt.savefig(os.path.join(RESULTS_DIR, 'vault_overhead_percentage.png'))
    plt.close()

# Plot Line Chart per Iteration
def plot_line_chart(iterations, static_times, vault_times):
    plt.figure(figsize=(12, 6))
    plt.plot(iterations, static_times, label='Static App', color='green', marker='o')
    plt.plot(iterations, vault_times, label='Vault App', color='orange', marker='x')
    plt.title('Response Time per Iteration')
    plt.xlabel('Iteration')
    plt.ylabel('Response Time (Seconds)')
    plt.legend()
    plt.grid(True, linestyle='--', alpha=0.7)
    plt.tight_layout()
    plt.savefig(os.path.join(RESULTS_DIR, 'response_time_per_iteration.png'))
    plt.close()

# Plot Histogram Distribusi
def plot_histogram(static_times, vault_times):
    plt.figure(figsize=(12, 6))
    plt.hist(static_times, bins=15, alpha=0.7, label='Static App', color='green')
    plt.hist(vault_times, bins=15, alpha=0.7, label='Vault App', color='orange')
    plt.title('Response Time Distribution')
    plt.xlabel('Response Time (Seconds)')
    plt.ylabel('Frequency')
    plt.legend()
    plt.grid(True, linestyle='--', alpha=0.7)
    plt.tight_layout()
    plt.savefig(os.path.join(RESULTS_DIR, 'response_time_distribution.png'))
    plt.close()

# Plot Rotation Time
def plot_rotation(rotations):
    if not rotations:
        print("No rotation data found.")
        return

    plt.figure(figsize=(10, 6))
    plt.plot(range(1, len(rotations) + 1), rotations, marker='o', linestyle='-', color='#2196F3')
    plt.title('Vault Credential Rotation Time per 10 Iterations')
    plt.xlabel('Rotation Event')
    plt.ylabel('Rotation Duration (Seconds)')
    plt.grid(True, linestyle='--', alpha=0.7)

    for idx, val in enumerate(rotations, 1):
        plt.text(idx, val + 0.002, f'{val:.4f}', ha='center', fontsize=10)

    plt.tight_layout()
    plt.savefig(os.path.join(RESULTS_DIR, 'vault_rotation_time.png'))
    plt.close()

# Gitleaks report comparison with latest file
def plot_gitleaks():
    static_files = glob.glob(os.path.join(SECURITY_DIR, 'static-secrets-gitleaks-report_*.json'))
    vault_files = glob.glob(os.path.join(SECURITY_DIR, 'vault-secrets-gitleaks-report_*.json'))

    if not static_files:
        print("⚠️ Static secrets Gitleaks report not found.")
        static = 0
    else:
        static_file = sorted(static_files)[-1]
        static = count_secrets(static_file)

    if not vault_files:
        print("⚠️ Vault secrets Gitleaks report not found.")
        vault = 0
    else:
        vault_file = sorted(vault_files)[-1]
        vault = count_secrets(vault_file)

    plt.figure(figsize=(6, 4))
    bars = plt.bar(['Static Secrets', 'Vault Secrets'], [static, vault], color=['crimson', 'blue'])
    plt.title('Secrets Leak Detected (Gitleaks)')
    plt.ylabel('Count')
    plt.grid(axis='y', linestyle='--', alpha=0.7)

    for bar in bars:
        yval = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2, yval + 0.05, f'{yval}', ha='center', fontsize=12)

    plt.tight_layout()
    plt.savefig(os.path.join(RESULTS_DIR, 'secrets_leak_comparison.png'))
    plt.close()

def count_secrets(file):
    if not os.path.exists(file):
        print(f"⚠️ File not found: {file}. Assuming 0 secrets leaked.")
        return 0
    with open(file) as f:
        return len(json.load(f))
    
def generate_markdown_summary(static_times, vault_times, overhead_percents, rotations, static_leaks, vault_leaks):
    static_avg = sum(static_times) / len(static_times)
    vault_avg = sum(vault_times) / len(vault_times)
    overhead_avg = sum(overhead_percents) / len(overhead_percents)

    summary_file = os.path.join(RESULTS_DIR, 'benchmark_summary.md')
    with open(summary_file, 'w') as f:
        f.write(f"# Vault Dynamic Secrets Performance Report\n\n")
        f.write(f"**Test Summary Date:** {get_current_time()}\n\n")

        f.write(f"## Key Metrics\n")
        f.write(f"- Static Secrets Avg Response Time: **{static_avg:.4f} s**\n")
        f.write(f"- Vault Secrets Avg Response Time: **{vault_avg:.4f} s**\n")
        f.write(f"- Vault Overhead: **{overhead_avg:.2f} %**\n\n")

        if rotations:
            f.write(f"## Vault Rotation Metrics\n")
            f.write(f"- Avg Rotation Duration: **{sum(rotations)/len(rotations):.4f} s**\n")
            f.write(f"- Total Rotations: **{len(rotations)} times**\n\n")
        else:
            f.write(f"## Vault Rotation Metrics\n")
            f.write(f"- No rotations detected in this benchmark.\n\n")

        f.write(f"## Gitleaks Report\n")
        f.write(f"- Static Secrets Leaks: **{static_leaks}**\n")
        f.write(f"- Vault Secrets Leaks: **{vault_leaks}**\n\n")

        f.write(f"## Conclusion\n")
        f.write(f"- Vault improves security by eliminating static secrets from the application source code.\n")
        f.write(f"- The performance overhead introduced by Vault is acceptable based on the benchmark results.\n")
        f.write(f"- Credential rotation is efficient and does not require service restarts.\n")

    print(f"📄 Benchmark summary saved to: {summary_file}")

def get_current_time():
    from datetime import datetime
    return datetime.now().strftime('%Y-%m-%d %H:%M:%S')


# Main execution
iterations, static_times, vault_times, overheads, overhead_percents, rotations = load_benchmark_csv()

plot_overhead(static_times, vault_times, overhead_percents)
plot_line_chart(iterations, static_times, vault_times)
plot_histogram(static_times, vault_times)
plot_rotation(rotations)

# Load Gitleaks files
static_files = glob.glob(os.path.join(SECURITY_DIR, 'static-secrets-gitleaks-report_*.json'))
vault_files = glob.glob(os.path.join(SECURITY_DIR, 'vault-secrets-gitleaks-report_*.json'))

if not static_files:
    print("⚠️ Static secrets Gitleaks report not found.")
    static_leaks = 0
else:
    static_file = sorted(static_files)[-1]
    static_leaks = count_secrets(static_file)

if not vault_files:
    print("⚠️ Vault secrets Gitleaks report not found.")
    vault_leaks = 0
else:
    vault_file = sorted(vault_files)[-1]
    vault_leaks = count_secrets(vault_file)

plot_gitleaks()

# Generate Markdown Report
generate_markdown_summary(static_times, vault_times, overhead_percents, rotations, static_leaks, vault_leaks)

print(f"✅ Semua grafik dan summary berhasil disimpan di folder: {RESULTS_DIR}")
# End of script