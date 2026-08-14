import os
import re

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Find all BorderRadius.circular(X)
    pattern = r'BorderRadius\.circular\(\s*([0-9.]+)\s*\)'
    
    def replacer(match):
        val_str = match.group(1)
        val = float(val_str)
        
        if val > 48:
            return match.group(0) # Keep circular
        elif val <= 16:
            return 'BorderRadius.circular(AppTokens.radiusSm)'
        else:
            return 'BorderRadius.circular(AppTokens.radiusLg)'
            
    new_content, count = re.subn(pattern, replacer, content)
    
    if count > 0:
        # Check if AppTokens is imported, if not, it might need to be imported.
        # But wait, AppTokens is in lib/theme/design_tokens.dart
        # If it replaces, we must ensure the import is present, but this could be tricky since relative paths differ.
        pass
        
    return count > 0, new_content

changed_files = []
for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            changed, new_content = process_file(filepath)
            if changed:
                # Add import if missing
                if 'AppTokens' in new_content and 'design_tokens.dart' not in new_content:
                    # Calculate relative path
                    depth = filepath.count('/') - 1
                    prefix = '../' * depth if depth > 0 else './'
                    if prefix == './': prefix = ''
                    import_stmt = f"import '{prefix}theme/design_tokens.dart';"
                    # Insert after the last import
                    lines = new_content.split('\n')
                    last_import = -1
                    for i, line in enumerate(lines):
                        if line.startswith('import '):
                            last_import = i
                    if last_import != -1:
                        lines.insert(last_import + 1, import_stmt)
                    else:
                        lines.insert(0, import_stmt)
                    new_content = '\n'.join(lines)
                
                with open(filepath, 'w') as f:
                    f.write(new_content)
                changed_files.append(filepath)

print("Changed files:")
for f in changed_files:
    print(f)
