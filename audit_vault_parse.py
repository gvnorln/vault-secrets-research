import json
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime
from collections import Counter
import os

log_file = 'data/audit-log/audit.log'
output_dir = 'data/results/audit-grafik'
os.makedirs(output_dir, exist_ok=True)

# Load and process data
timestamps, operations, types = [], [], []
with open(log_file, 'r') as f:
    for line in f:
        try:
            entry = json.loads(line)
            timestamps.append(datetime.fromisoformat(entry['time'].replace('Z','')))
            types.append(entry['type'])
            operations.append(entry.get('request', {}).get('operation', 'unknown'))
        except json.JSONDecodeError:
            continue

# Set style
sns.set_theme(style="darkgrid", context='talk')

# Bar plot for operation frequency
plt.figure(figsize=(10,6))
sns.countplot(x=operations, palette="cubehelix")
plt.title('Frekuensi Operasi', fontsize=18, fontweight='bold')
plt.xlabel('Operation', fontsize=14)
plt.ylabel('Jumlah', fontsize=14)
plt.xticks(rotation=30)
plt.tight_layout()
plt.savefig(os.path.join(output_dir, 'operation_frequency.png'))
plt.close()

# Scatter plot for log types over time
plt.figure(figsize=(14,6))
sns.scatterplot(x=timestamps, y=types, hue=types, style=types, palette="bright", s=80)
plt.title('Distribusi Tipe Log dari Waktu ke Waktu', fontsize=18, fontweight='bold')
plt.xlabel('Waktu', fontsize=14)
plt.ylabel('Tipe', fontsize=14)
plt.legend(title='Type', bbox_to_anchor=(1.05, 1), loc='upper left')
plt.tight_layout()
plt.savefig(os.path.join(output_dir, 'log_type_over_time.png'))
plt.close()
