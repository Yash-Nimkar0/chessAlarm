import os
import re

replacements = {
    r'Colors\.white(?!\.)': r'Theme.of(context).colorScheme.onSurface',
    r'Colors\.white\.withOpacity\((.*?)\)': r'Theme.of(context).colorScheme.onSurface.withOpacity(\1)',
    r'Colors\.white54': r'Theme.of(context).colorScheme.onSurfaceVariant',
    r'Colors\.white70': r'Theme.of(context).colorScheme.onSurfaceVariant',
    r'Colors\.white38': r'Theme.of(context).colorScheme.onSurface.withOpacity(0.38)',
    r'Colors\.white24': r'Theme.of(context).colorScheme.onSurface.withOpacity(0.24)',
    r'Colors\.white12': r'Theme.of(context).colorScheme.onSurface.withOpacity(0.12)',
}

def remove_const(text):
    # Strip const from standard UI widgets
    text = re.sub(r'\bconst\s+(TextStyle|Text|Icon|Color|BoxDecoration|Padding|SizedBox|Row|Column|Container|Center|Align|Divider|Expanded)', r'\1', text)
    # Strip const from lists
    text = re.sub(r'\bconst\s+\[', r'[', text)
    return text

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r') as f:
                content = f.read()
            
            new_content = content
            for old, new in replacements.items():
                new_content = re.sub(old, new, new_content)
                
            if new_content != content:
                new_content = remove_const(new_content)
                with open(filepath, 'w') as f:
                    f.write(new_content)
                print(f"Updated {filepath}")
