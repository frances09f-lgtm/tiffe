#!/usr/bin/env python3
"""Staff update-button and manual-status edits. Idempotent: a file that already
has its marker is left alone. Run from the repo root."""
import pathlib
import re


def edit(path, marker, fn):
    p = pathlib.Path(path)
    s = p.read_text()
    if marker in s:
        print('already applied:', path)
        return
    s = fn(s)
    p.write_text(s)
    print('patched:', path)


def sub(s, old, new):
    assert s.count(old) == 1, (s.count(old), old[:70])
    return s.replace(old, new)


def hub(s):
    s = sub(s, "import '../live/backend.dart';\n", "import '../live/backend.dart';\nimport 'staff_update.dart';\n")
    s = sub(s, "  bool autoAccept = false, autoKnown = false;\n", "")
    s = sub(s, "    super.initState();\n    os = widget.backend.orders().listen(",
            "    super.initState();\n    WidgetsBinding.instance.addPostFrameCallback((_) {\n      if (mounted) maybePromptStaffUpdate(context);\n    });\n    os = widget.backend.orders().listen(")
    s = sub(s, """      final v = await widget.backend.currentSettings();
      if (mounted)
        setState(() {
          autoAccept = v?['kitchen_auto_accept'] == true;
          autoKnown = v?.containsKey('kitchen_auto_accept') == true;
        });
    } catch (_) {}""", """      // Order status must change only when staff tap it. If the server still
      // has auto-accept switched on, the owner session switches it off.
      final v = await widget.backend.currentSettings();
      if (widget.role == 'owner' && v?['kitchen_auto_accept'] == true) {
        await widget.backend.client.rpc(
          'set_kitchen_auto_accept',
          params: {'p_enabled': false},
        );
      }
    } catch (_) {}""")
    s = sub(s, """        autoAccept: autoAccept,
        autoKnown: autoKnown,
        onAuto: (v) async {
          await widget.backend.client.rpc(
            'set_kitchen_auto_accept',
            params: {'p_enabled': v},
          );
          await reload();
        },
      ),""", "      ),")
    s = sub(s, "                autoAccept: autoAccept,\n                onSignOut", "                onSignOut")
    s = sub(s, "  final bool autoAccept, autoKnown;\n  final Future<void> Function(bool)? onAuto;\n", "")
    s = sub(s, "    this.autoAccept = false,\n    this.autoKnown = false,\n    this.onAuto,\n", "")
    s = sub(s, "  final bool autoAccept;\n  final VoidCallback onSignOut;", "  final VoidCallback onSignOut;")
    s = sub(s, "    required this.autoAccept,\n    required this.onSignOut,", "    required this.onSignOut,")
    pat = re.compile(r"        const SizedBox\(height: 12\),\n        SwitchListTile\(.*?(?=        if \(error != null\)\n          Text\(error!)", re.S)
    assert len(pat.findall(s)) == 1
    s = pat.sub("", s)
    s = sub(s, """                onSelected: (v) {
                  if (v == 'logout')
                    onSignOut();
                  else
                    onTab(int.parse(v));
                },""", """                onSelected: (v) {
                  if (v == 'logout') {
                    onSignOut();
                  } else if (v == 'update') {
                    checkStaffUpdateManually(c);
                  } else {
                    onTab(int.parse(v));
                  }
                },""")
    s = sub(s, "                  const PopupMenuItem(value: 'logout', child: Text('Sign out')),",
            "                  const PopupMenuItem(\n                    value: 'update',\n                    child: Text('Check for updates'),\n                  ),\n                  const PopupMenuItem(value: 'logout', child: Text('Sign out')),")
    return s


def home(s):
    s = sub(s, "import 'partner_hub.dart';\n", "import 'partner_hub.dart';\nimport 'staff_update.dart';\n")
    s = sub(s, "    super.initState();\n    orders = widget.backend.staffOrders(widget.role);\n",
            "    super.initState();\n    orders = widget.backend.staffOrders(widget.role);\n    WidgetsBinding.instance.addPostFrameCallback((_) {\n      if (mounted) maybePromptStaffUpdate(context);\n    });\n")
    s = sub(s, "          icon: const Icon(Icons.refresh),\n        ),\n",
            "          icon: const Icon(Icons.refresh),\n        ),\n        IconButton(\n          onPressed: () => checkStaffUpdateManually(c),\n          tooltip: 'Check for updates',\n          icon: const Icon(Icons.system_update),\n        ),\n")
    return s


FUNC = r"""    // In-app update: APK is downloaded over HTTP in Dart and handed to the
    // Android package installer here. The only system steps are the one-time
    // "install unknown apps" toggle and the installer confirm, both owned by
    // Android. Also serves the app's versionName and cache dir so the Dart
    // side needs no extra plugins.
    private fun registerUpdateChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/update")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "appVersion" -> result.success(
                        packageManager.getPackageInfo(packageName, 0).versionName
                    )
                    "cacheDir" -> result.success(cacheDir.absolutePath)
                    "canInstall" -> result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            packageManager.canRequestPackageInstalls()
                    )
                    "openInstallSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName")
                                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                        }
                        result.success(null)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        val file = path?.let { File(it) }
                        if (file == null || !file.exists()) {
                            result.error("no_apk", "APK not found: $path", null)
                            return@setMethodCallHandler
                        }
                        val uri = FileProvider.getUriForFile(
                            this,
                            "$packageName.updateprovider",
                            file
                        )
                        val intent = Intent(Intent.ACTION_VIEW)
                            .setDataAndType(
                                uri,
                                "application/vnd.android.package-archive"
                            )
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
"""


def main_activity(s):
    s = sub(s, "import android.os.Build\n", "import android.os.Build\nimport android.net.Uri\n")
    s = sub(s, "import android.os.SystemClock\n", "import android.os.SystemClock\nimport android.provider.Settings\nimport androidx.core.content.FileProvider\n")
    s = sub(s, "import io.flutter.plugin.common.MethodChannel\n", "import io.flutter.plugin.common.MethodChannel\nimport java.io.File\n")
    s = sub(s, "        super.configureFlutterEngine(flutterEngine)\n", "        super.configureFlutterEngine(flutterEngine)\n        registerUpdateChannel(flutterEngine)\n")
    i = s.rstrip().rfind("}")
    return s[:i] + FUNC + "}\n"


def manifest(s):
    s = sub(s, '    <uses-permission android:name="android.permission.USE_EXACT_ALARM" />\n',
            '    <uses-permission android:name="android.permission.USE_EXACT_ALARM" />\n    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />\n')
    prov = """        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.updateprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_paths" />
        </provider>
"""
    return sub(s, "        <!-- Don't delete the meta-data below.", prov + "        <!-- Don't delete the meta-data below.")


edit('lib/staff/partner_hub.dart', 'checkStaffUpdateManually', hub)
edit('lib/staff/staff_app.dart', 'checkStaffUpdateManually', home)
edit('android/app/src/main/kotlin/com/tiffe/tiffe/MainActivity.kt', 'registerUpdateChannel', main_activity)
edit('android/app/src/main/AndroidManifest.xml', 'updateprovider', manifest)
edit('pubspec.yaml', 'version: 1.0.50+50', lambda s: sub(s, 'version: 1.0.49+49', 'version: 1.0.50+50'))
edit('lib/live/bug_report.dart', "'1.0.50+50'", lambda s: sub(s, "'1.0.49+49'", "'1.0.50+50'"))
