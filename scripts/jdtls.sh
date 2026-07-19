#!/bin/bash
JDTLS_DIR="$HOME/.local/share/jdtls"
JAVA21=$(readlink -f /usr/lib/jvm/java-21-openjdk-amd64/bin/java 2>/dev/null || echo "/usr/lib/jvm/java-21-openjdk-amd64/bin/java")
LAUNCHER_JAR=$(ls "$JDTLS_DIR/plugins/org.eclipse.equinox.launcher_"*.jar 2>/dev/null | head -1)
CONFIG_DIR="$JDTLS_DIR/config_linux"
DATA_DIR="$HOME/.local/share/jdtls/workspace-data"
mkdir -p "$DATA_DIR"
exec "$JAVA21" \
  -Declipse.application=org.eclipse.jdt.ls.core.id1 \
  -Dosgi.bundles.defaultStartLevel=4 \
  -Declipse.product=org.eclipse.jdt.ls.core.product \
  -Dosgi.checkConfiguration=true \
  -Dosgi.sharedConfiguration.area="$CONFIG_DIR" \
  -Dosgi.sharedConfiguration.area.readOnly=true \
  -Dosgi.configuration.cascaded=true \
  -Xms1G \
  --add-modules=ALL-SYSTEM \
  --add-opens java.base/java.util=ALL-UNNAMED \
  --add-opens java.base/java.lang=ALL-UNNAMED \
  -jar "$LAUNCHER_JAR" \
  -configuration "$CONFIG_DIR" \
  -data "$DATA_DIR" \
  "$@"
