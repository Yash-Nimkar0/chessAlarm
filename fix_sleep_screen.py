import re

with open('lib/screens/sleep_screen.dart', 'r') as f:
    content = f.read()

content = content.replace("String icon = \"☀️\";", "IconData icon = Icons.wb_sunny;")
content = content.replace("icon = \"🌧️\";", "icon = Icons.water_drop;")
content = content.replace("icon = \"❄️\";", "icon = Icons.ac_unit;")
content = content.replace("Text(\"$icon  $weatherStr\",", "Row(children: [Icon(icon, color: AppTokens.signal, size: 16), SizedBox(width: 8), Text(weatherStr,")
content = content.replace("'Tonight 🌙'", "'Tonight'")
content = content.replace("Widget _buildSoundButton(String emoji, String title, String soundFile)", "Widget _buildSoundButton(IconData icon, String title, String soundFile)")
content = content.replace("Text(emoji, style: const TextStyle(fontSize: 24)),", "Icon(icon, size: 24, color: isPlaying ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface),")
content = content.replace("_buildSoundButton('🌧️',", "_buildSoundButton(Icons.water_drop,")
content = content.replace("_buildSoundButton('🌊',", "_buildSoundButton(Icons.waves,")
content = content.replace("_buildSoundButton('🌴',", "_buildSoundButton(Icons.forest,")
content = content.replace("_buildSoundButton('🤍',", "_buildSoundButton(Icons.noise_control_off,")

with open('lib/screens/sleep_screen.dart', 'w') as f:
    f.write(content)
