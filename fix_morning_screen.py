import re

with open('lib/screens/morning_screen.dart', 'r') as f:
    content = f.read()

# Emoji removals
content = content.replace("'🌟 Early Riser'", "'Early Riser'")
content = content.replace("'🌙 While You Were Sleeping...'", "'While You Were Sleeping...'")
content = content.replace("'Your Brain Week 🧠'", "'Your Brain Week'")
content = content.replace("'🌟 Missions completed'", "'Missions completed'")
content = content.replace("'🏅 Streak extended'", "'Streak extended'")
content = content.replace("'📈 Total missions'", "'Total missions'")
content = content.replace("'⏱ Fastest solve'", "'Fastest solve'")
content = content.replace("'😴'", "Icons.bedtime")
content = content.replace("'🙂'", "Icons.sentiment_satisfied")
content = content.replace("'⚡'", "Icons.bolt")
content = content.replace("'🔥'", "Icons.local_fire_department")
content = content.replace("'😢'", "Icons.sentiment_dissatisfied")
content = content.replace("'😐'", "Icons.sentiment_neutral")
content = content.replace("String emoji, String label, String description", "IconData icon, String label, String description")
content = content.replace("Text(emoji, style: const TextStyle(fontSize: 32)),", "Icon(icon, size: 32, color: isSelected ? AppTokens.signal : Theme.of(context).colorScheme.onSurfaceVariant),")
content = content.replace("String emoji, String title, String value", "IconData icon, String title, String value")
content = content.replace("Text(emoji, style: const TextStyle(fontSize: 32)),", "Icon(icon, size: 32, color: isSelected ? AppTokens.signal : Theme.of(context).colorScheme.onSurfaceVariant),")

# Fix gradients and solid color cards
content = re.sub(r'gradient:\s*LinearGradient\(\s*colors:\s*\[Colors\.indigo\.shade900,\s*Colors\.purple\.shade900\],.*?\),', 'color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),', content, flags=re.DOTALL)
content = re.sub(r'boxShadow:\s*\[\s*BoxShadow\(color:\s*Colors\.purple\.withValues\(alpha:\s*0\.3\).*?\),?\s*\],', '', content, flags=re.DOTALL)

# Simple color replacements
content = content.replace("Colors.greenAccent", "AppTokens.signal")
content = content.replace("Colors.orangeAccent", "AppTokens.signal")
content = content.replace("Colors.orange.shade400", "AppTokens.signal")
content = content.replace("Colors.blueAccent", "AppTokens.signal")
content = content.replace("Colors.purpleAccent", "AppTokens.signal")
content = content.replace("Colors.indigoAccent", "AppTokens.signal")
content = content.replace("Colors.indigo", "AppTokens.signal")

with open('lib/screens/morning_screen.dart', 'w') as f:
    f.write(content)

