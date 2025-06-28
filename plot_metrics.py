# vault_benchmark_visualization.py
import os
import csv
import glob
import matplotlib.pyplot as plt
import json
from datetime import datetime

# Direktori data dan hasil
DATA_DIR = 'data'
RESULTS_DIR = os.path.join(DATA_DIR, 'results')
PERFORMANCE_DIR = os.path.join(DATA_DIR, 'performance-results')
SECURITY_DIR = os.path.join(DATA_DIR, 'security-results')

os.makedirs(RESULTS_DIR, exist_ok=True)

# Load file CSV hasil benchmark terbaru
def load_benchmark_csv():
    files = glob.glob(os.path.join(PERFORMANCE_DIR, 'benchmark_data_*.csv'))
    if not files:
        raise FileNotFoundError("❌ Benchmark CSV file not ditemukan.")
    csv_file = sorted(files)[-1]  # ambil file terbaru

    iterations, static_times, vault_times = [], [], []
    overheads, overhead_percents, rotations = [], [], []

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

# Gambar grafik batang waktu respon rata-rata dan overhead
def plot_avg_response_and_overhead(static_times, vault_times, overhead_percents):
    static_avg = sum(static_times) / len(static_times)
    vault_avg = sum(vault_times) / len(vault_times)
    overhead_avg = sum(overhead_percents) / len(overhead_percents)

    # Bar chart waktu rata-rata
    plt.figure(figsize=(8, 6))
    bars = plt.bar(['Static App', 'Vault App'], [static_avg, vault_avg], color=['#4CAF50', '#FF9800'])
    plt.title('Rata-rata Waktu Respons Aplikasi')
    plt.ylabel('Waktu (detik)')
    plt.grid(axis='y', linestyle='--', alpha=0.7)
    for bar in bars:
        yval = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2, yval + 0.001, f'{yval:.4f}', ha='center', fontsize=10)
    plt.tight_layout()
    plt.savefig(os.path.join(RESULTS_DIR, 'avg_response_time.png'))
    plt.close()

    # Bar chart overhead rata-rata
    plt.figure(figsize=(6, 5))
    plt.bar(['Vault Overhead'], [overhead_avg], color='crimson')
    plt.title('Rata-rata Overhead Vault (%)')
    plt.ylabel('Persentase')
    plt.grid(axis='y', linestyle='--', alpha=0.7)
    plt.text(0, overhead_avg + 1, f'{overhead_avg:.2f}%', ha='center', fontsize=12)
    plt.tight_layout()
    plt.savefig(os.path.join(RESULTS_DIR, 'vault_overhead_percentage.png'))
    plt.close()

# Gambar grafik garis per iterasi

def plot_response_per_iteration(iterations, static_times, vault_times):
    plt.figure(figsize=(12, 6))
    plt.plot(iterations, static_times, label='Static App', color='#4CAF50', marker='o')
    plt.plot(iterations, vault_times, label='Vault App', color='#FF9800', marker='x')
    plt.title('Waktu Respons per Iterasi')
    plt.xlabel('Iterasi')
    plt.ylabel('Waktu Respons (detik)')
    plt.legend()
    plt.grid(True, linestyle='--', alpha=0.7)
    plt.tight_layout()
    plt.savefig(os.path.join(RESULTS_DIR, 'response_time_per_iteration.png'))
    plt.close()

# Gambar distribusi histogram

def plot_response_histogram(static_times, vault_times):
    plt.figure(figsize=(10, 5))
    plt.hist(static_times, bins=15, alpha=0.7, label='Static App', color='#4CAF50')
    plt.hist(vault_times, bins=15, alpha=0.7, label='Vault App', color='#FF9800')
    plt.title('Distribusi Waktu Respons')
    plt.xlabel('Waktu Respons (detik)')
    plt.ylabel('Frekuensi')
    plt.legend()
    plt.grid(True, linestyle='--', alpha=0.7)
    plt.tight_layout()
    plt.savefig(os.path.join(RESULTS_DIR, 'response_time_distribution.png'))
    plt.close()

# Gambar rotasi kredensial vault

def plot_rotation_time(rotations):
    if not rotations:
        print("❗ Tidak ada data rotasi kredensial.")
        return

    plt.figure(figsize=(10, 5))
    plt.plot(range(1, len(rotations)+1), rotations, marker='o', linestyle='-', color='#2196F3')
    plt.title('Durasi Rotasi Kredensial Vault (per 10 iterasi)')
    plt.xlabel('Event Rotasi ke-')
    plt.ylabel('Durasi (detik)')
    plt.grid(True, linestyle='--', alpha=0.7)
    for idx, val in enumerate(rotations, 1):
        plt.text(idx, val + 0.002, f'{val:.4f}', ha='center', fontsize=9)
    plt.tight_layout()
    plt.savefig(os.path.join(RESULTS_DIR, 'vault_rotation_time.png'))
    plt.close()

# Gitleaks static vs vault

def count_gitleaks(file):
    if not os.path.exists(file):
        return 0
    with open(file) as f:
        return len(json.load(f))

def plot_gitleaks_comparison():
    static_files = glob.glob(os.path.join(SECURITY_DIR, 'static-secrets-gitleaks-report_*.json'))
    vault_files = glob.glob(os.path.join(SECURITY_DIR, 'vault-secrets-gitleaks-report_*.json'))

    static_count = count_gitleaks(sorted(static_files)[-1]) if static_files else 0
    vault_count = count_gitleaks(sorted(vault_files)[-1]) if vault_files else 0

    plt.figure(figsize=(6, 5))
    bars = plt.bar(['Static Secrets', 'Vault Secrets'], [static_count, vault_count], color=['darkred', 'steelblue'])
    plt.title('Jumlah Kebocoran Secrets (Gitleaks)')
    plt.ylabel('Jumlah Secrets')
    plt.grid(axis='y', linestyle='--', alpha=0.7)
    for bar in bars:
        yval = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2, yval + 0.1, str(yval), ha='center', fontsize=12)
    plt.tight_layout()
    plt.savefig(os.path.join(RESULTS_DIR, 'secrets_leak_comparison.png'))
    plt.close()

# Main eksekusi
if __name__ == '__main__':
    iterations, static_times, vault_times, overheads, overhead_percents, rotations = load_benchmark_csv()

    plot_avg_response_and_overhead(static_times, vault_times, overhead_percents)
    plot_response_per_iteration(iterations, static_times, vault_times)
    plot_response_histogram(static_times, vault_times)
    plot_rotation_time(rotations)
    plot_gitleaks_comparison()

    print(f"✅ Semua grafik berhasil disimpan di folder: {RESULTS_DIR}")
